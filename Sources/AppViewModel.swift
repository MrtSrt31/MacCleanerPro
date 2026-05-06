import AppKit
import Foundation
import UserNotifications

final class AppViewModel: ObservableObject, @unchecked Sendable {
    @Published var selectedSection: AppSection = .dashboard
    @Published private(set) var results: [CleanupScanResult] = CleanupCategory.allCases.map {
        CleanupScanResult(
            category: $0,
            bytes: 0,
            itemCount: 0,
            itemPaths: [],
            notes: [$0.emptyStateNote],
            shellCommand: nil,
            scannedRoots: [],
            lastUpdated: Date()
        )
    }
    @Published private(set) var selectedCategories: Set<CleanupCategory> = Set(CleanupCategory.allCases.filter(\.defaultSelected))
    @Published private(set) var diskSummary: DiskSummary = .empty
    @Published private(set) var isScanning = false
    @Published private(set) var isCleaning = false
    @Published private(set) var scanProgress: Double = 0
    @Published private var stageTitlePayload  = LocalizedTextPayload.localized("Hazir")
    @Published private var stageDetailPayload = LocalizedTextPayload.localized("Gercek sistem verisini taramaya hazir.")
    @Published private(set) var activities: [ActivityEntry] = []
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var lastCleanupDate: Date?
    @Published private(set) var reportURL: URL?
    @Published private(set) var snapshotURL: URL?
    @Published private var toastPayload: LocalizedTextPayload?

    @Published private(set) var safeMode = true
    @Published private(set) var deepScan = false
    @Published private(set) var snapshotBeforeCleanup = true
    @Published private(set) var schedule: MaintenanceSchedule = .weekly
    @Published var threshold: Double = 72

    @Published private(set) var themeAccent: ThemeAccent = .tealCopper
    @Published var showOnboarding = false
    @Published private(set) var launchAgentInstalled = false
    @Published private(set) var notificationsAuthorized = false

    private var hasPerformedInitialScan = false
    private var toastWorkItem: DispatchWorkItem?

    // Thread-safe cancellation flag accessed from both main and background queues.
    private let cancellationQueue = DispatchQueue(label: "com.mertsert.mcp.cancellation")
    private var _scanCancelled = false

    private enum Defaults {
        static let safeMode    = "MacCleanerPro.safeMode"
        static let deepScan    = "MacCleanerPro.deepScan"
        static let snapshot    = "MacCleanerPro.snapshotBeforeCleanup"
        static let schedule    = "MacCleanerPro.schedule"
        static let threshold   = "MacCleanerPro.threshold"
        static let themeAccent = "MacCleanerPro.themeAccent"
        static let onboarding  = "MacCleanerPro.onboardingCompleted"
    }

    init() {
        let ud = UserDefaults.standard
        safeMode             = ud.object(forKey: Defaults.safeMode)  as? Bool   ?? true
        deepScan             = ud.object(forKey: Defaults.deepScan)  as? Bool   ?? false
        snapshotBeforeCleanup = ud.object(forKey: Defaults.snapshot) as? Bool   ?? true
        // Clamp threshold to valid slider range regardless of what's stored.
        threshold = {
            let raw = ud.object(forKey: Defaults.threshold) as? Double ?? 72
            return max(55, min(90, raw))
        }()
        if let raw = ud.string(forKey: Defaults.schedule), let v = MaintenanceSchedule(rawValue: raw) { schedule = v }
        if let raw = ud.string(forKey: Defaults.themeAccent), let v = ThemeAccent(rawValue: raw) { themeAccent = v }
        showOnboarding = !ud.bool(forKey: Defaults.onboarding)
        selectedCategories = Set(CleanupCategory.allCases.filter { safeMode ? $0.safety == .safe : $0.defaultSelected })
        launchAgentInstalled = FileManager.default.fileExists(atPath: launchAgentPlistURL.path)

        requestNotificationPermission()
        appendActivity(.localized("Native macOS uygulama hazirlandi. Ilk tarama bekleniyor."), style: .info)
    }

    // MARK: - Computed properties

    var stageTitle:   String { stageTitlePayload.resolved }
    var stageDetail:  String { stageDetailPayload.resolved }
    var toastMessage: String? { toastPayload?.resolved }

    var orderedResults: [CleanupScanResult] {
        results.sorted { lhs, rhs in
            lhs.bytes != rhs.bytes ? lhs.bytes > rhs.bytes : lhs.category.title < rhs.category.title
        }
    }

    var selectedResults: [CleanupScanResult] {
        orderedResults.filter { selectedCategories.contains($0.category) }
    }

    var reclaimableBytes: Int64 { orderedResults.totalBytes }
    var selectedBytes: Int64    { selectedResults.totalBytes }
    var selectedCount: Int      { selectedResults.count }

    var riskCount: Int {
        selectedResults.filter { $0.safety != .safe }.count
    }

    var healthScore: Int {
        guard diskSummary.total > 0 else { return 50 }
        let freePercent   = Double(diskSummary.free)  / Double(diskSummary.total)      // 0…1
        let reclaimGB     = Double(reclaimableBytes)  / 1_073_741_824                  // in GB
        let totalGB       = Double(diskSummary.total) / 1_073_741_824
        let reclaimFactor = min(reclaimGB / max(totalGB * 0.05, 1), 1.0)               // 0…1, normalised to 5% of disk
        let riskPenalty   = Double(riskCount) * 0.06
        let safeBonus     = safeMode ? 0.08 : 0.0
        let score = (freePercent * 60) + (reclaimFactor * 20) + (safeBonus * 20) - (riskPenalty * 20)
        return min(99, max(30, Int(score.rounded())))
    }

    var freeSpaceAfterCleanup: Int64  { diskSummary.free + selectedBytes }
    var monthlyProjectedGain: Int64   { Int64(Double(selectedBytes) * schedule.monthlyMultiplier) }
    var nextMaintenanceLabel: String  { schedule.nextDate(from: Date()).shortTimestamp }

    var statusBadgeTitle: String {
        if isCleaning  { return L10n.tr("Temizlik calisiyor") }
        if isScanning  { return L10n.tr("Tarama calisiyor") }
        return L10n.tr("Hazir")
    }

    var lastScanLabel: String {
        lastScanDate?.shortTimestamp ?? L10n.tr("Henuz taranmadi")
    }

    var riskLabel: String {
        if riskCount == 0 && safeMode { return L10n.tr("Tam guvenli") }
        if riskCount == 0             { return L10n.tr("Dengeli") }
        return L10n.tr("Onay gerekiyor")
    }

    var reportBars: [BarPoint] {
        let baseBytes = Double(max(selectedBytes, 1))
        let multipliers: [Double] = [0.92, 1.07, 1.01, 1.18, 1.11, 1.24]
        let calendar = Calendar.current
        let now = Date()
        let fmt = DateFormatter()
        fmt.locale = L10n.locale
        fmt.dateFormat = "MMM"

        return multipliers.enumerated().map { index, multiplier in
            let monthDate = calendar.date(byAdding: .month, value: index, to: now) ?? now
            return BarPoint(label: fmt.string(from: monthDate), value: baseBytes * multiplier * schedule.monthlyMultiplier)
        }
    }

    var appVersionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var reportSummary: String {
        let deepText     = deepScan ? L10n.tr("acik") : L10n.tr("kapali")
        let snapshotText = snapshotBeforeCleanup ? L10n.tr("olusturuluyor") : L10n.tr("olusturulmuyor")
        return L10n.format(
            "Bu kurulum %@ secili alan hedefliyor. Guvenlik profili %@ ve derin tarama %@. Temizlik oncesi snapshot manifesti %@. Bir sonraki planli bakim %@ olarak hesaplandi.",
            selectedBytes.formattedBytes, riskLabel, deepText, snapshotText, nextMaintenanceLabel
        )
    }

    var scanOptions: ScanOptions {
        ScanOptions(
            includeDeepScan: deepScan,
            safeMode: safeMode,
            largeDownloadThresholdMB: deepScan ? 250 : 500,
            largeDownloadAgeDays: deepScan ? 10 : 21
        )
    }

    // MARK: - Scan lifecycle

    func performInitialScanIfNeeded() {
        guard !hasPerformedInitialScan else { return }
        hasPerformedInitialScan = true
        startScan(manual: false)
    }

    func startScan(manual: Bool = true) {
        guard !isScanning, !isCleaning else { return }
        setScanCancelled(false)

        isScanning = true
        scanProgress = 0.03
        setStage(title: .localized("Tarama hazirlaniyor"), detail: .localized("Gercek sistem klasorleri okunacak."))

        if manual { appendActivity(.localized("Akilli tarama baslatildi."), style: .info) }

        let options = scanOptions
        let previousSelection = selectedCategories
        let currentSafeMode = safeMode
        let shouldCancelFn: () -> Bool = { [weak self] in self?.checkScanCancelled() ?? false }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            do {
                let bundle = try CleanupService.performScan(
                    options: options,
                    shouldCancel: shouldCancelFn
                ) { update in
                    DispatchQueue.main.async { [weak self] in
                        self?.scanProgress = update.progress
                        self?.stageTitlePayload = .raw(update.title)
                        self?.stageDetailPayload = .raw(update.detail)
                    }
                }

                DispatchQueue.main.async { [weak self] in
                    self?.applyScanBundle(bundle, previousSelection: previousSelection, safeMode: currentSafeMode)
                }
            } catch CleanupServiceError.scanCancelled {
                DispatchQueue.main.async { [weak self] in
                    self?.isScanning = false
                    self?.scanProgress = 0
                    self?.setStage(title: .localized("Tarama iptal edildi"), detail: .localized("Kullanici taraflı iptal."))
                    self?.appendActivity(.localized("Tarama kullanici tarafindan iptal edildi."), style: .warning)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.isScanning = false
                    self?.setStage(title: .localized("Tarama basarisiz"), detail: .raw(error.localizedDescription))
                    self?.appendActivity(.localized("Tarama hatasi: %@", arguments: [error.localizedDescription]), style: .failure)
                    self?.showToast(.localized("Tarama tamamlanamadi."))
                }
            }
        }
    }

    func cancelScan() {
        guard isScanning else { return }
        setScanCancelled(true)
    }

    func runCleanup() {
        guard !isCleaning, !isScanning else { return }

        let actionable = selectedResults.filter(\.isActionable)
        guard !actionable.isEmpty else {
            showToast(.localized("Temizlenecek secili oge yok."))
            return
        }

        isCleaning = true
        setStage(title: .localized("Temizlik basladi"), detail: .localized("Secili ogeler Cop Kutusu ve komut katmani ile temizlenecek."))
        appendActivity(.localized("%@ kategori icin temizlik akisi baslatildi.", arguments: ["\(actionable.count)"]), style: .warning)

        let snapshotEnabled = snapshotBeforeCleanup

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            do {
                let outcome = try CleanupService.performCleanup(
                    results: actionable,
                    snapshotEnabled: snapshotEnabled,
                    progress: { message in
                        DispatchQueue.main.async { [weak self] in self?.stageDetailPayload = .raw(message) }
                    }
                )

                DispatchQueue.main.async { [weak self] in self?.finishCleanup(outcome: outcome) }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.isCleaning = false
                    self?.appendActivity(.localized("Temizlik hatasi: %@", arguments: [error.localizedDescription]), style: .failure)
                    self?.showToast(.localized("Temizlik akisi durdu."))
                    self?.setStage(title: .localized("Temizlik basarisiz"), detail: .raw(error.localizedDescription))
                }
            }
        }
    }

    // MARK: - Preferences

    func setSafeMode(_ enabled: Bool) {
        safeMode = enabled
        UserDefaults.standard.set(enabled, forKey: Defaults.safeMode)
        if enabled { selectedCategories = Set(orderedResults.filter { $0.safety == .safe && $0.isActionable }.map(\.category)) }
        appendActivity(.localized("Guvenli mod %@.", arguments: [L10n.tr(enabled ? "acildi" : "kapatildi")]), style: enabled ? .success : .warning)
    }

    func setDeepScan(_ enabled: Bool) {
        deepScan = enabled
        UserDefaults.standard.set(enabled, forKey: Defaults.deepScan)
        appendActivity(.localized("Derin tarama %@.", arguments: [L10n.tr(enabled ? "acildi" : "kapatildi")]), style: .info)
        if hasPerformedInitialScan { startScan(manual: false) }
    }

    func setSnapshotPreference(_ enabled: Bool) {
        snapshotBeforeCleanup = enabled
        UserDefaults.standard.set(enabled, forKey: Defaults.snapshot)
        appendActivity(.localized("Snapshot manifesti %@.", arguments: [L10n.tr(enabled ? "etkin" : "kapali")]), style: enabled ? .success : .warning)
    }

    func setSchedule(_ value: MaintenanceSchedule) {
        schedule = value
        UserDefaults.standard.set(value.rawValue, forKey: Defaults.schedule)
        appendActivity(.localized("Bakim ritmi %@ olarak guncellendi.", arguments: [value.title]), style: .info)
    }

    func commitThresholdChange() {
        UserDefaults.standard.set(threshold, forKey: Defaults.threshold)
        appendActivity(.localized("Disk esigi %@ olarak kaydedildi.", arguments: ["%\(Int(threshold.rounded()))"]), style: .info)
    }

    func setThemeAccent(_ accent: ThemeAccent) {
        themeAccent = accent
        UserDefaults.standard.set(accent.rawValue, forKey: Defaults.themeAccent)
    }

    // MARK: - Onboarding

    func applyProfile(_ profile: SetupProfile) {
        setSafeMode(profile.safeMode)
        setDeepScan(profile.deepScan)
        setSchedule(profile.schedule)
        appendActivity(.localized("Kurulum profili uygulandi: %@", arguments: [profile.title]), style: .success)
    }

    func completeOnboarding(profile: SetupProfile, theme: ThemeAccent) {
        applyProfile(profile)
        setThemeAccent(theme)
        UserDefaults.standard.set(true, forKey: Defaults.onboarding)
        showOnboarding = false
    }

    func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: Defaults.onboarding)
        showOnboarding = true
    }

    // MARK: - LaunchAgent automation

    private var launchAgentPlistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.mertsert.maccleanerpro.plist")
    }

    func toggleLaunchAgent() {
        if launchAgentInstalled { uninstallLaunchAgent() } else { installLaunchAgent() }
    }

    private func installLaunchAgent() {
        guard let executablePath = Bundle.main.executablePath ?? ProcessInfo.processInfo.arguments.first else {
            appendActivity(.localized("LaunchAgent kurulamadi: uygulama yolu bulunamadi."), style: .failure)
            return
        }

        let intervalSeconds: Int
        switch schedule {
        case .daily:   intervalSeconds = 86_400
        case .weekly:  intervalSeconds = 604_800
        case .monthly: intervalSeconds = 2_592_000
        }

        let plist: [String: Any] = [
            "Label": "com.mertsert.maccleanerpro",
            "ProgramArguments": [executablePath],
            "StartInterval": intervalSeconds,
            "RunAtLoad": false,
            "KeepAlive": false,
            "StandardOutPath": FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs/MacCleanerPro-daemon.log").path,
            "StandardErrorPath": FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs/MacCleanerPro-daemon-error.log").path,
        ]

        do {
            let dir = launchAgentPlistURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: launchAgentPlistURL, options: .atomic)
            CleanupService.runLaunchCtl(["load", "-w", launchAgentPlistURL.path])
            launchAgentInstalled = true
            appendActivity(.localized("LaunchAgent kuruldu. Arka plan bakim aktif."), style: .success)
            showToast(.localized("Arka plan bakim aktif edildi."))
        } catch {
            appendActivity(.localized("LaunchAgent kurulamadi: %@", arguments: [error.localizedDescription]), style: .failure)
        }
    }

    private func uninstallLaunchAgent() {
        CleanupService.runLaunchCtl(["unload", "-w", launchAgentPlistURL.path])
        do {
            try FileManager.default.removeItem(at: launchAgentPlistURL)
            launchAgentInstalled = false
            appendActivity(.localized("LaunchAgent kaldirildi. Arka plan bakim devre disi."), style: .info)
            showToast(.localized("Arka plan bakim devre disi."))
        } catch {
            appendActivity(.localized("LaunchAgent kaldirilamadi: %@", arguments: [error.localizedDescription]), style: .failure)
        }
    }

    // MARK: - Notifications

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            DispatchQueue.main.async { self?.notificationsAuthorized = granted }
        }
    }

    private func sendNotification(title: String, body: String) {
        guard notificationsAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Actions

    func didChangeLanguage() {
        objectWillChange.send()
        appendActivity(.localized("Dil secimi degisti. Arayuz yenileniyor."), style: .info)
        if hasPerformedInitialScan && !isScanning && !isCleaning { startScan(manual: false) }
    }

    func exportReport() {
        let report = buildReportText()

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }

            do {
                let url = try CleanupService.exportReport(report: report)
                DispatchQueue.main.async { [weak self] in
                    self?.reportURL = url
                    self?.appendActivity(.localized("Rapor disa aktarildi: %@", arguments: [url.lastPathComponent]), style: .success)
                    self?.showToast(.localized("Rapor olusturuldu."))
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.appendActivity(.localized("Rapor yazilamadi: %@", arguments: [error.localizedDescription]), style: .failure)
                    self?.showToast(.localized("Rapor yazilamadi."))
                }
            }
        }
    }

    func reveal(result: CleanupScanResult) {
        guard let firstURL = result.urls.first else {
            showToast(.localized("Finder acilacak dosya bulunmadi."))
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([firstURL])
    }

    func openReport()           { guard let u = reportURL   else { return }; NSWorkspace.shared.activateFileViewerSelecting([u]) }
    func openSnapshotManifest() { guard let u = snapshotURL else { return }; NSWorkspace.shared.activateFileViewerSelecting([u]) }

    func toggleSelection(for result: CleanupScanResult) {
        guard result.isActionable else { return }

        if safeMode && result.safety != .safe {
            showToast(.localized("Guvenli mod bu kategoriyi secmiyor."))
            return
        }

        if selectedCategories.contains(result.category) {
            selectedCategories.remove(result.category)
            appendActivity(.localized("%@ plandan cikarildi.", arguments: [result.category.title]), style: .info)
        } else {
            selectedCategories.insert(result.category)
            appendActivity(.localized("%@ plana eklendi.", arguments: [result.category.title]), style: .success)
        }
    }

    // MARK: - Private helpers

    private func applyScanBundle(
        _ bundle: ScanBundle,
        previousSelection: Set<CleanupCategory>,
        safeMode: Bool
    ) {
        results = bundle.results
        diskSummary = bundle.diskSummary
        isScanning = false
        scanProgress = 1.0
        lastScanDate = Date()
        setStage(
            title: .localized("Tarama tamamlandi"),
            detail: .localized("%@ temizlenebilir alan bulundu.", arguments: [bundle.results.totalBytes.formattedBytes])
        )

        let actionableCategories = Set(bundle.results.filter(\.isActionable).map(\.category))

        if safeMode {
            // In safe mode always enforce safe-only selection.
            selectedCategories = Set(bundle.results.filter { $0.safety == .safe && $0.isActionable }.map(\.category))
        } else {
            // Preserve user's existing selection — only drop categories that are no longer actionable.
            let preserved = previousSelection.intersection(actionableCategories)
            if preserved.isEmpty {
                // Nothing the user had selected is actionable; fall back to defaults.
                selectedCategories = Set(bundle.results.filter { $0.category.defaultSelected && $0.isActionable }.map(\.category))
            } else {
                selectedCategories = preserved
            }
        }

        let totalFound = reclaimableBytes
        appendActivity(.localized("Tarama tamamlandi. %@ aday alan hesaplandi.", arguments: [totalFound.formattedBytes]), style: .success)
        showToast(.localized("Tarama tamamlandi"))
        sendNotification(
            title: "MacCleanerPro",
            body: L10n.format("Tarama tamamlandi. %@ temizlenebilir alan bulundu.", totalFound.formattedBytes)
        )
    }

    private func finishCleanup(outcome: CleanupOutcome) {
        isCleaning = false
        lastCleanupDate = Date()
        snapshotURL = outcome.snapshotURL
        setStage(
            title: .localized("Temizlik tamamlandi"),
            detail: .localized("%@ alan temizlendi.", arguments: [outcome.cleanedBytes.formattedBytes])
        )
        appendActivity(
            .localized(
                "Temizlik tamamlandi. %@ oge Cop Kutusu'na tasindi, %@ alan acildi.",
                arguments: ["\(outcome.cleanedItems)", outcome.cleanedBytes.formattedBytes]
            ),
            style: .success
        )
        for warning in outcome.warnings.prefix(3) { appendActivity(.raw(warning), style: .warning) }

        sendNotification(
            title: "MacCleanerPro",
            body: L10n.format("Temizlik tamamlandi. %@ alan acildi.", outcome.cleanedBytes.formattedBytes)
        )
        showToast(.localized("Temizlik tamamlandi. Yeni tarama baslatiliyor."))
        startScan(manual: false)
    }

    private func buildReportText() -> String {
        let selectedLines = selectedResults.map {
            L10n.format("- %@: %@ · %@ oge · %@", $0.category.title, $0.bytes.formattedBytes, "\($0.itemCount)", $0.safety.title)
        }.joined(separator: "\n")

        return """
        \(L10n.tr("MacCleanerPro Gercek Tarama Raporu"))
        \(L10n.format("Tarih: %@", Date().shortTimestamp))
        \(L10n.format("Versiyon: %@", appVersionString))

        \(L10n.format("Son tarama: %@", lastScanLabel))
        \(L10n.format("Son temizlik: %@", lastCleanupDate?.shortTimestamp ?? L10n.tr("Henuz yok")))
        \(L10n.format("Toplam aday alan: %@", reclaimableBytes.formattedBytes))
        \(L10n.format("Secili plan: %@", selectedBytes.formattedBytes))
        \(L10n.format("Tahmini sonraki bos alan: %@", freeSpaceAfterCleanup.formattedBytes))
        \(L10n.format("Risk profili: %@", riskLabel))
        \(L10n.format("Bakim ritmi: %@", schedule.title))
        \(L10n.format("Disk esigi: %@", "%\(Int(threshold.rounded()))"))
        \(L10n.format("Derin tarama: %@", deepScan ? L10n.tr("Acik") : L10n.tr("Kapali")))
        \(L10n.format("Snapshot manifesti: %@", snapshotBeforeCleanup ? L10n.tr("Acik") : L10n.tr("Kapali")))
        \(L10n.format("Arka plan bakim: %@", launchAgentInstalled ? L10n.tr("Acik") : L10n.tr("Kapali")))

        \(L10n.tr("Secili kategoriler:"))
        \(selectedLines.isEmpty ? L10n.tr("- Secili kategori yok") : selectedLines)

        \(L10n.tr("Ozet:"))
        \(reportSummary)
        """
    }

    private func setStage(title: LocalizedTextPayload, detail: LocalizedTextPayload) {
        stageTitlePayload  = title
        stageDetailPayload = detail
    }

    private func appendActivity(_ payload: LocalizedTextPayload, style: ActivityStyle) {
        activities.insert(ActivityEntry(date: Date(), payload: payload, style: style), at: 0)
        activities = Array(activities.prefix(50))
    }

    private func showToast(_ payload: LocalizedTextPayload) {
        toastPayload = payload
        toastWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in self?.toastPayload = nil }
        toastWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
    }

    // Thread-safe helpers for the cancellation flag.
    private func setScanCancelled(_ value: Bool) {
        cancellationQueue.sync { _scanCancelled = value }
    }

    private func checkScanCancelled() -> Bool {
        cancellationQueue.sync { _scanCancelled }
    }
}

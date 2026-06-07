import Foundation

enum CleanupServiceError: LocalizedError {
    case commandFailed(String)
    case cleanupFailed(String)
    case exportFailed(String)
    case scanCancelled

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):  return message
        case .cleanupFailed(let message):  return message
        case .exportFailed(let message):   return message
        case .scanCancelled:               return "Scan cancelled by user."
        }
    }
}

private struct ProcessResult {
    var exitCode: Int32
    var stdout: String
    var stderr: String
}

private struct SnapshotManifest: Codable {
    struct Entry: Codable {
        var category: String
        var bytes: Int64
        var itemCount: Int
        var paths: [String]
    }

    var createdAt: Date
    var entries: [Entry]
}

private struct DockerRow: Decodable {
    let type: String
    let reclaimable: String

    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case reclaimable = "Reclaimable"
    }
}

// Resolved at first use and cached.
private let dockerExecutablePath: String = {
    let candidates = [
        "/usr/local/bin/docker",
        "/opt/homebrew/bin/docker",
        "/opt/homebrew/opt/docker/bin/docker",
        "/usr/bin/docker",
    ]
    return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? ""
}()

enum CleanupService {
    static func performScan(
        options: ScanOptions,
        shouldCancel: @escaping () -> Bool = { false },
        progress: @escaping (ScanStageUpdate) -> Void
    ) throws -> ScanBundle {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let totalStages = 16.0
        var completedStages = 0.0

        func advance(title: String, detail: String) {
            completedStages += 1
            progress(ScanStageUpdate(
                title: title,
                detail: detail,
                progress: min(completedStages / totalStages, 0.98)
            ))
        }

        func checkCancellation() throws {
            if shouldCancel() { throw CleanupServiceError.scanCancelled }
        }

        try checkCancellation()
        advance(title: L10n.tr("Cache alanlari taraniyor"), detail: L10n.tr("Library/Caches ve gerekiyorsa container cache klasorleri okunuyor."))
        let caches = scanUserCaches(home: home, options: options)

        try checkCancellation()
        advance(title: L10n.tr("Log arsivleri okunuyor"), detail: L10n.tr("Tani loglari, crash raporlari ve ilgili klasorler gruplanıyor."))
        let logs = scanLogs(home: home, options: options)

        try checkCancellation()
        advance(title: L10n.tr("DerivedData olculuyor"), detail: L10n.tr("Xcode DerivedData artıkları gercek boyutlariyla taraniyor."))
        let derivedData = scanDerivedData(home: home)

        try checkCancellation()
        advance(title: L10n.tr("Simulator ve cihaz destek dosyalari taraniyor"), detail: L10n.tr("CoreSimulator cache ve device support klasorleri hesaplaniyor."))
        let deviceSupport = scanDeviceSupport(home: home)

        try checkCancellation()
        advance(title: L10n.tr("Mail indirilenleri kontrol ediliyor"), detail: L10n.tr("Apple Mail tarafinda lokal kopyalanan ek klasorleri okunuyor."))
        let mailDownloads = scanMailDownloads(home: home)

        try checkCancellation()
        advance(title: L10n.tr("iOS yedekleri kontrol ediliyor"), detail: L10n.tr("Finder uzerinden alinmis MobileSync yedekleri aranıyor."))
        let iosBackups = scanIOSBackups(home: home)

        try checkCancellation()
        advance(title: L10n.tr("Downloads sinifi filtreleniyor"), detail: L10n.tr("Buyuk ve eski indirilen dosyalar esiklere gore seciliyor."))
        let downloads = scanLargeDownloads(home: home, options: options)

        try checkCancellation()
        advance(title: L10n.tr("Docker ozeti alinıyor"), detail: L10n.tr("Docker CLI varsa reclaimable alan ve prune secenegi hazirlaniyor."))
        let docker = scanDocker()

        try checkCancellation()
        advance(title: L10n.tr("Cop Kutusu kontrol ediliyor"), detail: L10n.tr("Kalici silme icin Cop Kutusu icerigi olculuyor."))
        let trashBin = scanTrashBin(home: home)

        try checkCancellation()
        advance(title: L10n.tr("Sistem gecici dosyalari taraniyor"), detail: L10n.tr("TMPDIR altindaki eski gecici dosyalar tespit ediliyor."))
        let systemJunk = scanSystemJunk()

        try checkCancellation()
        advance(title: L10n.tr("Tarayici onbellekleri olculuyor"), detail: L10n.tr("Safari, Chrome ve Firefox onbellek klasorleri taraniyor."))
        let browserCaches = scanBrowserCaches(home: home)

        try checkCancellation()
        advance(title: L10n.tr("Xcode arsivleri taraniyor"), detail: L10n.tr("Gecmis .xcarchive paketleri gercek boyutlariyla olculuyor."))
        let xcodeArchives = scanXcodeArchives(home: home)

        try checkCancellation()
        advance(title: L10n.tr("Gelistirici paket onbellekleri taraniyor"), detail: L10n.tr("Homebrew, npm, pip ve cargo onbellek klasorleri olculuyor."))
        let packageCaches = scanPackageCaches(home: home)

        try checkCancellation()
        advance(title: L10n.tr("Buyuk ve eski dosyalar taraniyor"), detail: L10n.tr("Belgeler, Masaustu ve medya klasorlerinde esik disindaki dosyalar bulunuyor."))
        let largeOldFiles = scanLargeOldFiles(home: home)

        try checkCancellation()
        advance(title: L10n.tr("Uygulama artiklari kontrol ediliyor"), detail: L10n.tr("Yuklu uygulama listesiyle eslesmeyen Library klasorleri tespit ediliyor."))
        let appLeftovers = scanAppLeftovers(home: home)

        try checkCancellation()
        advance(title: L10n.tr("Fotograf kutuphanesi onbellegi olculuyor"), detail: L10n.tr("Photos turetilmis onizleme verisi bilgi amacli olculuyor."))
        let photoJunk = scanPhotoJunk(home: home)

        let diskSummary = try filesystemSummary(home: home)
        let results = [
            caches, logs, derivedData, deviceSupport, mailDownloads, iosBackups, downloads, docker,
            trashBin, systemJunk, browserCaches, xcodeArchives, packageCaches, largeOldFiles, appLeftovers, photoJunk,
        ]
            .sorted { lhs, rhs in
                lhs.bytes != rhs.bytes ? lhs.bytes > rhs.bytes : lhs.category.title < rhs.category.title
            }

        progress(ScanStageUpdate(
            title: L10n.tr("Tarama tamamlandi"),
            detail: L10n.tr("Gercek sistem verisi okundu ve temizlenebilir alan hesaplandi."),
            progress: 1.0
        ))

        return ScanBundle(results: results, diskSummary: diskSummary)
    }

    static func performCleanup(
        results: [CleanupScanResult],
        snapshotEnabled: Bool,
        progress: @escaping (String) -> Void
    ) throws -> CleanupOutcome {
        let actionableResults = results.filter(\.isActionable)

        if actionableResults.isEmpty {
            throw CleanupServiceError.cleanupFailed(L10n.tr("Secili kategorilerde temizlenecek ogeler bulunmuyor."))
        }

        let snapshotURL = snapshotEnabled ? try writeSnapshotManifest(for: actionableResults) : nil
        let fileManager = FileManager.default
        var cleanedBytes: Int64 = 0
        var cleanedItems = 0
        var warnings: [String] = []

        for result in actionableResults {
            progress(L10n.format("%@ temizleniyor", result.category.title))

            switch result.category.actionKind {
            case .trash:
                for itemURL in result.urls {
                    let itemBytes = allocatedSize(of: itemURL)
                    do {
                        try fileManager.trashItem(at: itemURL, resultingItemURL: nil)
                        cleanedItems += 1
                        cleanedBytes += itemBytes
                    } catch {
                        let nsError = error as NSError
                        // File already gone - skip silently
                        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileNoSuchFileError {
                            continue
                        }
                        warnings.append(L10n.format("%@ tasinamadi: %@", itemURL.lastPathComponent, error.localizedDescription))
                    }
                }

            case .permanentDelete:
                // Items here (e.g. Trash contents) are deleted outright instead of being
                // moved to Trash again — this mirrors Finder's "Empty Trash" and is irreversible.
                for itemURL in result.urls {
                    let itemBytes = allocatedSize(of: itemURL)
                    do {
                        try fileManager.removeItem(at: itemURL)
                        cleanedItems += 1
                        cleanedBytes += itemBytes
                    } catch {
                        let nsError = error as NSError
                        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileNoSuchFileError {
                            continue
                        }
                        warnings.append(L10n.format("%@ silinemedi: %@", itemURL.lastPathComponent, error.localizedDescription))
                    }
                }

            case .dockerPrune:
                guard !dockerExecutablePath.isEmpty, result.bytes > 0 else {
                    warnings.append(L10n.tr("Docker bulunamadi veya temizlenecek alan yok."))
                    continue
                }
                do {
                    let commandResult = try runProcess(
                        executable: dockerExecutablePath,
                        arguments: ["system", "prune", "-af"],
                        timeoutSeconds: 120
                    )
                    if commandResult.exitCode == 0 {
                        cleanedItems += max(1, result.itemCount)
                        cleanedBytes += result.bytes
                    } else {
                        let msg = commandResult.stderr.isEmpty ? commandResult.stdout : commandResult.stderr
                        warnings.append(L10n.format("Docker prune hatasi: %@", msg))
                    }
                } catch {
                    warnings.append(L10n.format("Docker prune calistirilamadi: %@", error.localizedDescription))
                }
            }
        }

        if cleanedItems == 0 && !warnings.isEmpty {
            throw CleanupServiceError.cleanupFailed(warnings.joined(separator: "\n"))
        }

        return CleanupOutcome(
            cleanedBytes: cleanedBytes,
            cleanedItems: cleanedItems,
            snapshotURL: snapshotURL,
            warnings: warnings
        )
    }

    static func exportReport(report: String) throws -> URL {
        let baseDirectory = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let reportURL = baseDirectory.appendingPathComponent("MacCleanerPro-Report-\(Date().fileStamp).txt")

        do {
            try report.write(to: reportURL, atomically: true, encoding: .utf8)
        } catch {
            throw CleanupServiceError.exportFailed(error.localizedDescription)
        }

        return reportURL
    }

    // MARK: - Internal utilities (accessible for LaunchAgent management)

    static func runLaunchCtl(_ args: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = args
        process.environment = minimalEnvironment()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    // MARK: - Private scan implementations

    private static func filesystemSummary(home: URL) throws -> DiskSummary {
        let attributes = try FileManager.default.attributesOfFileSystem(forPath: home.path)
        let total = (attributes[.systemSize] as? NSNumber)?.int64Value ?? 0
        let free = (attributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        return DiskSummary(total: total, free: free)
    }

    private static func scanUserCaches(home: URL, options: ScanOptions) -> CleanupScanResult {
        var roots = [home.appendingPathComponent("Library/Caches", isDirectory: true)]

        if options.includeDeepScan {
            roots.append(contentsOf: containerRoots(
                at: home.appendingPathComponent("Library/Containers", isDirectory: true),
                suffix: "Data/Library/Caches"
            ))
        }

        return buildDirectoryResult(category: .userCaches, roots: roots)
    }

    private static func scanLogs(home: URL, options: ScanOptions) -> CleanupScanResult {
        var roots = [
            home.appendingPathComponent("Library/Logs", isDirectory: true),
            home.appendingPathComponent("Library/Application Support/CrashReporter", isDirectory: true),
        ]

        if options.includeDeepScan {
            roots.append(contentsOf: containerRoots(
                at: home.appendingPathComponent("Library/Containers", isDirectory: true),
                suffix: "Data/Library/Logs"
            ))
        }

        return buildDirectoryResult(category: .logArchives, roots: roots)
    }

    private static func scanDerivedData(home: URL) -> CleanupScanResult {
        buildDirectoryResult(
            category: .derivedData,
            roots: [home.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true)]
        )
    }

    private static func scanDeviceSupport(home: URL) -> CleanupScanResult {
        buildDirectoryResult(
            category: .deviceSupport,
            roots: [
                home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport", isDirectory: true),
                home.appendingPathComponent("Library/Developer/CoreSimulator/Caches", isDirectory: true),
            ]
        )
    }

    private static func scanMailDownloads(home: URL) -> CleanupScanResult {
        buildDirectoryResult(
            category: .mailDownloads,
            roots: [home.appendingPathComponent(
                "Library/Containers/com.apple.mail/Data/Library/Mail Downloads",
                isDirectory: true
            )]
        )
    }

    private static func scanIOSBackups(home: URL) -> CleanupScanResult {
        buildDirectoryResult(
            category: .iosBackups,
            roots: [home.appendingPathComponent(
                "Library/Application Support/MobileSync/Backup",
                isDirectory: true
            )]
        )
    }

    private static func scanLargeDownloads(home: URL, options: ScanOptions) -> CleanupScanResult {
        let downloadsRoot = home.appendingPathComponent("Downloads", isDirectory: true)
        let thresholdBytes = Int64(options.largeDownloadThresholdMB) * 1_048_576
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -options.largeDownloadAgeDays,
            to: Date()
        ) ?? .distantPast

        return buildDirectoryResult(
            category: .largeDownloads,
            roots: [downloadsRoot],
            filter: { _, resourceValues in
                let itemDate = resourceValues.contentModificationDate ?? .distantFuture
                let fileSize = Int64(
                    resourceValues.totalFileAllocatedSize
                    ?? resourceValues.fileAllocatedSize
                    ?? resourceValues.fileSize
                    ?? 0
                )
                let isFile = resourceValues.isRegularFile ?? false
                return isFile && fileSize >= thresholdBytes && itemDate <= cutoffDate
            }
        )
    }

    private static func scanTrashBin(home: URL) -> CleanupScanResult {
        buildDirectoryResult(
            category: .trashBin,
            roots: [home.appendingPathComponent(".Trash", isDirectory: true)]
        )
    }

    // Scans the per-user TMPDIR (/private/var/folders/.../T) for files that have
    // not been touched in a few days — fresh temp files may still be in active use.
    private static func scanSystemJunk() -> CleanupScanResult {
        let tmpRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? .distantPast

        return buildDirectoryResult(
            category: .systemJunk,
            roots: [tmpRoot],
            filter: { _, resourceValues in
                let itemDate = resourceValues.contentModificationDate ?? .distantFuture
                return itemDate <= cutoffDate
            }
        )
    }

    private static func scanBrowserCaches(home: URL) -> CleanupScanResult {
        let relativePaths = [
            "Library/Caches/com.apple.Safari",
            "Library/Containers/com.apple.Safari/Data/Library/Caches",
            "Library/Caches/Google/Chrome",
            "Library/Caches/Google/Chrome Beta",
            "Library/Caches/Google/Chrome Canary",
            "Library/Caches/com.google.Chrome",
            "Library/Caches/BraveSoftware/Brave-Browser",
            "Library/Caches/com.brave.Browser",
            "Library/Caches/Firefox",
            "Library/Caches/Mozilla/Firefox",
            "Library/Caches/com.microsoft.edgemac",
            "Library/Caches/company.thebrowser.Browser",
            "Library/Caches/com.operasoftware.Opera",
            "Library/Caches/com.vivaldi.Vivaldi",
        ]

        return buildDirectoryResult(
            category: .browserCaches,
            roots: relativePaths.map { home.appendingPathComponent($0, isDirectory: true) }
        )
    }

    private static func scanXcodeArchives(home: URL) -> CleanupScanResult {
        buildDirectoryResult(
            category: .xcodeArchives,
            roots: [home.appendingPathComponent("Library/Developer/Xcode/Archives", isDirectory: true)]
        )
    }

    private static func scanPackageCaches(home: URL) -> CleanupScanResult {
        let relativePaths = [
            "Library/Caches/Homebrew",
            "Library/Caches/pip",
            "Library/Caches/Yarn",
            "Library/Caches/CocoaPods",
            "Library/Caches/go-build",
            "Library/Caches/com.apple.dt.Xcode/SymbolCache",
            ".npm/_cacache",
            ".cache/pip",
            ".cargo/registry/cache",
            "go/pkg/mod/cache",
            ".gradle/caches",
            ".bundle/cache",
        ]

        return buildDirectoryResult(
            category: .packageCaches,
            roots: relativePaths.map { home.appendingPathComponent($0, isDirectory: true) }
        )
    }

    // Recursively scans common personal-file folders for large files that have not
    // been modified in a long time — distinct from the Downloads-only large-file scan.
    private static func scanLargeOldFiles(home: URL) -> CleanupScanResult {
        let thresholdBytes: Int64 = 200 * 1_048_576
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -45, to: Date()) ?? .distantPast
        let relativeRoots = ["Documents", "Desktop", "Movies", "Music", "Pictures"]
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .contentModificationDateKey,
            .fileSizeKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey,
        ]

        var scannedRoots: [String] = []
        var sizedItems: [(url: URL, bytes: Int64)] = []

        for relativeRoot in relativeRoots {
            let root = home.appendingPathComponent(relativeRoot, isDirectory: true)
            guard FileManager.default.fileExists(atPath: root.path) else { continue }
            scannedRoots.append(root.path)

            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }

            for case let fileURL as URL in enumerator {
                guard let values = try? fileURL.resourceValues(forKeys: keys) else { continue }
                guard values.isSymbolicLink != true, values.isRegularFile == true else { continue }

                let bytes = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
                let modified = values.contentModificationDate ?? .distantFuture
                guard bytes >= thresholdBytes, modified <= cutoffDate else { continue }

                sizedItems.append((fileURL, bytes))
            }
        }

        sizedItems.sort { lhs, rhs in
            lhs.bytes != rhs.bytes ? lhs.bytes > rhs.bytes : lhs.url.lastPathComponent < rhs.url.lastPathComponent
        }

        let notes = sizedItems.isEmpty
            ? [CleanupCategory.largeOldFiles.emptyStateNote]
            : sizedItems.prefix(3).map { "\($0.url.lastPathComponent) · \($0.bytes.formattedBytes)" }

        return CleanupScanResult(
            category: .largeOldFiles,
            bytes: sizedItems.reduce(0) { $0 + $1.bytes },
            itemCount: sizedItems.count,
            itemPaths: sizedItems.map { $0.url.path },
            notes: notes,
            shellCommand: nil,
            scannedRoots: scannedRoots,
            lastUpdated: Date()
        )
    }

    // Flags Library data folders whose name looks like a bundle identifier but no
    // longer corresponds to any application installed in /Applications or ~/Applications.
    // Conservative by design: skips Apple's own identifiers and anything under 1 MB.
    private static func scanAppLeftovers(home: URL) -> CleanupScanResult {
        let installedBundleIDs = installedApplicationBundleIdentifiers()
        let leftoverRoots = [
            home.appendingPathComponent("Library/Application Support", isDirectory: true),
            home.appendingPathComponent("Library/Caches", isDirectory: true),
            home.appendingPathComponent("Library/Saved Application State", isDirectory: true),
            home.appendingPathComponent("Library/HTTPStorages", isDirectory: true),
            home.appendingPathComponent("Library/WebKit", isDirectory: true),
        ]
        let minimumBytes: Int64 = 1_048_576

        var scannedRoots: [String] = []
        var sizedItems: [(url: URL, bytes: Int64)] = []
        var seenPaths = Set<String>()

        for root in leftoverRoots where FileManager.default.fileExists(atPath: root.path) {
            scannedRoots.append(root.path)

            for child in directChildren(of: root) {
                var identifier = child.lastPathComponent
                if identifier.hasSuffix(".savedState") {
                    identifier = String(identifier.dropLast(".savedState".count))
                }

                guard looksLikeBundleIdentifier(identifier) else { continue }
                guard !identifier.hasPrefix("com.apple.") else { continue }
                guard !installedBundleIDs.contains(where: {
                    identifier == $0 || identifier.hasPrefix($0 + ".") || $0.hasPrefix(identifier + ".")
                }) else { continue }
                guard seenPaths.insert(child.path).inserted else { continue }

                let bytes = allocatedSize(of: child)
                guard bytes >= minimumBytes else { continue }
                sizedItems.append((child, bytes))
            }
        }

        sizedItems.sort { lhs, rhs in
            lhs.bytes != rhs.bytes ? lhs.bytes > rhs.bytes : lhs.url.lastPathComponent < rhs.url.lastPathComponent
        }

        let notes = sizedItems.isEmpty
            ? [CleanupCategory.appLeftovers.emptyStateNote]
            : sizedItems.prefix(3).map { "\($0.url.lastPathComponent) · \($0.bytes.formattedBytes)" }

        return CleanupScanResult(
            category: .appLeftovers,
            bytes: sizedItems.reduce(0) { $0 + $1.bytes },
            itemCount: sizedItems.count,
            itemPaths: sizedItems.map { $0.url.path },
            notes: notes,
            shellCommand: nil,
            scannedRoots: scannedRoots,
            lastUpdated: Date()
        )
    }

    // Reverse-DNS bundle identifiers have at least three dot-separated, alphanumeric components.
    private static func looksLikeBundleIdentifier(_ name: String) -> Bool {
        let parts = name.split(separator: ".")
        guard parts.count >= 3 else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        }
    }

    private static func installedApplicationBundleIdentifiers() -> Set<String> {
        let searchRoots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
        ]

        var identifiers = Set<String>()

        for root in searchRoots {
            guard let apps = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsSubdirectoryDescendants]
            ) else { continue }

            for appURL in apps where appURL.pathExtension == "app" {
                let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
                guard let data = try? Data(contentsOf: infoPlistURL),
                      let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                      let bundleID = plist["CFBundleIdentifier"] as? String
                else { continue }
                identifiers.insert(bundleID)
            }
        }

        return identifiers
    }

    // Reports the size of derived/cache data inside the Photos library purely for visibility.
    // Deliberately informational-only (no itemPaths/shellCommand) — touching files inside a
    // .photoslibrary bundle directly risks corrupting the library, so no delete action is offered.
    private static func scanPhotoJunk(home: URL) -> CleanupScanResult {
        let relativePaths = [
            "Pictures/Photos Library.photoslibrary/database/Caches",
            "Pictures/Photos Library.photoslibrary/resources/derivatives",
            "Pictures/Photos Library.photoslibrary/private/com.apple.Safari",
        ]

        var scannedRoots: [String] = []
        var notes: [String] = []
        var totalBytes: Int64 = 0

        for relativePath in relativePaths {
            let url = home.appendingPathComponent(relativePath, isDirectory: true)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }

            let bytes = allocatedSize(of: url)
            scannedRoots.append(url.path)
            totalBytes += bytes
            notes.append("\(url.lastPathComponent) · \(bytes.formattedBytes)")
        }

        return CleanupScanResult(
            category: .photoJunk,
            bytes: totalBytes,
            itemCount: scannedRoots.count,
            itemPaths: [],
            notes: notes.isEmpty ? [CleanupCategory.photoJunk.emptyStateNote] : notes,
            shellCommand: nil,
            scannedRoots: scannedRoots,
            lastUpdated: Date()
        )
    }

    private static func scanDocker() -> CleanupScanResult {
        guard !dockerExecutablePath.isEmpty else {
            return emptyDockerResult(note: CleanupCategory.docker.emptyStateNote)
        }

        do {
            let result = try runProcess(
                executable: dockerExecutablePath,
                arguments: ["system", "df", "--format", "{{json .}}"],
                timeoutSeconds: 15
            )

            guard result.exitCode == 0 else {
                let note = result.stderr.isEmpty ? CleanupCategory.docker.emptyStateNote : result.stderr
                return emptyDockerResult(note: note)
            }

            let lines = result.stdout
                .split(whereSeparator: \.isNewline)
                .map(String.init)
                .filter { !$0.isEmpty }

            let decoder = JSONDecoder()
            var rows: [DockerRow] = []

            for line in lines {
                guard let data = line.data(using: .utf8) else { continue }
                if let row = try? decoder.decode(DockerRow.self, from: data) {
                    rows.append(row)
                }
            }

            let reclaimableBytes = rows.reduce(into: Int64(0)) { acc, row in
                acc += parseHumanByteCount(from: row.reclaimable)
            }

            let notes = rows.isEmpty
                ? [CleanupCategory.docker.emptyStateNote]
                : rows.prefix(3).map { "\($0.type) · \(parseHumanByteCount(from: $0.reclaimable).formattedBytes)" }

            return CleanupScanResult(
                category: .docker,
                bytes: reclaimableBytes,
                itemCount: rows.count,
                itemPaths: [],
                notes: notes,
                shellCommand: rows.isEmpty ? nil : "docker system prune -af",
                scannedRoots: [dockerExecutablePath],
                lastUpdated: Date()
            )
        } catch {
            return emptyDockerResult(note: CleanupCategory.docker.emptyStateNote)
        }
    }

    private static func emptyDockerResult(note: String) -> CleanupScanResult {
        CleanupScanResult(
            category: .docker,
            bytes: 0,
            itemCount: 0,
            itemPaths: [],
            notes: [note],
            shellCommand: nil,
            scannedRoots: ["docker system df"],
            lastUpdated: Date()
        )
    }

    private static func buildDirectoryResult(
        category: CleanupCategory,
        roots: [URL],
        filter: ((URL, URLResourceValues) -> Bool)? = nil
    ) -> CleanupScanResult {
        let fileManager = FileManager.default
        var scannedRoots: [String] = []
        var sizedItems: [(url: URL, bytes: Int64)] = []

        for root in roots where fileManager.fileExists(atPath: root.path) {
            scannedRoots.append(root.path)

            for candidate in directChildren(of: root, filter: filter) {
                sizedItems.append((candidate, allocatedSize(of: candidate)))
            }
        }

        sizedItems.sort { lhs, rhs in
            lhs.bytes != rhs.bytes ? lhs.bytes > rhs.bytes : lhs.url.lastPathComponent < rhs.url.lastPathComponent
        }

        let notes = sizedItems.isEmpty
            ? [category.emptyStateNote]
            : sizedItems.prefix(3).map { "\($0.url.lastPathComponent) · \($0.bytes.formattedBytes)" }

        return CleanupScanResult(
            category: category,
            bytes: sizedItems.reduce(0) { $0 + $1.bytes },
            itemCount: sizedItems.count,
            itemPaths: sizedItems.map { $0.url.path },
            notes: notes,
            shellCommand: nil,
            scannedRoots: scannedRoots,
            lastUpdated: Date()
        )
    }

    // Enumerates only direct children, skipping symlinks.
    private static func directChildren(
        of root: URL,
        filter: ((URL, URLResourceValues) -> Bool)? = nil
    ) -> [URL] {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .contentModificationDateKey,
            .fileSizeKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey,
        ]

        guard let children = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: []
        ) else {
            return []
        }

        return children.filter { child in
            let values = (try? child.resourceValues(forKeys: keys)) ?? URLResourceValues()
            // Never follow symlinks — they could point outside the intended scope.
            guard values.isSymbolicLink != true else { return false }
            return filter?(child, values) ?? true
        }
    }

    // Recursively sums allocated size without following symbolic links.
    private static func allocatedSize(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey,
        ]

        let rootValues = try? url.resourceValues(forKeys: keys)

        if rootValues?.isSymbolicLink == true { return 0 }

        if rootValues?.isRegularFile == true {
            return Int64(rootValues?.totalFileAllocatedSize ?? rootValues?.fileAllocatedSize ?? 0)
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        var total: Int64 = 0

        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: keys)
            // Skip symbolic links to avoid counting targets that live outside the intended scope.
            if values?.isSymbolicLink == true { continue }
            total += Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        }

        return total
    }

    private static func containerRoots(at baseURL: URL, suffix: String) -> [URL] {
        guard let containerURLs = try? FileManager.default.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return []
        }

        return containerURLs.compactMap { containerURL in
            let candidate = containerURL.appendingPathComponent(suffix, isDirectory: true)
            return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
        }
    }

    private static func writeSnapshotManifest(for results: [CleanupScanResult]) throws -> URL {
        let snapshotsDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MacCleanerPro/Snapshots", isDirectory: true)
        try FileManager.default.createDirectory(
            at: snapshotsDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let manifestURL = snapshotsDirectory.appendingPathComponent("cleanup-\(Date().fileStamp).json")
        let manifest = SnapshotManifest(
            createdAt: Date(),
            entries: results.map {
                SnapshotManifest.Entry(
                    category: $0.category.title,
                    bytes: $0.bytes,
                    itemCount: $0.itemCount,
                    paths: $0.itemPaths
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(to: manifestURL, options: .atomic)
        return manifestURL
    }

    private static func runProcess(
        executable: String,
        arguments: [String],
        timeoutSeconds: Double = 30
    ) throws -> ProcessResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        // Use a clean, minimal environment to prevent profile-injection attacks.
        process.environment = minimalEnvironment()

        try process.run()

        let timedOut = DispatchSemaphore(value: 0)

        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            timedOut.signal()
        }

        if timedOut.wait(timeout: .now() + timeoutSeconds) == .timedOut {
            process.terminate()
            throw CleanupServiceError.commandFailed(
                "Process timed out after \(Int(timeoutSeconds))s: \(executable)"
            )
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData  = errorPipe.fileHandleForReading.readDataToEndOfFile()

        return ProcessResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: outputData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines),
            stderr: String(decoding: errorData,  as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func minimalEnvironment() -> [String: String] {
        [
            "PATH": "/usr/local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME": FileManager.default.homeDirectoryForCurrentUser.path,
            "LANG": "en_US.UTF-8",
            "TERM": "dumb",
        ]
    }

    // Parses Docker-style human-readable byte strings like "1.2GB (15%)" or "450MB".
    private static func parseHumanByteCount(from text: String) -> Int64 {
        // Extract the first whitespace-delimited token.
        guard let token = text.split(separator: " ").first.map(String.init) else { return 0 }

        // Strip trailing parenthetical like "(15%)" if it leaked into the token.
        let clean = token.components(separatedBy: "(").first ?? token

        let digits = clean.replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
                          .replacingOccurrences(of: ",", with: ".")
        let unit   = clean.replacingOccurrences(of: "[0-9.,]", with: "", options: .regularExpression)
                          .uppercased()

        guard let value = Double(digits), value >= 0 else { return 0 }

        let multiplier: Double
        switch unit {
        case "TB", "TIB": multiplier = 1_099_511_627_776
        case "GB", "GIB": multiplier = 1_073_741_824
        case "MB", "MIB": multiplier = 1_048_576
        case "KB", "KIB": multiplier = 1_024
        default:          multiplier = 1
        }

        let result = value * multiplier
        // Guard against overflow before converting to Int64.
        guard result < Double(Int64.max) else { return 0 }
        return Int64(result)
    }
}

import SwiftUI

#if FULL_VERSION

@MainActor
final class MaintenanceViewModel: ObservableObject {
    @Published var runningTaskID: String?
    @Published var statusByTask: [String: String] = [:]
    @Published var pendingAdminTask: MaintenanceTask?
    @Published var showAdminConsentPrompt = false

    private let rememberKey = "maintenance.rememberAdminAuth"
    private let askedBeforeKey = "maintenance.adminAuthAsked"

    private var rememberAdminAuth: Bool {
        get { UserDefaults.standard.bool(forKey: rememberKey) }
        set { UserDefaults.standard.set(newValue, forKey: rememberKey) }
    }

    private var hasAskedBefore: Bool {
        get { UserDefaults.standard.bool(forKey: askedBeforeKey) }
        set { UserDefaults.standard.set(newValue, forKey: askedBeforeKey) }
    }

    func run(_ task: MaintenanceTask) {
        guard runningTaskID == nil else { return }

        if task.requiresAdmin {
            if !hasAskedBefore {
                pendingAdminTask = task
                showAdminConsentPrompt = true
                return
            }
            if !rememberAdminAuth {
                pendingAdminTask = task
                showAdminConsentPrompt = true
                return
            }
        }

        execute(task)
    }

    /// Called after the user responds to the "remember admin authorization?" prompt.
    func confirmPendingTask(remember: Bool) {
        hasAskedBefore = true
        rememberAdminAuth = remember

        if let task = pendingAdminTask {
            execute(task)
        }
        pendingAdminTask = nil
        showAdminConsentPrompt = false
    }

    func cancelPendingTask() {
        pendingAdminTask = nil
        showAdminConsentPrompt = false
    }

    private func execute(_ task: MaintenanceTask) {
        runningTaskID = task.id
        statusByTask[task.id] = nil

        Task.detached(priority: .userInitiated) {
            let result = task.requiresAdmin
                ? MaintenanceRunner.runWithAdmin(task)
                : MaintenanceRunner.run(task)

            await MainActor.run {
                switch result {
                case .success(let message):
                    self.statusByTask[task.id] = message
                case .failure(let message):
                    self.statusByTask[task.id] = message
                }
                self.runningTaskID = nil
            }
        }
    }
}

#endif

struct MaintenanceView: View {
    @ObservedObject var viewModel: AppViewModel

    private var primaryTeal: Color { viewModel.themeAccent.primary }
    private var copper: Color { viewModel.themeAccent.accent }

    private func t(_ base: String) -> String { L10n.tr(base) }

    var body: some View {
        #if FULL_VERSION
        FullMaintenanceView(primaryTeal: primaryTeal, copper: copper)
        #else
        VStack(alignment: .leading, spacing: 18) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(
                        title: t("Bakim ve Optimizasyon"),
                        subtitle: t("Sistem bakim ve optimizasyon araclarini calistirir.")
                    )

                    FullVersionLockNotice(
                        title: t("Bakim ve Optimizasyon Full surumde"),
                        message: t("Yonetici izniyle calisan sistem bakim araclari App Store korumali ortaminda kisitlandigi icin bu ozellik App Store surumunde kapalidir."),
                        teal: primaryTeal,
                        copper: copper
                    )
                    .help(t("Bu ozellik App Store surumunde kapalidir."))
                }
            }
        }
        #endif
    }
}

#if FULL_VERSION

private struct FullMaintenanceView: View {
    @StateObject private var viewModel = MaintenanceViewModel()

    var primaryTeal: Color
    var copper: Color

    private func t(_ base: String) -> String { L10n.tr(base) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(
                        title: t("Genel Bakim"),
                        subtitle: t("Yonetici izni gerektirmeyen, guvenli optimizasyon araclari.")
                    )

                    VStack(spacing: 8) {
                        ForEach(MaintenanceCatalog.userTasks) { task in
                            taskRow(task)
                        }
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(
                        title: t("Gelismis Bakim (Yonetici)"),
                        subtitle: t("Bu araclar sistem genelinde degisiklik yapar ve yonetici izni gerektirir.")
                    )

                    VStack(spacing: 8) {
                        ForEach(MaintenanceCatalog.adminTasks) { task in
                            taskRow(task)
                        }
                    }
                }
            }
        }
        .alert(
            t("Yonetici izni gerekiyor"),
            isPresented: $viewModel.showAdminConsentPrompt
        ) {
            Button(t("Sadece bu kez")) {
                viewModel.confirmPendingTask(remember: false)
            }
            Button(t("Hatirla, tekrar sorma")) {
                viewModel.confirmPendingTask(remember: true)
            }
            Button(t("Vazgec"), role: .cancel) {
                viewModel.cancelPendingTask()
            }
        } message: {
            Text(t("Bu islem icin macOS yonetici sifrenizi isteyecek. Bu uygulama sifrenizi gormez veya saklamaz. Sonraki yonetici islemlerinde bu onayi tekrar sormamizi ister misiniz?"))
        }
    }

    private func taskRow(_ task: MaintenanceTask) -> some View {
        let isRunning = viewModel.runningTaskID == task.id

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: task.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(task.requiresAdmin ? copper : primaryTeal)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(appInkColor)
                    Text(task.description)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    AppActionButton(
                        title: t("Calistir"),
                        systemImage: "play.fill",
                        style: task.requiresAdmin ? .secondary : .primary,
                        teal: primaryTeal,
                        copper: copper,
                        isDisabled: viewModel.runningTaskID != nil
                    ) {
                        viewModel.run(task)
                    }
                }
            }

            if let status = viewModel.statusByTask[task.id] {
                Text(status)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#endif

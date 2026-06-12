import AppKit
import SwiftUI

#if FULL_VERSION

@MainActor
final class UninstallerViewModel: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var isLoading = false
    @Published var selectedAppID: String?
    @Published var selectedLeftoverIDs: Set<String> = []
    @Published var isUninstalling = false
    @Published var statusMessage: String?

    var selectedApp: InstalledApp? {
        guard let id = selectedAppID else { return nil }
        return apps.first { $0.id == id }
    }

    func load() {
        guard apps.isEmpty, !isLoading else { return }
        isLoading = true
        Task.detached(priority: .userInitiated) {
            var list = AppUninstallerService.listInstalledApps()
            for index in list.indices {
                list[index].leftovers = AppUninstallerService.findLeftovers(for: list[index])
            }
            await MainActor.run {
                self.apps = list
                self.isLoading = false
            }
        }
    }

    func select(_ app: InstalledApp) {
        selectedAppID = app.id
        selectedLeftoverIDs = Set(app.leftovers.map { $0.id })
    }

    func uninstallSelected() {
        guard let app = selectedApp else { return }
        let leftovers = app.leftovers.filter { selectedLeftoverIDs.contains($0.id) }
        isUninstalling = true

        Task.detached(priority: .userInitiated) {
            do {
                try AppUninstallerService.uninstall(app: app, leftovers: leftovers)
                await MainActor.run {
                    self.apps.removeAll { $0.id == app.id }
                    self.selectedAppID = nil
                    self.selectedLeftoverIDs = []
                    self.isUninstalling = false
                    self.statusMessage = L10n.format("%@ ve iliskili dosyalari cope tasindi.", arguments: [app.name])
                }
            } catch {
                await MainActor.run {
                    self.isUninstalling = false
                    self.statusMessage = L10n.format("Kaldirma basarisiz: %@", arguments: [error.localizedDescription])
                }
            }
        }
    }
}

#endif

struct UninstallerView: View {
    @ObservedObject var viewModel: AppViewModel

    private var primaryTeal: Color { viewModel.themeAccent.primary }
    private var copper: Color { viewModel.themeAccent.accent }

    private func t(_ base: String) -> String { L10n.tr(base) }

    var body: some View {
        #if FULL_VERSION
        FullUninstallerView(primaryTeal: primaryTeal, copper: copper)
        #else
        VStack(alignment: .leading, spacing: 18) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(
                        title: t("Uygulama Kaldirici"),
                        subtitle: t("Yukleli uygulamalari ve iliskili dosyalarini birlikte kaldirir.")
                    )

                    FullVersionLockNotice(
                        title: t("Uygulama Kaldirici Full surumde"),
                        message: t("Diger uygulamalari silme ve dosya sistemi erisimi App Store korumali ortaminda kisitlandigi icin bu ozellik App Store surumunde kapalidir."),
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

private struct FullUninstallerView: View {
    @StateObject private var viewModel = UninstallerViewModel()
    @State private var showConfirmation = false

    var primaryTeal: Color
    var copper: Color

    private func t(_ base: String) -> String { L10n.tr(base) }

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(
                        title: t("Uygulama Kaldirici"),
                        subtitle: t("Yukleli uygulamalari ve iliskili dosyalarini birlikte kaldirir.")
                    )

                    if let status = viewModel.statusMessage {
                        Text(status)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    if viewModel.isLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(t("Uygulamalar taraniyor..."))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                    } else if viewModel.apps.isEmpty {
                        Text(t("Yukleli uygulama bulunamadi."))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(viewModel.apps) { app in
                                    appRow(app)
                                }
                            }
                        }
                        .frame(minHeight: 320)
                    }
                }
            }
            .frame(minWidth: 320)

            GlassCard {
                if let app = viewModel.selectedApp {
                    detailView(for: app)
                } else {
                    VStack {
                        Spacer()
                        Text(t("Detaylari gormek icin bir uygulama secin."))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 320)
                }
            }
            .frame(minWidth: 320)
        }
        .onAppear { viewModel.load() }
    }

    private func appRow(_ app: InstalledApp) -> some View {
        let isSelected = viewModel.selectedAppID == app.id

        return Button {
            viewModel.select(app)
        } label: {
            HStack(spacing: 12) {
                appIcon(for: app)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(appInkColor)
                        .lineLimit(1)
                    Text(app.bundleID)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(app.totalBytes.formattedBytes)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(
                isSelected ? primaryTeal.opacity(0.16) : Color.white.opacity(0.52),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private func appIcon(for app: InstalledApp) -> some View {
        Group {
            if let path = app.iconPath, let image = NSImage(contentsOfFile: path) {
                Image(nsImage: image)
                    .resizable()
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .foregroundStyle(copper)
            }
        }
        .aspectRatio(contentMode: .fit)
    }

    private func detailView(for app: InstalledApp) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                appIcon(for: app)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(appInkColor)
                    Text("\(app.bundleID) · \(app.version)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            CompactMetricRow(title: t("Uygulama boyutu"), value: app.appBytes.formattedBytes)

            if app.leftovers.isEmpty {
                Text(t("Iliskili dosya bulunamadi."))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                Text(t("Iliskili dosyalar"))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(appInkColor)

                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(app.leftovers) { leftover in
                            leftoverRow(leftover)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }

            Spacer(minLength: 0)

            AppActionButton(
                title: t("Cope Tasi"),
                systemImage: "trash.fill",
                style: .destructive,
                teal: primaryTeal,
                copper: copper,
                isDisabled: viewModel.isUninstalling
            ) {
                showConfirmation = true
            }
        }
        .padding(4)
        .alert(
            t("Uygulamayi kaldir"),
            isPresented: $showConfirmation
        ) {
            Button(t("Vazgec"), role: .cancel) {}
            Button(t("Cope Tasi"), role: .destructive) {
                viewModel.uninstallSelected()
            }
        } message: {
            Text(L10n.format("%@ ve secili dosyalari Cop'e tasinacak.", arguments: [app.name]))
        }
    }

    private func leftoverRow(_ leftover: InstalledAppLeftover) -> some View {
        let isOn = Binding<Bool>(
            get: { viewModel.selectedLeftoverIDs.contains(leftover.id) },
            set: { newValue in
                if newValue {
                    viewModel.selectedLeftoverIDs.insert(leftover.id)
                } else {
                    viewModel.selectedLeftoverIDs.remove(leftover.id)
                }
            }
        )

        return HStack {
            Toggle(isOn: isOn) {
                Text(leftover.url.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .toggleStyle(.checkbox)

            Spacer()

            Text(leftover.bytes.formattedBytes)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#endif

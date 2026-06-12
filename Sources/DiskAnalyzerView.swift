import AppKit
import SwiftUI

struct DiskAnalyzerView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var pathStack: [URL] = [FileManager.default.homeDirectoryForCurrentUser]
    @State private var entries: [DiskUsageEntry] = []
    @State private var isLoading = false

    private var primaryTeal: Color { viewModel.themeAccent.primary }
    private var copper: Color { viewModel.themeAccent.accent }

    private func t(_ base: String) -> String { L10n.tr(base) }

    private var currentFolder: URL { pathStack[pathStack.count - 1] }
    private var totalBytes: Int64 { entries.reduce(0) { $0 + $1.bytes } }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(
                        title: t("Klasor Kullanim Dagilimi"),
                        subtitle: t("Gercek tahsis edilmis (allocated) boyutlara gore buyukten kucuge siralanir.")
                    )

                    breadcrumb

                    if isLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(t("Hesaplaniyor..."))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                    } else if entries.isEmpty {
                        Text(t("Bu klasorde olculebilir icerik bulunamadi."))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(entries) { entry in
                                entryRow(entry)
                            }
                        }
                    }
                }
            }
        }
        .task(id: currentFolder) {
            await load()
        }
    }

    private var breadcrumb: some View {
        HStack(spacing: 8) {
            ForEach(Array(pathStack.enumerated()), id: \.offset) { index, url in
                Button {
                    pathStack = Array(pathStack.prefix(index + 1))
                } label: {
                    Text(displayName(for: url))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .buttonStyle(.plain)
                .foregroundStyle(index == pathStack.count - 1 ? appInkColor : primaryTeal)

                if index < pathStack.count - 1 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if pathStack.count > 1 {
                AppActionButton(
                    title: t("Geri"),
                    systemImage: "chevron.left",
                    style: .secondary,
                    teal: primaryTeal,
                    copper: copper
                ) {
                    pathStack.removeLast()
                }
            }
        }
    }

    private func entryRow(_ entry: DiskUsageEntry) -> some View {
        let fraction = totalBytes > 0 ? Double(entry.bytes) / Double(totalBytes) : 0

        return Button {
            pathStack.append(entry.url)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(copper)
                    Text(entry.name)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(appInkColor)
                        .lineLimit(1)
                    Spacer()
                    Text(entry.bytes.formattedBytes)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([entry.url])
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                UsageBar(fraction: fraction, tint: primaryTeal)
            }
        }
        .buttonStyle(.plain)
        .padding(12)
        .background(Color.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func displayName(for url: URL) -> String {
        url.path == FileManager.default.homeDirectoryForCurrentUser.path ? t("Ana Dizin") : url.lastPathComponent
    }

    private func load() async {
        isLoading = true
        let folder = currentFolder
        let result = await Task.detached(priority: .userInitiated) {
            folder.path == FileManager.default.homeDirectoryForCurrentUser.path
                ? DiskUsageAnalyzer.topLevelBreakdown(home: folder)
                : DiskUsageAnalyzer.breakdown(of: folder)
        }.value
        entries = result
        isLoading = false
    }
}

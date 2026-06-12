import SwiftUI

@MainActor
final class SystemMonitorViewModel: ObservableObject {
    @Published private(set) var snapshot: SystemSnapshot = .empty

    private let service = SystemMonitorService()
    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        snapshot = service.sample()
    }
}

struct SystemMonitorView: View {
    @ObservedObject var viewModel: AppViewModel
    @StateObject private var monitor = SystemMonitorViewModel()

    private var primaryTeal: Color { viewModel.themeAccent.primary }
    private var copper: Color { viewModel.themeAccent.accent }

    private func t(_ base: String) -> String { L10n.tr(base) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], spacing: 14) {
                gaugeCard(
                    title: t("Islemci (CPU)"),
                    valueText: percentText(monitor.snapshot.cpuUsage),
                    fraction: monitor.snapshot.cpuUsage,
                    tint: primaryTeal,
                    caption: t("Anlik toplam CPU kullanimi")
                )
                gaugeCard(
                    title: t("Bellek (RAM)"),
                    valueText: "\(monitor.snapshot.memoryUsedBytes.formattedBytes) / \(monitor.snapshot.memoryTotalBytes.formattedBytes)",
                    fraction: monitor.snapshot.memoryTotalBytes > 0 ? Double(monitor.snapshot.memoryUsedBytes) / Double(monitor.snapshot.memoryTotalBytes) : 0,
                    tint: copper,
                    caption: t("Kullanilan fiziksel bellek")
                )
                gaugeCard(
                    title: t("Disk"),
                    valueText: "\(monitor.snapshot.diskUsedBytes.formattedBytes) / \(monitor.snapshot.diskTotalBytes.formattedBytes)",
                    fraction: monitor.snapshot.diskTotalBytes > 0 ? Double(monitor.snapshot.diskUsedBytes) / Double(monitor.snapshot.diskTotalBytes) : 0,
                    tint: Color(red: 0.49, green: 0.34, blue: 0.66),
                    caption: t("Ana disk kullanim orani")
                )
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(title: t("Ag Trafigi"), subtitle: t("Tum aktif arayuzler uzerinden toplam veri hizi."))
                    HStack(spacing: 14) {
                        networkTile(title: t("Indirme"), value: monitor.snapshot.networkDownBytesPerSec.formattedBytesPerSecond, systemImage: "arrow.down.circle.fill", tint: primaryTeal)
                        networkTile(title: t("Yukleme"), value: monitor.snapshot.networkUpBytesPerSec.formattedBytesPerSecond, systemImage: "arrow.up.circle.fill", tint: copper)
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(title: t("Sicaklik ve Fan"), subtitle: t("Apple SMC sensor verileri (sadece Full surum)."))

                    if BuildFlavor.isFullVersion {
                        if monitor.snapshot.sensors.isEmpty {
                            Text(t("Bu Mac icin sensor verisi alinamadi veya bu donanim desteklenmiyor."))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                                ForEach(monitor.snapshot.sensors) { sensor in
                                    CompactMetricRow(title: sensor.label, value: "\(String(format: "%.1f", sensor.value)) \(sensor.unit)")
                                }
                            }
                        }
                    } else {
                        FullVersionLockNotice(
                            title: t("Sicaklik/Fan izleme Full surumde"),
                            message: t("GPU sicakligi ve fan hizi okumalari donanima dogrudan eristigi icin App Store surumunde kapalidir."),
                            teal: primaryTeal,
                            copper: copper
                        )
                    }
                }
            }
        }
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    private func percentText(_ fraction: Double) -> String {
        "%\(Int((fraction * 100).rounded()))"
    }

    private func gaugeCard(title: String, valueText: String, fraction: Double, tint: Color, caption: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text(valueText)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(appInkColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                UsageBar(fraction: fraction, tint: tint)
                Text(caption)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func networkTile(title: String, value: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(appInkColor)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

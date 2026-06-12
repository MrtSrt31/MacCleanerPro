import SwiftUI

/// Shared, theme-aware building blocks used by the newer feature sections
/// (Live Monitor, Disk Analyzer, Uninstaller, Maintenance) so they match the
/// look of the dashboard without duplicating ContentView's private helpers.
let appInkColor = Color(red: 0.10, green: 0.20, blue: 0.23)

struct SectionHeading: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(appInkColor)
            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

struct CompactMetricRow: View {
    var title: String
    var value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .multilineTextAlignment(.trailing)
        }
        .padding(12)
        .background(Color.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct AppBadge: View {
    var title: String
    var tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

enum AppButtonStyle {
    case primary
    case secondary
    case ghost
    case destructive

    func foreground(teal: Color, copper: Color) -> Color {
        switch self {
        case .primary:    return .white
        case .secondary:  return appInkColor
        case .ghost:      return teal
        case .destructive: return .white
        }
    }

    func background(teal: Color, copper: Color) -> LinearGradient {
        switch self {
        case .primary:
            return LinearGradient(colors: [teal, copper], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .secondary:
            return LinearGradient(colors: [Color.white.opacity(0.72), Color.white.opacity(0.58)], startPoint: .top, endPoint: .bottom)
        case .ghost:
            return LinearGradient(colors: [Color.white.opacity(0.36), Color.white.opacity(0.24)], startPoint: .top, endPoint: .bottom)
        case .destructive:
            return LinearGradient(colors: [Color(red: 0.76, green: 0.25, blue: 0.30), Color(red: 0.86, green: 0.42, blue: 0.32)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    func border(teal: Color) -> Color {
        switch self {
        case .primary:    return .clear
        case .secondary:  return Color.white.opacity(0.28)
        case .ghost:      return teal.opacity(0.22)
        case .destructive: return .clear
        }
    }
}

struct AppActionButton: View {
    var title: String
    var systemImage: String
    var style: AppButtonStyle
    var teal: Color
    var copper: Color
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
        .foregroundStyle(style.foreground(teal: teal, copper: copper))
        .background(style.background(teal: teal, copper: copper), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(style.border(teal: teal), lineWidth: 1)
        )
        .opacity(isDisabled ? 0.45 : 1)
        .disabled(isDisabled)
    }
}

/// A horizontal bar used by the disk analyzer / memory & disk gauges.
struct UsageBar: View {
    var fraction: Double
    var tint: Color
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(Color.white.opacity(0.4))
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(tint)
                    .frame(width: max(0, min(1, fraction)) * proxy.size.width)
            }
        }
        .frame(height: height)
    }
}

/// Shown for App Store-only sections when a feature is gated to the Full build.
struct FullVersionLockNotice: View {
    var title: String
    var message: String
    var teal: Color
    var copper: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(copper)
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(appInkColor)
            }
            Text(message)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Link(destination: BuildFlavor.fullVersionInfoURL) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right.square.fill")
                    Text(L10n.tr("Full surumu GitHub'dan edinin"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(LinearGradient(colors: [teal, copper], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(16)
        .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(copper.opacity(0.3), lineWidth: 1)
        )
    }
}

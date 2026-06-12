import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var step = 0
    @State private var selectedProfile: SetupProfile = .general
    @State private var selectedTheme: ThemeAccent = .tealCopper

    private let totalSteps = 4
    private var primaryTeal: Color { selectedTheme.primary }
    private var copper: Color { selectedTheme.accent }
    private let ink = Color(red: 0.10, green: 0.20, blue: 0.23)

    private func t(_ key: String) -> String { L10n.tr(key) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: selectedTheme.backgroundGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.35), value: selectedTheme.rawValue)

            VStack(spacing: 0) {
                stepContent
                    .id(step)
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.22), value: step)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                footer
            }
        }
        .frame(width: 700, height: 540)
        .onAppear {
            selectedTheme = viewModel.themeAccent
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: welcomeStep
        case 1: profileStep
        case 2: themeStep
        case 3: readyStep
        default: welcomeStep
        }
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 28) {
            AppLogo(size: 96)
                .shadow(color: primaryTeal.opacity(0.35), radius: 16, y: 6)

            VStack(spacing: 10) {
                Text("MacCleanerPro")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink)
                Text(t("Mac'inizi gercek dosya sistemi taramasi ile temizler."))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 24) {
                featurePill(icon: "magnifyingglass", text: t("Gercek Tarama"))
                featurePill(icon: "trash.fill", text: t("Guvenli Temizlik"))
                featurePill(icon: "chart.bar.fill", text: t("Anlik Raporlar"))
                featurePill(icon: "lock.shield.fill", text: t("Guvenli Mod"))
            }

            Text(t("Kurulum birkaç adımda tamamlanır. Istediginizde degistirebilirsiniz."))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 60)
    }

    // MARK: - Step 1: Profile

    private var profileStep: some View {
        VStack(spacing: 24) {
            stepHeader(
                title: t("Kullanim Profilinizi Secin"),
                subtitle: t("Profil, varsayilan tarama ve bakim ayarlarini otomatik yapilandirir.")
            )

            HStack(spacing: 14) {
                ForEach(SetupProfile.allCases) { profile in
                    profileCard(profile)
                }
            }
            .padding(.horizontal, 40)

            profileDetail
        }
        .padding(.top, 12)
    }

    private func profileCard(_ profile: SetupProfile) -> some View {
        let isSelected = selectedProfile == profile
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                selectedProfile = profile
            }
        } label: {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected
                            ? LinearGradient(colors: [primaryTeal, copper], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color.white.opacity(0.7), Color.white.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: 56, height: 56)
                    Image(systemName: profile.systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : primaryTeal)
                }
                VStack(spacing: 4) {
                    Text(profile.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(ink)
                    Text(profile.subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSelected ? primaryTeal.opacity(0.10) : Color.white.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? primaryTeal.opacity(0.45) : Color.white.opacity(0.4), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var profileDetail: some View {
        HStack(spacing: 20) {
            profileDetailPill(icon: "shield.fill", label: t("Guvenli Mod"), value: selectedProfile.safeMode ? t("Acik") : t("Kapali"))
            profileDetailPill(icon: "magnifyingglass.circle.fill", label: t("Derin Tarama"), value: selectedProfile.deepScan ? t("Acik") : t("Kapali"))
            profileDetailPill(icon: "clock.arrow.circlepath", label: t("Bakim Ritmi"), value: selectedProfile.schedule.title)
        }
        .padding(.horizontal, 40)
    }

    private func profileDetailPill(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(primaryTeal)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Step 2: Theme

    private var themeStep: some View {
        VStack(spacing: 24) {
            stepHeader(
                title: t("Renk Temasinizi Secin"),
                subtitle: t("Arayuz rengi istediginiz zaman Otomasyon bolumunden degistirilebilir.")
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 14)], spacing: 14) {
                ForEach(ThemeAccent.allCases) { accent in
                    themeCard(accent)
                }
            }
            .padding(.horizontal, 50)
        }
        .padding(.top, 12)
    }

    private func themeCard(_ accent: ThemeAccent) -> some View {
        let isSelected = selectedTheme == accent
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                selectedTheme = accent
            }
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [accent.primary, accent.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(height: 52)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                Text(accent.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? ink : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? accent.primary.opacity(0.10) : Color.white.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? accent.primary.opacity(0.50) : Color.white.opacity(0.35), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3: Ready

    private var readyStep: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [primaryTeal.opacity(0.15), copper.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [primaryTeal, copper], startPoint: .topLeading, endPoint: .bottomTrailing))
            }

            VStack(spacing: 10) {
                Text(t("Hazirsiniz!"))
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink)
                Text(t("Kurulum tamamlandi. Ilk tarama simdi baslatilabilir."))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                readySummaryRow(icon: "person.fill", label: t("Profil"), value: selectedProfile.title)
                readySummaryRow(icon: "paintpalette.fill", label: t("Tema"), value: selectedTheme.title)
                readySummaryRow(icon: "shield.fill", label: t("Guvenli Mod"), value: selectedProfile.safeMode ? t("Acik") : t("Kapali"))
                readySummaryRow(icon: "clock.arrow.circlepath", label: t("Bakim Ritmi"), value: selectedProfile.schedule.title)
            }
            .padding(.horizontal, 120)
        }
        .padding(.horizontal, 60)
    }

    private func readySummaryRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(primaryTeal)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.3)

            HStack {
                if step > 0 {
                    Button(t("Geri")) {
                        withAnimation(.easeOut(duration: 0.18)) { step -= 1 }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                } else {
                    Button(t("Atla")) {
                        viewModel.completeOnboarding(profile: .general, theme: selectedTheme)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                }

                Spacer()

                stepDots

                Spacer()

                if step < totalSteps - 1 {
                    Button(t("Devam")) {
                        withAnimation(.easeOut(duration: 0.18)) { step += 1 }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(colors: [primaryTeal, copper], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .foregroundStyle(.white)
                } else {
                    Button(t("Taramaya Basla")) {
                        viewModel.completeOnboarding(profile: selectedProfile, theme: selectedTheme)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(colors: [primaryTeal, copper], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
        }
        .background(.ultraThinMaterial)
    }

    private var stepDots: some View {
        HStack(spacing: 7) {
            ForEach(0 ..< totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i == step
                        ? LinearGradient(colors: [primaryTeal, copper], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.secondary.opacity(0.25), Color.secondary.opacity(0.25)], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: i == step ? 22 : 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: step)
            }
        }
    }

    // MARK: - Shared helpers

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(ink)
            Text(subtitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }

    private func featurePill(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(primaryTeal)
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(width: 100, height: 72)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
    }
}

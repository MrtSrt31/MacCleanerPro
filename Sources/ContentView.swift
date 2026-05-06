import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject private var localization = LocalizationController.shared

    @State private var showCleanupConfirmation = false

    private let sidebarWidth: CGFloat = 290
    private var primaryTeal: Color { viewModel.themeAccent.primary }
    private var copper: Color { viewModel.themeAccent.accent }
    private let ink = Color(red: 0.10, green: 0.20, blue: 0.23)

    private func t(_ base: String) -> String {
        L10n.tr(base)
    }

    private func f(_ base: String, _ args: CVarArg...) -> String {
        L10n.format(base, arguments: args)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(
                colors: viewModel.themeAccent.backgroundGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: viewModel.themeAccent.rawValue)

            HStack(spacing: 0) {
                sidebar
                Divider().overlay(Color.white.opacity(0.35))
                mainArea
            }
            .padding(18)

            if let toastMessage = viewModel.toastMessage {
                toast(message: toastMessage)
                    .padding(.trailing, 28)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(minWidth: 1220, minHeight: 840)
        .task {
            viewModel.performInitialScanIfNeeded()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.toastMessage)
        .sheet(isPresented: $viewModel.showOnboarding) {
            OnboardingView(viewModel: viewModel)
        }
        .alert(
            t("Temizligi Onayla"),
            isPresented: $showCleanupConfirmation
        ) {
            Button(role: .destructive) {
                viewModel.runCleanup()
            } label: {
                Text(t("Cop Kutusuna Tasi"))
            }
            Button(t("Iptal"), role: .cancel) {}
        } message: {
            Text(f(
                "%@ kategori, %@ alan Cop Kutusu'na tasınacak. Docker prune seciliyse bu islem doğrudan calisacak.",
                "\(viewModel.selectedCount)",
                viewModel.selectedBytes.formattedBytes
            ))
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(LinearGradient(colors: [primaryTeal, copper], startPoint: .topLeading, endPoint: .bottomTrailing))
                            Text("MC")
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 46, height: 46)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("MacCleanerPro")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(ink)
                            Text(t("Native macOS Cleanup"))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                            Text("v\(viewModel.appVersionString)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.secondary.opacity(0.6))
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(t("Saglik Skoru"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                        HStack(alignment: .lastTextBaseline, spacing: 10) {
                            Text("\(viewModel.healthScore)")
                                .font(.system(size: 42, weight: .heavy, design: .rounded))
                                .foregroundStyle(ink)
                            Text(viewModel.riskLabel)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.white.opacity(0.62), in: Capsule())
                        }
                    }

                    VStack(spacing: 10) {
                        miniSidebarMetric(title: t("Secili geri kazanım"), value: viewModel.selectedBytes.formattedBytes)
                        miniSidebarMetric(title: t("Toplam aday alan"), value: viewModel.reclaimableBytes.formattedBytes)
                        miniSidebarMetric(title: t("Bir sonraki bakim"), value: viewModel.nextMaintenanceLabel)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(AppSection.allCases) { section in
                    Button {
                        viewModel.selectedSection = section
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: section.systemImage)
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(section.title)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                Text(section.subtitle)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .lineLimit(2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(viewModel.selectedSection == section ? LinearGradient(colors: [primaryTeal.opacity(0.18), copper.opacity(0.13)], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [Color.white.opacity(0.42), Color.white.opacity(0.24)], startPoint: .top, endPoint: .bottom))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(viewModel.selectedSection == section ? primaryTeal.opacity(0.28) : Color.white.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)

            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(t("Canli Durum"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    HStack(spacing: 8) {
                        PulsingDot(
                            active: viewModel.isScanning || viewModel.isCleaning,
                            color: viewModel.isScanning || viewModel.isCleaning ? primaryTeal : .secondary
                        )
                        Text(viewModel.statusBadgeTitle)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(viewModel.isScanning || viewModel.isCleaning ? primaryTeal : .secondary)
                    }
                    Text(viewModel.stageTitle)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text(viewModel.stageDetail)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(width: sidebarWidth)
    }

    private var mainArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                Group {
                    switch viewModel.selectedSection {
                    case .dashboard:
                        dashboardSection
                    case .plan:
                        planSection
                    case .automation:
                        automationSection
                    case .reports:
                        reportsSection
                    }
                }
                .id(viewModel.selectedSection)
                .transition(.opacity)
                .animation(.easeOut(duration: 0.18), value: viewModel.selectedSection)
            }
            .padding(24)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.selectedSection.title)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink)
                Text(viewModel.selectedSection.subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                statusBadge(viewModel.statusBadgeTitle)
                actionButton(
                    title: viewModel.isScanning ? t("Taraniyor") : t("Akilli Tarama"),
                    systemImage: "magnifyingglass",
                    style: .primary,
                    isDisabled: viewModel.isScanning || viewModel.isCleaning,
                    shortcut: KeyboardShortcut("r", modifiers: .command),
                    action: { viewModel.startScan() }
                )
                actionButton(
                    title: viewModel.isCleaning ? t("Temizleniyor") : t("Secilenleri Temizle"),
                    systemImage: "trash.fill",
                    style: .secondary,
                    isDisabled: viewModel.isScanning || viewModel.isCleaning || viewModel.selectedCount == 0,
                    shortcut: KeyboardShortcut(.delete, modifiers: .command),
                    action: { showCleanupConfirmation = true }
                )
            }
        }
    }

    private var dashboardSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            GlassCard {
                HStack(alignment: .top, spacing: 22) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(t("Gercek sistem taramasi ve secilebilir temizlik isleri"))
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(ink)
                        Text(t("Bu masaustu uygulamasi gercek klasorleri okur, secilen dosyalari Cop Kutusu'na tasir ve docker sistem temizligini komutla calistirabilir."))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            dashboardToggle(title: t("Guvenli mod"), isOn: Binding(get: { viewModel.safeMode }, set: { viewModel.setSafeMode($0) }))
                            dashboardToggle(title: t("Derin tarama"), isOn: Binding(get: { viewModel.deepScan }, set: { viewModel.setDeepScan($0) }))
                            dashboardToggle(title: t("Snapshot"), isOn: Binding(get: { viewModel.snapshotBeforeCleanup }, set: { viewModel.setSnapshotPreference($0) }))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(viewModel.stageTitle)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                Spacer()
                                if viewModel.isScanning {
                                    Button(t("Iptal Et")) { viewModel.cancelScan() }
                                        .buttonStyle(.borderless)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(Int((viewModel.scanProgress * 100).rounded()))%")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }

                            ProgressView(value: viewModel.scanProgress)
                                .tint(primaryTeal)

                            Text(viewModel.stageDetail)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 0)

                    VStack(spacing: 12) {
                        heroMetricCard(title: t("Secili geri kazanım"), value: viewModel.selectedBytes.formattedBytes, caption: t("Aktif plan"))
                        heroMetricCard(title: t("Mevcut bos alan"), value: viewModel.diskSummary.free.formattedBytes, caption: t("Disk anlik"))
                        heroMetricCard(title: t("Plan sonrasi"), value: viewModel.freeSpaceAfterCleanup.formattedBytes, caption: t("Hedef bos alan"))
                    }
                    .frame(width: 240)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 14)], spacing: 14) {
                metricCard(title: t("Toplam aday alan"), value: viewModel.reclaimableBytes.formattedBytes, subtitle: t("Gercek tarama sonucu"))
                metricCard(title: t("Secili kategori"), value: "\(viewModel.selectedCount)", subtitle: t("Temizlik planindaki moduller"))
                metricCard(title: t("Saglik skoru"), value: "\(viewModel.healthScore)", subtitle: t("Bos alan ve risk dengesi"))
                metricCard(title: t("Aylik projeksiyon"), value: viewModel.monthlyProjectedGain.formattedBytes, subtitle: viewModel.schedule.detail)
            }

            HStack(alignment: .top, spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        sectionHeading(title: t("Temizlik Kategorileri"), subtitle: t("Secim, reveal ve dogrudan temizlik butonlari ile gercek kaynaklar."))
                        ForEach(viewModel.orderedResults) { result in
                            resultCard(result)
                        }
                    }
                }

                VStack(spacing: 16) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeading(title: t("Canli Aktivite"), subtitle: t("Tarama, secim ve temizlik olaylari yerel akista tutulur."))
                            if viewModel.activities.isEmpty {
                                Text(t("Henuz aktivite yok."))
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 60)
                            } else {
                                ForEach(viewModel.activities) { item in
                                    HStack(alignment: .top, spacing: 12) {
                                        Circle()
                                            .fill(item.style.tint)
                                            .frame(width: 10, height: 10)
                                            .padding(.top, 5)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.message)
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            Text(item.date.shortTimestamp)
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer(minLength: 0)
                                    }
                                }
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeading(title: t("Disk Ozetleri"), subtitle: t("Gercek dosya sistemi istatistikleri."))
                            compactMetric(title: t("Toplam kapasite"), value: viewModel.diskSummary.total.formattedBytes)
                            compactMetric(title: t("Kullanilan"), value: viewModel.diskSummary.used.formattedBytes)
                            compactMetric(title: t("Bos alan"), value: viewModel.diskSummary.free.formattedBytes)
                            compactMetric(title: t("Son tarama"), value: viewModel.lastScanLabel)
                        }
                    }
                }
                .frame(width: 310)
            }
        }
    }

    private var planSection: some View {
        HStack(alignment: .top, spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeading(title: t("Secili Temizlik Plani"), subtitle: t("Gercek olarak secili kategoriler ve beklenen alan geri kazanimi."))

                    if viewModel.selectedResults.isEmpty {
                        emptyState(t("Henuz secili kategori yok. Kontrol Merkezi'nden secim yapabilirsiniz."))
                    } else {
                        ForEach(viewModel.selectedResults) { result in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: result.category.systemImage)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(primaryTeal)
                                    .frame(width: 26)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.category.title)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                    Text(f("%@ · %@ oge · %@", result.bytes.formattedBytes, "\(result.itemCount)", result.safety.title))
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button(t("Finder")) {
                                    viewModel.reveal(result: result)
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(primaryTeal)
                                .disabled(result.urls.isEmpty)
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                }
            }

            VStack(spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeading(title: t("Once / Sonra"), subtitle: t("Secili planin bos alani nasil etkileyecegini gosterir."))
                        beforeAfterRow(title: t("Bugunku bos alan"), value: viewModel.diskSummary.free, total: max(viewModel.diskSummary.total, 1), tint: .blue)
                        beforeAfterRow(title: t("Plan sonrasi bos alan"), value: viewModel.freeSpaceAfterCleanup, total: max(viewModel.diskSummary.total, 1), tint: primaryTeal)
                        beforeAfterRow(title: t("Secili plan toplamı"), value: viewModel.selectedBytes, total: max(viewModel.diskSummary.total, 1), tint: copper)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeading(title: t("Geri Donus Katmani"), subtitle: t("Temizlik oncesi audit manifesti ve son cikan dosyalar."))
                        compactMetric(title: t("Snapshot tercihi"), value: viewModel.snapshotBeforeCleanup ? t("Acik") : t("Kapali"))
                        compactMetric(title: t("Son temizlik"), value: viewModel.lastCleanupDate?.shortTimestamp ?? t("Henuz yapilmadi"))
                        compactMetric(title: t("Manifest dosyasi"), value: viewModel.snapshotURL?.lastPathComponent ?? t("Henuz uretilmedi"))

                        actionButton(
                            title: t("Manifesti Ac"),
                            systemImage: "doc.text",
                            style: .secondary,
                            isDisabled: viewModel.snapshotURL == nil,
                            action: { viewModel.openSnapshotManifest() }
                        )
                    }
                }
            }
            .frame(width: 360)
        }
    }

    private var automationSection: some View {
        HStack(alignment: .top, spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    sectionHeading(title: t("Bakim Ayarlari"), subtitle: t("Yerel tercihler gercek uygulama durumunda saklanir ve rapor hesaplarina yansir."))

                    VStack(alignment: .leading, spacing: 10) {
                        Text(t("Arayuz Dili"))
                            .font(.system(size: 13, weight: .bold, design: .rounded))

                        Picker(
                            t("Arayuz Dili"),
                            selection: Binding(
                                get: { localization.selection },
                                set: { newSelection in
                                    localization.updateSelection(newSelection)
                                    viewModel.didChangeLanguage()
                                }
                            )
                        ) {
                            ForEach(AppLanguageChoice.allCases) { choice in
                                Text(choice.title).tag(choice)
                            }
                        }
                        .pickerStyle(.menu)

                        HStack(spacing: 10) {
                            compactMetric(title: t("Dil modu"), value: localization.selection.title)
                            compactMetric(title: t("Etkin dil"), value: localization.effectiveLanguage.rawValue)
                        }

                        Text(t("Desteklenmeyen cihaz dili icin otomatik İngilizce."))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(t("Renk Temasi"))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        HStack(spacing: 10) {
                            ForEach(ThemeAccent.allCases) { accent in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        viewModel.setThemeAccent(accent)
                                    }
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(LinearGradient(
                                                colors: [accent.primary, accent.accent],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ))
                                            .frame(width: 34, height: 34)
                                        if viewModel.themeAccent == accent {
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2.5)
                                                .frame(width: 34, height: 34)
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .heavy))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .help(accent.title)
                            }
                        }
                        Text(t("Secilen tema: ") + viewModel.themeAccent.title)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(t("Bakim Ritmi"))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Picker(t("Bakim Ritmi"), selection: Binding(get: { viewModel.schedule }, set: { viewModel.setSchedule($0) })) {
                            ForEach(MaintenanceSchedule.allCases) { schedule in
                                Text(schedule.title).tag(schedule)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(t("Disk Doluluk Esigi"))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                            Spacer()
                            Text("%\(Int(viewModel.threshold.rounded()))")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        Slider(
                            value: $viewModel.threshold,
                            in: 55 ... 90,
                            step: 1,
                            onEditingChanged: { editing in
                                if !editing {
                                    viewModel.commitThresholdChange()
                                }
                            }
                        )
                        .tint(primaryTeal)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        settingRow(title: t("Guvenli mod"), subtitle: t("Inceleme ve manuel kategoriler otomatik secilmez."), isOn: Binding(get: { viewModel.safeMode }, set: { viewModel.setSafeMode($0) }))
                        settingRow(title: t("Derin tarama"), subtitle: t("Container cache ve daha agresif download esikleri taranir."), isOn: Binding(get: { viewModel.deepScan }, set: { viewModel.setDeepScan($0) }))
                        settingRow(title: t("Snapshot manifesti"), subtitle: t("Temizlik oncesi dosya listesi JSON olarak kaydedilir."), isOn: Binding(get: { viewModel.snapshotBeforeCleanup }, set: { viewModel.setSnapshotPreference($0) }))
                        settingRow(
                            title: t("Arka Plan Bakim"),
                            subtitle: t("LaunchAgent ile secili ritimde arka planda uygulama calisir."),
                            isOn: Binding(
                                get: { viewModel.launchAgentInstalled },
                                set: { _ in viewModel.toggleLaunchAgent() }
                            )
                        )
                    }
                }
            }

            VStack(spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeading(title: t("Otomasyon Ongorusu"), subtitle: t("Gercek secili plan ve tercihlerinize gore projeksiyon uretir."))
                        compactMetric(title: t("Aylik potansiyel"), value: viewModel.monthlyProjectedGain.formattedBytes)
                        compactMetric(title: t("Bir sonraki bakim"), value: viewModel.nextMaintenanceLabel)
                        compactMetric(title: t("Guvenlik profili"), value: viewModel.riskLabel)
                        compactMetric(title: t("Secili kategori"), value: "\(viewModel.selectedCount)")
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeading(title: t("Politika Notu"), subtitle: t("LaunchAgent eklemeden once bu uygulama tercihleri lokal olarak tutar."))
                        Text(t("Uygulama bu surumde arka planda otomatik calisacak LaunchAgent yazmaz; ancak secilen ritim, esik ve koruma tercihleri rapor ve temizlik kararlarini etkiler."))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        actionButton(
                            title: t("Kurulum Sihirbazini Goster"),
                            systemImage: "wand.and.stars",
                            style: .ghost,
                            isDisabled: false,
                            action: { viewModel.resetOnboarding() }
                        )
                    }
                }
            }
            .frame(width: 360)
        }
    }

    private var reportsSection: some View {
        HStack(alignment: .top, spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeading(title: t("Alti Aylik Projeksiyon"), subtitle: t("Secili plan ile aylik geri kazanım egilimi gercek veriden uretilir."))
                    barChart(points: viewModel.reportBars)
                }
            }

            VStack(spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeading(title: t("Rapor Ozeti"), subtitle: t("Disa aktarilabilir metin raporu ve yerel artefaktlar."))
                        Text(viewModel.reportSummary)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        actionButton(
                            title: t("Raporu Disa Aktar"),
                            systemImage: "square.and.arrow.up.fill",
                            style: .primary,
                            isDisabled: false,
                            action: { viewModel.exportReport() }
                        )

                        actionButton(
                            title: t("Rapor Dosyasini Ac"),
                            systemImage: "doc.fill",
                            style: .secondary,
                            isDisabled: viewModel.reportURL == nil,
                            action: { viewModel.openReport() }
                        )
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeading(title: t("Artefaktlar"), subtitle: t("Son olusan report ve snapshot manifesti yolları."))
                        compactMetric(title: t("Rapor"), value: viewModel.reportURL?.lastPathComponent ?? t("Henuz uretilmedi"))
                        compactMetric(title: t("Snapshot"), value: viewModel.snapshotURL?.lastPathComponent ?? t("Henuz uretilmedi"))
                        compactMetric(title: t("Son tarama"), value: viewModel.lastScanLabel)
                    }
                }
            }
            .frame(width: 380)
        }
    }

    private func resultCard(_ result: CleanupScanResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: result.category.systemImage)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(primaryTeal)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.category.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text(result.category.subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(result.bytes.formattedBytes)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                    Text(f("%@ oge", "\(result.itemCount)"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                badge(title: result.safety.title, tint: result.safety.tint)
                if result.shellCommand != nil {
                    badge(title: t("Shell"), tint: copper)
                }
                if viewModel.selectedCategories.contains(result.category) {
                    badge(title: t("Secili"), tint: primaryTeal)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(result.notes.prefix(3).enumerated()), id: \.offset) { _, note in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(copper)
                            .padding(.top, 3)
                        Text(note)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if viewModel.safeMode && result.safety != .safe {
                Text(t("Guvenli mod acik oldugu icin bu kategori otomatik secilmez."))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(result.safety.tint)
            }

            HStack(spacing: 10) {
                actionButton(
                    title: viewModel.selectedCategories.contains(result.category) ? t("Plani Cikar") : t("Plana Ekle"),
                    systemImage: viewModel.selectedCategories.contains(result.category) ? "minus.circle.fill" : "plus.circle.fill",
                    style: .secondary,
                    isDisabled: !result.isActionable || (viewModel.safeMode && result.safety != .safe),
                    action: { viewModel.toggleSelection(for: result) }
                )

                actionButton(
                    title: t("Finder"),
                    systemImage: "folder.fill",
                    style: .ghost,
                    isDisabled: result.urls.isEmpty,
                    action: { viewModel.reveal(result: result) }
                )
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(viewModel.selectedCategories.contains(result.category) ? primaryTeal.opacity(0.30) : Color.white.opacity(0.25), lineWidth: 1)
        )
        .opacity(result.isEmpty ? 0.74 : 1)
    }

    private func miniSidebarMetric(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
        }
        .padding(10)
        .background(Color.white.opacity(0.48), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func heroMetricCard(title: String, value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(ink)
            Text(caption)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func metricCard(title: String, value: String, subtitle: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func compactMetric(title: String, value: String) -> some View {
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

    private func beforeAfterRow(title: String, value: Int64, total: Int64, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Spacer()
                Text(value.formattedBytes)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(value) / Double(max(total, 1)))
                .tint(tint)
        }
        .padding(12)
        .background(Color.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func settingRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func dashboardToggle(title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Toggle(title, isOn: isOn)
                .toggleStyle(.switch)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sectionHeading(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(ink)
            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private func badge(title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule())
    }

    private func statusBadge(_ title: String) -> some View {
        let isActive = viewModel.isScanning || viewModel.isCleaning
        return HStack(spacing: 8) {
            PulsingDot(active: isActive, color: isActive ? primaryTeal : Color.secondary.opacity(0.6))
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.62), in: Capsule())
    }

    private func actionButton(
        title: String,
        systemImage: String,
        style: ActionButtonStyle,
        isDisabled: Bool,
        shortcut: KeyboardShortcut? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: style == .primary ? nil : .infinity)
        }
        .buttonStyle(.plain)
        .foregroundStyle(style.foreground(teal: primaryTeal, copper: copper))
        .background(style.background(teal: primaryTeal, copper: copper), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(style.border(teal: primaryTeal), lineWidth: 1)
        )
        .opacity(isDisabled ? 0.45 : 1)
        .disabled(isDisabled)
        .ifLet(shortcut) { view, sc in view.keyboardShortcut(sc) }
    }

    private func barChart(points: [BarPoint]) -> some View {
        let maximum = max(points.map(\.value).max() ?? 1, 1)

        return HStack(alignment: .bottom, spacing: 14) {
            ForEach(points) { point in
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [primaryTeal, copper], startPoint: .top, endPoint: .bottom))
                        .frame(height: max(28, CGFloat(point.value / maximum) * 190))
                    Text(Int64(point.value).formattedBytes)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(point.label)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 250, alignment: .bottom)
        .padding(.top, 6)
    }

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 160)
            .background(Color.white.opacity(0.46), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func toast(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.36), lineWidth: 1)
            )
    }
}

private struct PulsingDot: View {
    var active: Bool
    var color: Color
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .scaleEffect(pulse ? 1.35 : 1.0)
            .opacity(pulse ? 0.6 : 1.0)
            .onAppear {
                if active { startPulsing() }
            }
            .onChange(of: active) { isActive in
                if isActive {
                    startPulsing()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        pulse = false
                    }
                }
            }
    }

    private func startPulsing() {
        withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}

private extension View {
    @ViewBuilder
    func ifLet<T, V: View>(_ value: T?, transform: (Self, T) -> V) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}

private enum ActionButtonStyle {
    case primary
    case secondary
    case ghost

    func foreground(teal: Color, copper: Color) -> Color {
        switch self {
        case .primary:
            return .white
        case .secondary:
            return Color(red: 0.10, green: 0.20, blue: 0.23)
        case .ghost:
            return teal
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
        }
    }

    func border(teal: Color) -> Color {
        switch self {
        case .primary:
            return .clear
        case .secondary:
            return Color.white.opacity(0.28)
        case .ghost:
            return teal.opacity(0.22)
        }
    }
}
import AppKit
import SwiftUI
import UserNotifications

@main
struct MacCleanerProApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = AppViewModel()
    @StateObject private var localization = LocalizationController.shared

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .environment(\.locale, localization.locale)
                .environment(\.layoutDirection, localization.effectiveLanguage.isRightToLeft ? .rightToLeft : .leftToRight)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("MacCleanerPro Hakkında") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        NSApplication.AboutPanelOptionKey.applicationName: "MacCleanerPro",
                        NSApplication.AboutPanelOptionKey.applicationVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                        NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
                            string: "Gerçek sistem taraması ile Mac'inizi temizler.\n\nMert Sert tarafından geliştirildi.",
                            attributes: [
                                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                            ]
                        ),
                    ])
                }
                .keyboardShortcut(",", modifiers: [])
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appearanceObservation: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ notification: Notification) {
        updateAppIcon()
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor in
                self?.updateAppIcon()
            }
        }
        // Request notification permission early so the system prompt appears at launch.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        for window in NSApp.windows {
            window.titlebarAppearsTransparent = true
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @MainActor
    private func updateAppIcon() {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        NSApplication.shared.applicationIconImage = AppIconFactory.makeIcon(dark: isDark)
    }
}

@MainActor
enum AppIconFactory {
    static func makeIcon(dark: Bool) -> NSImage {
        AppLogoAsset.image(for: dark ? .dark : .light)
    }
}

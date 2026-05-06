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
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
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

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.applicationIconImage = AppIconFactory.makeIcon()
        // Request notification permission early so the system prompt appears at launch.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

enum AppIconFactory {
    static func makeIcon() -> NSImage {
        let size = NSSize(width: 512, height: 512)
        let image = NSImage(size: size)

        image.lockFocus()
        defer { image.unlockFocus() }

        let canvas = NSRect(origin: .zero, size: size).insetBy(dx: 24, dy: 24)
        let shellPath = NSBezierPath(roundedRect: canvas, xRadius: 126, yRadius: 126)
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.08, green: 0.63, blue: 0.58, alpha: 1.0),
            NSColor(calibratedRed: 0.84, green: 0.53, blue: 0.33, alpha: 1.0),
        ])
        gradient?.draw(in: shellPath, angle: 40)

        NSColor.white.withAlphaComponent(0.18).setFill()
        NSBezierPath(ovalIn: canvas.insetBy(dx: 78, dy: 78)).fill()

        let wand = NSBezierPath()
        wand.lineWidth = 34
        wand.lineCapStyle = .round
        wand.move(to: NSPoint(x: 190, y: 170))
        wand.line(to: NSPoint(x: 340, y: 320))
        NSColor.white.withAlphaComponent(0.92).setStroke()
        wand.stroke()

        let innerWand = NSBezierPath()
        innerWand.lineWidth = 16
        innerWand.lineCapStyle = .round
        innerWand.move(to: NSPoint(x: 214, y: 152))
        innerWand.line(to: NSPoint(x: 356, y: 294))
        NSColor(calibratedRed: 0.13, green: 0.19, blue: 0.24, alpha: 0.32).setStroke()
        innerWand.stroke()

        for sparkle in [
            NSRect(x: 292, y: 322, width: 30, height: 30),
            NSRect(x: 352, y: 344, width: 24, height: 24),
            NSRect(x: 324, y: 378, width: 18, height: 18),
        ] {
            NSColor.white.withAlphaComponent(0.95).setFill()
            NSBezierPath(ovalIn: sparkle).fill()
        }

        return image
    }
}

import AppKit
import SwiftUI

/// Provides the MacCleanerPro brand mark in its dark- and light-background variants.
@MainActor
enum AppLogoAsset {
    /// Returns the logo image whose background suits the given color scheme.
    /// In dark mode the dark-background artwork is used, in light mode the
    /// white-background artwork is used, so the logo always sits naturally
    /// against the surrounding interface.
    static func image(for colorScheme: ColorScheme) -> NSImage {
        let resourceName = colorScheme == .dark ? "dark" : "white"
        return cachedImage(named: resourceName)
    }

    private static var cache: [String: NSImage] = [:]

    private static func cachedImage(named name: String) -> NSImage {
        if let cached = cache[name] {
            return cached
        }
        let image = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Resources/Logo")
            .flatMap { NSImage(contentsOf: $0) }
            ?? Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Logo")
                .flatMap { NSImage(contentsOf: $0) }
            ?? NSImage()
        cache[name] = image
        return image
    }
}

/// Renders the MacCleanerPro logo, automatically switching between the
/// dark- and white-background artwork to match the current color scheme.
struct AppLogo: View {
    var size: CGFloat = 46
    var cornerRadius: CGFloat = 12

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(nsImage: AppLogoAsset.image(for: colorScheme))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

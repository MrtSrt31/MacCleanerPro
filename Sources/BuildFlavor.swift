import Foundation

/// Distinguishes the App Store build (sandboxed-friendly, no third-party
/// distribution links, advanced/system-level tools disabled) from the
/// direct-distribution "Full" build. Controlled at build time via the
/// `FULL_VERSION` Swift compiler flag (see Versions/Full/build.sh and
/// Versions/AppStore/build.sh).
enum BuildFlavor {
    #if FULL_VERSION
    static let isFullVersion = true
    #else
    static let isFullVersion = false
    #endif

    static let fullVersionInfoURL = URL(string: "https://github.com/MrtSrt31/MacCleanerPro")!
}

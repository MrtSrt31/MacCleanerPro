import Foundation

struct InstalledAppLeftover: Identifiable, Hashable {
    var id: String { url.path }
    var url: URL
    var bytes: Int64
}

struct InstalledApp: Identifiable, Hashable {
    var id: String { bundleURL.path }
    var name: String
    var bundleID: String
    var version: String
    var bundleURL: URL
    var iconPath: String?
    var appBytes: Int64

    var leftovers: [InstalledAppLeftover] = []
    var leftoverBytes: Int64 { leftovers.reduce(0) { $0 + $1.bytes } }
    var totalBytes: Int64 { appBytes + leftoverBytes }
}

#if FULL_VERSION

enum AppUninstallerService {
    /// Lists user-installed applications from /Applications and ~/Applications,
    /// skipping Apple system apps that should never be removed via this tool.
    static func listInstalledApps() -> [InstalledApp] {
        let fileManager = FileManager.default
        var roots: [URL] = [URL(fileURLWithPath: "/Applications")]
        roots.append(fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications"))

        var apps: [InstalledApp] = []

        for root in roots {
            guard let children = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { continue }

            for child in children where child.pathExtension == "app" {
                guard let bundle = Bundle(url: child) else { continue }
                guard let bundleID = bundle.bundleIdentifier else { continue }
                // Skip Apple's own apps — these are part of macOS and shouldn't be removed here.
                if bundleID.hasPrefix("com.apple.") { continue }

                let name = (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
                    ?? (bundle.infoDictionary?["CFBundleName"] as? String)
                    ?? child.deletingPathExtension().lastPathComponent
                let version = (bundle.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "-"

                var iconPath: String?
                if let iconFile = bundle.infoDictionary?["CFBundleIconFile"] as? String {
                    iconPath = bundle.path(forResource: iconFile, ofType: nil)
                        ?? bundle.path(forResource: iconFile, ofType: "icns")
                } else if let iconName = bundle.infoDictionary?["CFBundleIconName"] as? String {
                    iconPath = bundle.path(forResource: iconName, ofType: "icns")
                }

                let appBytes = allocatedSize(of: child)

                apps.append(InstalledApp(
                    name: name,
                    bundleID: bundleID,
                    version: version,
                    bundleURL: child,
                    iconPath: iconPath,
                    appBytes: appBytes
                ))
            }
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Finds leftover support/cache/preference files associated with a bundle identifier.
    static func findLeftovers(for app: InstalledApp) -> [InstalledAppLeftover] {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library")

        let bundleID = app.bundleID
        let appNameComponents = candidateNames(for: app)

        let searchRoots: [URL] = [
            library.appendingPathComponent("Application Support"),
            library.appendingPathComponent("Caches"),
            library.appendingPathComponent("Preferences"),
            library.appendingPathComponent("Saved Application State"),
            library.appendingPathComponent("Containers"),
            library.appendingPathComponent("HTTPStorages"),
            library.appendingPathComponent("WebKit"),
            library.appendingPathComponent("Logs"),
            library.appendingPathComponent("LaunchAgents"),
            library.appendingPathComponent("Application Scripts"),
        ]

        var leftovers: [InstalledAppLeftover] = []

        for root in searchRoots {
            guard let children = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { continue }

            for child in children {
                let nameLower = child.lastPathComponent.lowercased()
                let matches = nameLower.contains(bundleID.lowercased())
                    || appNameComponents.contains { !$0.isEmpty && nameLower.contains($0) }

                guard matches else { continue }

                let bytes = allocatedSize(of: child)
                guard bytes > 0 else { continue }
                leftovers.append(InstalledAppLeftover(url: child, bytes: bytes))
            }
        }

        return leftovers.sorted { $0.bytes > $1.bytes }
    }

    /// Moves the app bundle and all selected leftovers to the Trash.
    static func uninstall(app: InstalledApp, leftovers: [InstalledAppLeftover]) throws {
        let fileManager = FileManager.default

        try trash(app.bundleURL, fileManager: fileManager)

        for leftover in leftovers {
            try? trash(leftover.url, fileManager: fileManager)
        }
    }

    private static func trash(_ url: URL, fileManager: FileManager) throws {
        var resultingURL: NSURL?
        try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
    }

    private static func candidateNames(for app: InstalledApp) -> [String] {
        var names = Set<String>()
        names.insert(app.name.lowercased())

        let bundleComponents = app.bundleID.split(separator: ".")
        if let last = bundleComponents.last {
            names.insert(String(last).lowercased())
        }

        let fileName = app.bundleURL.deletingPathExtension().lastPathComponent
        names.insert(fileName.lowercased())

        return Array(names)
    }

    private static func allocatedSize(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey,
        ]

        let rootValues = try? url.resourceValues(forKeys: keys)
        if rootValues?.isSymbolicLink == true { return 0 }

        if rootValues?.isRegularFile == true {
            return Int64(rootValues?.totalFileAllocatedSize ?? rootValues?.fileAllocatedSize ?? 0)
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: keys)
            if values?.isSymbolicLink == true { continue }
            total += Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        }
        return total
    }
}

#endif

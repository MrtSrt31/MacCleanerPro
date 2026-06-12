import Foundation

struct DiskUsageEntry: Identifiable, Hashable {
    var id: String { url.path }
    var url: URL
    var bytes: Int64

    var name: String { url.lastPathComponent }
}

/// Measures the real allocated size of each top-level (and one level deeper)
/// folder under the user's home directory, sorted largest-first — a simple,
/// dependable stand-in for a treemap/disk-usage view.
enum DiskUsageAnalyzer {
    static func topLevelBreakdown(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [DiskUsageEntry] {
        let fileManager = FileManager.default
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]

        guard let children = try? fileManager.contentsOfDirectory(
            at: home,
            includingPropertiesForKeys: Array(keys),
            options: []
        ) else { return [] }

        var entries: [DiskUsageEntry] = []

        for child in children {
            guard let values = try? child.resourceValues(forKeys: keys) else { continue }
            guard values.isSymbolicLink != true else { continue }
            // Skip dotfiles/hidden folders (e.g. ~/.Trash is its own cleanup category already).
            guard !child.lastPathComponent.hasPrefix(".") else { continue }

            let bytes = allocatedSize(of: child)
            guard bytes > 0 else { continue }
            entries.append(DiskUsageEntry(url: child, bytes: bytes))
        }

        return entries.sorted { $0.bytes > $1.bytes }
    }

    /// Breaks down the immediate children of a given folder — used for drill-down.
    static func breakdown(of folder: URL) -> [DiskUsageEntry] {
        let fileManager = FileManager.default
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]

        guard let children = try? fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: Array(keys),
            options: []
        ) else { return [] }

        var entries: [DiskUsageEntry] = []

        for child in children {
            guard let values = try? child.resourceValues(forKeys: keys) else { continue }
            guard values.isSymbolicLink != true else { continue }

            let bytes = allocatedSize(of: child)
            guard bytes > 0 else { continue }
            entries.append(DiskUsageEntry(url: child, bytes: bytes))
        }

        return entries.sorted { $0.bytes > $1.bytes }
    }

    // Recursively sums allocated size without following symbolic links.
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

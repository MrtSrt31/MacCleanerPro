import Foundation
import Darwin
#if FULL_VERSION
import IOKit
#endif

/// A point-in-time read of system resource usage. CPU/RAM/Disk/Network use
/// standard Darwin host-statistics APIs and are available in every build.
/// `sensors` (temperature/fan) is only populated in the Full build, via the
/// SMC (see `SMCService`), and is empty on App Store builds or unsupported
/// Macs.
struct SystemSnapshot {
    var cpuUsage: Double
    var memoryUsedBytes: Int64
    var memoryTotalBytes: Int64
    var diskUsedBytes: Int64
    var diskTotalBytes: Int64
    var networkDownBytesPerSec: Double
    var networkUpBytesPerSec: Double
    var sensors: [SensorReading]

    static let empty = SystemSnapshot(
        cpuUsage: 0,
        memoryUsedBytes: 0,
        memoryTotalBytes: 0,
        diskUsedBytes: 0,
        diskTotalBytes: 0,
        networkDownBytesPerSec: 0,
        networkUpBytesPerSec: 0,
        sensors: []
    )
}

struct SensorReading: Identifiable, Hashable {
    var id: String
    var label: String
    var value: Double
    var unit: String
}

/// Samples live CPU, memory, disk, and network usage using Darwin host
/// statistics. Each call to `sample()` returns instantaneous values for
/// memory/disk and rates (computed from deltas) for CPU/network.
final class SystemMonitorService {
    private var lastCPUTicks: (user: Double, system: Double, idle: Double, nice: Double)?
    private var lastNetSample: (bytesIn: UInt64, bytesOut: UInt64, date: Date)?

    #if FULL_VERSION
    private let smc = SMCService()
    #endif

    func sample() -> SystemSnapshot {
        let cpu = sampleCPU()
        let memory = sampleMemory()
        let disk = sampleDisk()
        let network = sampleNetwork()

        var sensors: [SensorReading] = []
        #if FULL_VERSION
        sensors = smc.readSensors()
        #endif

        return SystemSnapshot(
            cpuUsage: cpu,
            memoryUsedBytes: memory.used,
            memoryTotalBytes: memory.total,
            diskUsedBytes: disk.used,
            diskTotalBytes: disk.total,
            networkDownBytesPerSec: network.down,
            networkUpBytesPerSec: network.up,
            sensors: sensors
        )
    }

    // MARK: - CPU

    private func sampleCPU() -> Double {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &cpuInfo) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, reboundPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let user   = Double(cpuInfo.cpu_ticks.0)
        let system = Double(cpuInfo.cpu_ticks.1)
        let idle   = Double(cpuInfo.cpu_ticks.2)
        let nice   = Double(cpuInfo.cpu_ticks.3)

        defer { lastCPUTicks = (user, system, idle, nice) }

        guard let previous = lastCPUTicks else { return 0 }

        let userDelta   = max(0, user - previous.user)
        let systemDelta = max(0, system - previous.system)
        let idleDelta   = max(0, idle - previous.idle)
        let niceDelta   = max(0, nice - previous.nice)
        let totalDelta  = userDelta + systemDelta + idleDelta + niceDelta

        guard totalDelta > 0 else { return 0 }
        return min(1, max(0, (userDelta + systemDelta + niceDelta) / totalDelta))
    }

    // MARK: - Memory

    private func sampleMemory() -> (used: Int64, total: Int64) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPointer, &count)
            }
        }

        let total = Int64(ProcessInfo.processInfo.physicalMemory)
        guard result == KERN_SUCCESS else { return (0, total) }

        let pageSize = Int64(getpagesize())
        let used = (Int64(stats.active_count) + Int64(stats.inactive_count) + Int64(stats.wire_count) + Int64(stats.compressor_page_count)) * pageSize
        return (min(used, total), total)
    }

    // MARK: - Disk

    private func sampleDisk() -> (used: Int64, total: Int64) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: home.path) else {
            return (0, 0)
        }
        let total = (attributes[.systemSize] as? NSNumber)?.int64Value ?? 0
        let free  = (attributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        return (max(0, total - free), total)
    }

    // MARK: - Network

    private func sampleNetwork() -> (down: Double, up: Double) {
        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0

        var ifaddrPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPointer) == 0, let firstAddr = ifaddrPointer else { return (0, 0) }
        defer { freeifaddrs(ifaddrPointer) }

        var pointer: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = pointer {
            let flags = Int32(current.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0

            if isUp, !isLoopback, current.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                if let data = current.pointee.ifa_data {
                    let networkData = data.withMemoryRebound(to: if_data.self, capacity: 1) { $0.pointee }
                    bytesIn += UInt64(networkData.ifi_ibytes)
                    bytesOut += UInt64(networkData.ifi_obytes)
                }
            }
            pointer = current.pointee.ifa_next
        }

        let now = Date()
        defer { lastNetSample = (bytesIn, bytesOut, now) }

        guard let previous = lastNetSample else { return (0, 0) }
        let elapsed = now.timeIntervalSince(previous.date)
        guard elapsed > 0, bytesIn >= previous.bytesIn, bytesOut >= previous.bytesOut else { return (0, 0) }

        let down = Double(bytesIn - previous.bytesIn) / elapsed
        let up = Double(bytesOut - previous.bytesOut) / elapsed
        return (down, up)
    }
}

extension Double {
    /// Formats a bytes-per-second rate as e.g. "1.2 MB/s".
    var formattedBytesPerSecond: String {
        let bytes = Int64(self.rounded())
        return bytes.formattedBytes + "/s"
    }
}

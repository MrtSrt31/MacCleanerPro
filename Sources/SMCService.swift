#if FULL_VERSION
import Foundation
import IOKit

/// Reads temperature/fan sensors from the Apple System Management Controller
/// (AppleSMC) via IOKit. This is only compiled into the Full build — it is
/// not sandbox-friendly and is intentionally excluded from the App Store
/// build (see `BuildFlavor`).
///
/// Sensor key coverage varies a lot by Mac model/chip, especially across
/// Apple Silicon generations. This reader probes a list of known candidate
/// keys and silently skips anything that doesn't respond — callers should
/// treat an empty result as "no sensor data available on this Mac" rather
/// than an error.
final class SMCService {
    private enum Selector: UInt8 {
        case handleYPCEvent = 2
    }

    private enum FunctionCode: UInt8 {
        case getKeyInfo = 9
        case readKey = 5
    }

    private static let structSize = 80

    private var connection: io_connect_t = 0
    private var isOpen = false

    init() {
        var service: io_object_t = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }

        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        isOpen = (result == kIOReturnSuccess)
        service = 0
    }

    deinit {
        if isOpen { IOServiceClose(connection) }
    }

    /// Known candidate sensor keys across Intel and Apple Silicon Macs.
    /// Label/unit pairs describe what each key represents if present.
    private static let temperatureCandidates: [(key: String, label: String)] = [
        ("TC0P", "CPU"), ("TC0D", "CPU Die"), ("TC0H", "CPU Heatsink"),
        ("TG0P", "GPU"), ("TG0D", "GPU Die"),
        ("Tp01", "CPU 1"), ("Tp05", "CPU 2"), ("Tp09", "CPU 3"), ("Tp0D", "CPU 4"),
        ("Tp0b", "GPU 1"), ("Tp0e", "GPU 2"),
        ("Tg05", "GPU"), ("Tg0D", "GPU"),
        ("Ts0P", "Sistem"),
    ]

    private static let fanCandidates: [(key: String, label: String)] = [
        ("F0Ac", "Fan 1"), ("F1Ac", "Fan 2"),
    ]

    func readSensors() -> [SensorReading] {
        guard isOpen else { return [] }

        var readings: [SensorReading] = []

        for (key, label) in Self.temperatureCandidates {
            guard let value = readValue(forKey: key), value > 0, value < 120 else { continue }
            readings.append(SensorReading(id: key, label: label, value: value, unit: "°C"))
        }

        for (key, label) in Self.fanCandidates {
            guard let value = readValue(forKey: key), value > 0 else { continue }
            readings.append(SensorReading(id: key, label: label, value: value, unit: "RPM"))
        }

        return readings
    }

    // MARK: - Low-level SMC protocol

    /// Looks up a key's reported type/size, then performs the actual read and
    /// decodes the result based on the SMC data-type code (e.g. "flt ", "sp78", "ui8 ").
    private func readValue(forKey key: String) -> Double? {
        guard let keyCode = fourCharCode(key) else { return nil }

        var input = [UInt8](repeating: 0, count: Self.structSize)
        writeUInt32(keyCode, into: &input, at: 0)
        input[42] = FunctionCode.getKeyInfo.rawValue // data8

        guard let infoOutput = callSMC(input: input) else { return nil }

        let dataSize = readUInt32(infoOutput, at: 28)
        let dataType = readUInt32(infoOutput, at: 32)
        guard dataSize > 0, dataSize <= 32 else { return nil }

        var readInput = [UInt8](repeating: 0, count: Self.structSize)
        writeUInt32(keyCode, into: &readInput, at: 0)
        writeUInt32(dataSize, into: &readInput, at: 28) // keyInfo.dataSize
        readInput[42] = FunctionCode.readKey.rawValue

        guard let output = callSMC(input: readInput) else { return nil }

        let bytes = Array(output[48..<(48 + Int(dataSize))])
        return decode(bytes: bytes, type: dataType)
    }

    private func callSMC(input: [UInt8]) -> [UInt8]? {
        guard isOpen else { return nil }

        var inputCopy = input
        var output = [UInt8](repeating: 0, count: Self.structSize)
        var outputSize = Self.structSize

        let result = inputCopy.withUnsafeMutableBytes { inPtr -> kern_return_t in
            output.withUnsafeMutableBytes { outPtr -> kern_return_t in
                IOConnectCallStructMethod(
                    connection,
                    UInt32(Selector.handleYPCEvent.rawValue),
                    inPtr.baseAddress, Self.structSize,
                    outPtr.baseAddress, &outputSize
                )
            }
        }

        guard result == kIOReturnSuccess else { return nil }
        // result byte (offset 40) is non-zero on SMC-level failure.
        guard output[40] == 0 else { return nil }
        return output
    }

    // MARK: - Encoding helpers

    private func fourCharCode(_ string: String) -> UInt32? {
        let chars = Array(string.utf8)
        guard chars.count == 4 else { return nil }
        return UInt32(chars[0]) << 24 | UInt32(chars[1]) << 16 | UInt32(chars[2]) << 8 | UInt32(chars[3])
    }

    private func writeUInt32(_ value: UInt32, into buffer: inout [UInt8], at offset: Int) {
        buffer[offset]     = UInt8((value >> 24) & 0xFF)
        buffer[offset + 1] = UInt8((value >> 16) & 0xFF)
        buffer[offset + 2] = UInt8((value >> 8) & 0xFF)
        buffer[offset + 3] = UInt8(value & 0xFF)
    }

    private func readUInt32(_ buffer: [UInt8], at offset: Int) -> UInt32 {
        UInt32(buffer[offset]) << 24 | UInt32(buffer[offset + 1]) << 16 | UInt32(buffer[offset + 2]) << 8 | UInt32(buffer[offset + 3])
    }

    private func fourCharString(_ value: UInt32) -> String {
        let bytes = [UInt8((value >> 24) & 0xFF), UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
        return String(decoding: bytes, as: UTF8.self)
    }

    private func decode(bytes: [UInt8], type: UInt32) -> Double? {
        let typeString = fourCharString(type)

        switch typeString {
        case "flt ":
            guard bytes.count >= 4 else { return nil }
            let bits = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            return Double(Float(bitPattern: bits))

        case "sp78", "sp7a":
            guard bytes.count >= 2 else { return nil }
            let raw = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
            return Double(raw) / 256.0

        case "ui8 ":
            guard bytes.count >= 1 else { return nil }
            return Double(bytes[0])

        case "ui16":
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))

        case "ui32":
            guard bytes.count >= 4 else { return nil }
            return Double(readUInt32(bytes, at: 0))

        case "fpe2":
            guard bytes.count >= 2 else { return nil }
            let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            return Double(raw) / 4.0

        default:
            return nil
        }
    }
}
#endif

import AppKit
import Foundation
import IOKit
import IOKit.ps
import MachO

struct HardwareStatusSnapshot: Equatable {
    let capturedAt: Date
    let cpuUsagePercent: Double?
    let memory: MemoryStatus
    let battery: BatteryStatus?
    let thermalState: ProcessInfo.ThermalState
    let temperatures: [TemperatureReading]
    let fans: [FanStatus]
    let gpu: GPUStatus

    var cpuTemperature: TemperatureReading? {
        temperatures.first { $0.kind == .cpu }
    }

    var gpuTemperature: TemperatureReading? {
        temperatures.first { $0.kind == .gpu }
    }
}

struct MemoryStatus: Equatable {
    let totalBytes: UInt64
    let usedBytes: UInt64

    var usedPercent: Double {
        guard totalBytes > 0 else {
            return 0
        }
        return min(100, max(0, Double(usedBytes) / Double(totalBytes) * 100))
    }
}

struct BatteryStatus: Equatable {
    enum PowerSource: Equatable {
        case acPower
        case batteryPower
        case unknown(String)

        var title: String {
            switch self {
            case .acPower:
                return "电源适配器"
            case .batteryPower:
                return "电池"
            case let .unknown(value):
                return value
            }
        }
    }

    let percent: Int
    let isCharging: Bool
    let powerSource: PowerSource
    let timeRemainingMinutes: Int?
}

struct TemperatureReading: Equatable {
    enum Kind: Equatable {
        case cpu
        case gpu
        case battery
        case other
    }

    let name: String
    let celsius: Double
    let kind: Kind
}

struct FanStatus: Equatable {
    let name: String
    let rpm: Double
}

struct GPUStatus: Equatable {
    let name: String?
    let usagePercent: Double?
    let note: String?
}

final class HardwareStatusMonitor {
    private var previousCPUState: [CPUCoreState]?
    private let smcReader = SMCReader()
    private let gpuNameLock = NSLock()
    private var cachedGPUName: String?
    private var isLoadingGPUName = false

    init() {
        loadGPUNameIfNeeded()
    }

    func snapshot() -> HardwareStatusSnapshot {
        loadGPUNameIfNeeded()
        return HardwareStatusSnapshot(
            capturedAt: Date(),
            cpuUsagePercent: cpuUsagePercent(),
            memory: memoryStatus(),
            battery: batteryStatus(),
            thermalState: ProcessInfo.processInfo.thermalState,
            temperatures: temperatureReadings(),
            fans: fanStatuses(),
            gpu: GPUStatus(
                name: gpuName(),
                usagePercent: nil,
                note: "macOS 未提供稳定公开的 GPU 使用率 API；当前显示 GPU 名称和 SMC 温度（如可用）。"
            )
        )
    }

    private func gpuName() -> String? {
        gpuNameLock.lock()
        defer {
            gpuNameLock.unlock()
        }
        return cachedGPUName
    }

    private func loadGPUNameIfNeeded() {
        gpuNameLock.lock()
        let shouldLoad = cachedGPUName == nil && !isLoadingGPUName
        if shouldLoad {
            isLoadingGPUName = true
        }
        gpuNameLock.unlock()

        guard shouldLoad else {
            return
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let name = self?.queryGPUName()
            self?.gpuNameLock.lock()
            self?.cachedGPUName = name
            self?.isLoadingGPUName = false
            self?.gpuNameLock.unlock()
        }
    }

    private func cpuUsagePercent() -> Double? {
        guard let currentState = readCPUCoreStates() else {
            return nil
        }

        defer {
            previousCPUState = currentState
        }

        guard let previousCPUState, previousCPUState.count == currentState.count else {
            return nil
        }

        var usedTicks: UInt64 = 0
        var totalTicks: UInt64 = 0

        for (previous, current) in zip(previousCPUState, currentState) {
            let user = current.userTicks.subtracting(previous.userTicks)
            let system = current.systemTicks.subtracting(previous.systemTicks)
            let nice = current.niceTicks.subtracting(previous.niceTicks)
            let idle = current.idleTicks.subtracting(previous.idleTicks)

            usedTicks += user + system + nice
            totalTicks += user + system + nice + idle
        }

        guard totalTicks > 0 else {
            return nil
        }

        return Double(usedTicks) / Double(totalTicks) * 100
    }

    private func readCPUCoreStates() -> [CPUCoreState]? {
        var cpuInfo: processor_info_array_t?
        var numCpuInfo = mach_msg_type_number_t()
        var processorCount = natural_t()

        let result = host_processor_info(
            mach_host_self(),
            processor_flavor_t(PROCESSOR_CPU_LOAD_INFO),
            &processorCount,
            &cpuInfo,
            &numCpuInfo
        )

        guard result == KERN_SUCCESS, let cpuInfo else {
            return nil
        }

        defer {
            let byteCount = vm_size_t(Int(numCpuInfo) * MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: cpuInfo)), byteCount)
        }

        var states: [CPUCoreState] = []
        let cpuStateCount = Int(CPU_STATE_MAX)
        for cpu in 0..<Int(processorCount) {
            let offset = cpu * cpuStateCount
            states.append(
                CPUCoreState(
                    userTicks: tickValue(cpuInfo[offset + Int(CPU_STATE_USER)]),
                    systemTicks: tickValue(cpuInfo[offset + Int(CPU_STATE_SYSTEM)]),
                    idleTicks: tickValue(cpuInfo[offset + Int(CPU_STATE_IDLE)]),
                    niceTicks: tickValue(cpuInfo[offset + Int(CPU_STATE_NICE)])
                )
            )
        }
        return states
    }

    private func tickValue(_ value: integer_t) -> UInt64 {
        UInt64(UInt32(bitPattern: value))
    }

    private func memoryStatus() -> MemoryStatus {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        let total = ProcessInfo.processInfo.physicalMemory
        guard result == KERN_SUCCESS else {
            return MemoryStatus(totalBytes: total, usedBytes: 0)
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let usedPages = UInt64(stats.active_count + stats.wire_count + stats.compressor_page_count)
        let used = min(total, usedPages * pageSize)
        return MemoryStatus(totalBytes: total, usedBytes: used)
    }

    private func batteryStatus() -> BatteryStatus? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return nil
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int,
                  let maxCapacity = description[kIOPSMaxCapacityKey] as? Int,
                  maxCapacity > 0
            else {
                continue
            }

            let state = (description[kIOPSPowerSourceStateKey] as? String).map(powerSourceState) ?? .unknown("未知")
            let isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
            let percent = Int(round(Double(currentCapacity) / Double(maxCapacity) * 100))
            let minutes = (description[kIOPSTimeToEmptyKey] as? Int).flatMap { $0 > 0 ? $0 : nil }
                ?? (description[kIOPSTimeToFullChargeKey] as? Int).flatMap { $0 > 0 ? $0 : nil }

            return BatteryStatus(
                percent: min(100, max(0, percent)),
                isCharging: isCharging,
                powerSource: state,
                timeRemainingMinutes: minutes
            )
        }

        return nil
    }

    private func powerSourceState(_ rawValue: String) -> BatteryStatus.PowerSource {
        switch rawValue {
        case kIOPSACPowerValue:
            return .acPower
        case kIOPSBatteryPowerValue:
            return .batteryPower
        default:
            return .unknown(rawValue)
        }
    }

    private func temperatureReadings() -> [TemperatureReading] {
        let keys: [(String, String, TemperatureReading.Kind)] = [
            ("TC0P", "CPU Proximity", .cpu),
            ("TC0E", "CPU Core", .cpu),
            ("TC0F", "CPU Core", .cpu),
            ("TG0P", "GPU Proximity", .gpu),
            ("TG0D", "GPU Diode", .gpu),
            ("TB0T", "Battery", .battery)
        ]

        var readings: [TemperatureReading] = []
        var seenNames: Set<String> = []
        for (key, name, kind) in keys {
            guard let celsius = smcReader.readTemperature(key: key) else {
                continue
            }

            let displayName = seenNames.contains(name) ? "\(name) \(key)" : name
            seenNames.insert(name)
            readings.append(TemperatureReading(name: displayName, celsius: celsius, kind: kind))
        }

        return readings
    }

    private func fanStatuses() -> [FanStatus] {
        let fanCount = min(smcReader.readUInt(key: "FNum") ?? 0, 8)
        guard fanCount > 0 else {
            return []
        }

        return (0..<fanCount).compactMap { index in
            guard let rpm = smcReader.readFanSpeed(key: "F\(index)Ac") else {
                return nil
            }
            return FanStatus(name: "Fan \(index + 1)", rpm: rpm)
        }
    }

    private func queryGPUName() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        task.arguments = ["SPDisplaysDataType", "-json"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else {
                return nil
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let displays = object["SPDisplaysDataType"] as? [[String: Any]]
            else {
                return nil
            }

            let names = displays.compactMap { $0["sppci_model"] as? String }
            return names.isEmpty ? nil : names.joined(separator: " / ")
        } catch {
            return nil
        }
    }
}

private struct CPUCoreState {
    let userTicks: UInt64
    let systemTicks: UInt64
    let idleTicks: UInt64
    let niceTicks: UInt64
}

private extension UInt64 {
    func subtracting(_ other: UInt64) -> UInt64 {
        self >= other ? self - other : 0
    }
}

private final class SMCReader {
    private var connection = io_connect_t()
    private var isOpen = false

    init() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != IO_OBJECT_NULL else {
            return
        }
        defer {
            IOObjectRelease(service)
        }

        isOpen = IOServiceOpen(service, mach_task_self_, 0, &connection) == kIOReturnSuccess
    }

    deinit {
        if isOpen {
            IOServiceClose(connection)
        }
    }

    func readTemperature(key: String) -> Double? {
        guard let value = readKey(key) else {
            return nil
        }

        switch value.dataTypeString {
        case "sp78", "spa5":
            guard value.bytes.count >= 2 else {
                return nil
            }
            let raw = Int16(bitPattern: UInt16(value.bytes[0]) << 8 | UInt16(value.bytes[1]))
            return Double(raw) / 256.0
        case "flt ":
            return value.bytes.withUnsafeBytes { rawBuffer in
                guard rawBuffer.count >= MemoryLayout<Float>.size else {
                    return nil
                }
                return Double(rawBuffer.load(as: Float.self))
            }
        default:
            return nil
        }
    }

    func readFanSpeed(key: String) -> Double? {
        guard let value = readKey(key), value.bytes.count >= 2 else {
            return nil
        }

        switch value.dataTypeString {
        case "fpe2":
            let raw = UInt16(value.bytes[0]) << 8 | UInt16(value.bytes[1])
            return Double(raw) / 4.0
        case "flt ":
            return value.bytes.withUnsafeBytes { rawBuffer in
                guard rawBuffer.count >= MemoryLayout<Float>.size else {
                    return nil
                }
                return Double(rawBuffer.load(as: Float.self))
            }
        default:
            return nil
        }
    }

    func readUInt(key: String) -> Int? {
        guard let value = readKey(key) else {
            return nil
        }

        switch value.dataTypeString {
        case "ui8 ":
            return value.bytes.first.map(Int.init)
        case "ui16":
            guard value.bytes.count >= 2 else {
                return nil
            }
            return Int(UInt16(value.bytes[0]) << 8 | UInt16(value.bytes[1]))
        default:
            return nil
        }
    }

    private func readKey(_ key: String) -> SMCValue? {
        guard isOpen else {
            return nil
        }

        var input = SMCKeyData()
        var output = SMCKeyData()
        input.key = smcKey(key)
        input.data8 = SMCCommand.readKeyInfo.rawValue

        guard callSMC(input: &input, output: &output) else {
            return nil
        }

        let dataSize = Int(output.keyInfo.dataSize)
        guard dataSize > 0, dataSize <= 32 else {
            return nil
        }

        input = SMCKeyData()
        input.key = smcKey(key)
        input.keyInfo = output.keyInfo
        input.data8 = SMCCommand.readBytes.rawValue

        guard callSMC(input: &input, output: &output) else {
            return nil
        }

        return SMCValue(
            key: key,
            dataType: output.keyInfo.dataType,
            bytes: Array(output.bytes.array.prefix(dataSize))
        )
    }

    private func callSMC(input: inout SMCKeyData, output: inout SMCKeyData) -> Bool {
        let inputSize = MemoryLayout<SMCKeyData>.stride
        var outputSize = MemoryLayout<SMCKeyData>.stride
        let result = withUnsafeMutablePointer(to: &input) { inputPointer in
            withUnsafeMutablePointer(to: &output) { outputPointer in
                IOConnectCallStructMethod(
                    connection,
                    SMCMethod.index.rawValue,
                    inputPointer,
                    inputSize,
                    outputPointer,
                    &outputSize
                )
            }
        }
        return result == kIOReturnSuccess
    }

    private func smcKey(_ key: String) -> UInt32 {
        var result: UInt32 = 0
        for scalar in key.unicodeScalars.prefix(4) {
            result = (result << 8) + UInt32(scalar.value)
        }
        return result
    }
}

private struct SMCValue {
    let key: String
    let dataType: UInt32
    let bytes: [UInt8]

    var dataTypeString: String {
        let scalars = [
            UInt8((dataType >> 24) & 0xff),
            UInt8((dataType >> 16) & 0xff),
            UInt8((dataType >> 8) & 0xff),
            UInt8(dataType & 0xff)
        ]
        return String(bytes: scalars, encoding: .ascii) ?? ""
    }
}

private enum SMCMethod: UInt32 {
    case index = 2
}

private enum SMCCommand: UInt8 {
    case readBytes = 5
    case readKeyInfo = 9
}

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private struct SMCBytes {
    var b0: UInt8 = 0
    var b1: UInt8 = 0
    var b2: UInt8 = 0
    var b3: UInt8 = 0
    var b4: UInt8 = 0
    var b5: UInt8 = 0
    var b6: UInt8 = 0
    var b7: UInt8 = 0
    var b8: UInt8 = 0
    var b9: UInt8 = 0
    var b10: UInt8 = 0
    var b11: UInt8 = 0
    var b12: UInt8 = 0
    var b13: UInt8 = 0
    var b14: UInt8 = 0
    var b15: UInt8 = 0
    var b16: UInt8 = 0
    var b17: UInt8 = 0
    var b18: UInt8 = 0
    var b19: UInt8 = 0
    var b20: UInt8 = 0
    var b21: UInt8 = 0
    var b22: UInt8 = 0
    var b23: UInt8 = 0
    var b24: UInt8 = 0
    var b25: UInt8 = 0
    var b26: UInt8 = 0
    var b27: UInt8 = 0
    var b28: UInt8 = 0
    var b29: UInt8 = 0
    var b30: UInt8 = 0
    var b31: UInt8 = 0

    var array: [UInt8] {
        [
            b0, b1, b2, b3, b4, b5, b6, b7,
            b8, b9, b10, b11, b12, b13, b14, b15,
            b16, b17, b18, b19, b20, b21, b22, b23,
            b24, b25, b26, b27, b28, b29, b30, b31
        ]
    }
}

private struct SMCKeyData {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes = SMCBytes()
}

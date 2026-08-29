import Darwin
import Foundation
import ReisenData

struct RuntimeEnvironmentSnapshot: Equatable, Sendable {
    var architecture: String
    var physicalMemoryBytes: UInt64
    var processFootprintBytes: UInt64?
    var availableMemoryBytes: UInt64?
    var volumeAvailableBytes: Int64?
    var thermalState: String
    var lowPowerMode: Bool
    var processorCount: Int
    var activeProcessorCount: Int
    var systemUptimeSeconds: TimeInterval
    var cloudKitEnabled: Bool

    func tableRows() -> String {
        """
        | Architektur | \(architecture) |
        | RAM physisch | \(Self.mebibytes(physicalMemoryBytes)) |
        | Prozess-Fußabdruck | \(Self.optionalMebibytes(processFootprintBytes)) |
        | Freier Prozessspeicher | \(Self.optionalMebibytes(availableMemoryBytes)) |
        | Freier Volume-Platz | \(Self.optionalGibibytes(volumeAvailableBytes)) |
        | Thermal | \(thermalState) |
        | Energiesparmodus | \(lowPowerMode ? "ja" : "nein") |
        | Prozessoren | \(activeProcessorCount)/\(processorCount) |
        | System-Uptime | \(Int(systemUptimeSeconds.rounded())) s |
        | iCloud | \(cloudKitEnabled ? "an" : "aus") |
        """
    }

    static func mebibytes(_ bytes: UInt64) -> String {
        "\(bytes / (1024 * 1024)) MiB"
    }

    static func optionalMebibytes(_ bytes: UInt64?) -> String {
        guard let bytes else { return "nicht verfügbar" }
        return mebibytes(bytes)
    }

    static func optionalGibibytes(_ bytes: Int64?) -> String {
        guard let bytes else { return "nicht verfügbar" }
        let gib = Double(bytes) / (1024.0 * 1024.0 * 1024.0)
        return String(format: "%.1f GiB", gib)
    }

    static func footprintBytes(kernReturn: kern_return_t, physFootprint: UInt64) -> UInt64? {
        guard kernReturn == KERN_SUCCESS else { return nil }
        return physFootprint
    }

    static func volumeBytes(importantUsage: Int64?) -> Int64? {
        importantUsage
    }

    static func live() -> RuntimeEnvironmentSnapshot {
        let info = ProcessInfo.processInfo
        return RuntimeEnvironmentSnapshot(
            architecture: currentArchitecture(),
            physicalMemoryBytes: info.physicalMemory,
            processFootprintBytes: currentProcessFootprintBytes(),
            availableMemoryBytes: currentAvailableMemoryBytes(),
            volumeAvailableBytes: currentVolumeAvailableBytes(),
            thermalState: thermalLabel(info.thermalState),
            lowPowerMode: info.isLowPowerModeEnabled,
            processorCount: info.processorCount,
            activeProcessorCount: info.activeProcessorCount,
            systemUptimeSeconds: info.systemUptime,
            cloudKitEnabled: PersistenceBootstrap.isCloudKitEnabledByEnvironment()
        )
    }

    private static func currentArchitecture() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "nicht verfügbar"
        #endif
    }

    private static func thermalLabel(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "nicht verfügbar"
        }
    }

    private static func currentProcessFootprintBytes() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        )
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPointer, &count)
            }
        }
        return footprintBytes(kernReturn: result, physFootprint: UInt64(info.phys_footprint))
    }

    private static func currentAvailableMemoryBytes() -> UInt64? {
        #if os(iOS)
        let available = UInt64(os_proc_available_memory())
        return available > 0 ? available : nil
        #else
        return nil
        #endif
    }

    private static func currentVolumeAvailableBytes() -> Int64? {
        guard let support = PersistenceBootstrap.supportDirectoryURL() else { return nil }
        let values = try? support.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return volumeBytes(importantUsage: values?.volumeAvailableCapacityForImportantUsage)
    }
}

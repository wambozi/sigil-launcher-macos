import Foundation
#if canImport(Metal)
import Metal
#endif

struct HardwareInfo {
    let totalRAMGB: Int
    let cpuCores: Int
    let cpuArch: String
    let diskAvailableGB: Int
    let gpuName: String?
}

struct ResourceRecommendation {
    let memoryGB: Int
    let cpus: Int
    let diskGB: Int
}

enum HardwareDetector {
    static func detect() -> HardwareInfo {
        // RAM via ProcessInfo
        let totalRAM = ProcessInfo.processInfo.physicalMemory
        let totalRAMGB = Int(totalRAM / (1024 * 1024 * 1024))

        // CPU cores
        let cpuCores = ProcessInfo.processInfo.processorCount

        // Architecture
        #if arch(arm64)
        let cpuArch = "arm64"
        #else
        let cpuArch = "x86_64"
        #endif

        // Disk space
        var diskAvailableGB = 0
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let freeSpace = attrs[.systemFreeSize] as? Int64 {
            diskAvailableGB = Int(freeSpace / (1024 * 1024 * 1024))
        }

        // GPU name
        var gpuName: String? = nil
        #if canImport(Metal)
        if let device = MTLCreateSystemDefaultDevice() {
            gpuName = device.name
        }
        #endif

        return HardwareInfo(
            totalRAMGB: totalRAMGB,
            cpuCores: cpuCores,
            cpuArch: cpuArch,
            diskAvailableGB: diskAvailableGB,
            gpuName: gpuName
        )
    }

    static func recommend(for hardware: HardwareInfo) -> ResourceRecommendation {
        let memoryGB = min(max(hardware.totalRAMGB / 2, 4), 12)
        let cpus = max(hardware.cpuCores / 2, 2)
        let diskGB = 20

        return ResourceRecommendation(
            memoryGB: memoryGB,
            cpus: cpus,
            diskGB: diskGB
        )
    }

    static func meetsMinimumRequirements(_ hardware: HardwareInfo) -> (Bool, String?) {
        if hardware.totalRAMGB < 8 {
            return (false, "Sigil requires at least 8GB of system RAM. Detected: \(hardware.totalRAMGB)GB.")
        }
        if hardware.diskAvailableGB < 10 {
            return (false, "Sigil requires at least 10GB of free disk space. Available: \(hardware.diskAvailableGB)GB.")
        }
        return (true, nil)
    }
}

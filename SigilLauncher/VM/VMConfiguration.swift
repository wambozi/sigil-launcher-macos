import Foundation
import Virtualization

/// Builds a VZVirtualMachineConfiguration from a LauncherProfile.
enum VMConfiguration {

    static func build(from profile: LauncherProfile) throws -> VZVirtualMachineConfiguration {
        let config = VZVirtualMachineConfiguration()

        // CPU & Memory
        config.cpuCount = max(profile.cpuCount, VZVirtualMachineConfiguration.minimumAllowedCPUCount)
        config.memorySize = max(profile.memorySize, VZVirtualMachineConfiguration.minimumAllowedMemorySize)

        // Bootloader — direct Linux kernel boot
        config.bootLoader = try VMBootloader.create(from: profile)

        // Serial console (virtio) — captures boot logs
        let serialPort = VZVirtioConsoleDeviceSerialPortConfiguration()
        serialPort.attachment = VZFileHandleSerialPortAttachment(
            fileHandleForReading: FileHandle.nullDevice,
            fileHandleForWriting: FileHandle.standardOutput
        )
        config.serialPorts = [serialPort]

        // Root disk (virtio block device)
        let diskURL = URL(fileURLWithPath: profile.diskImagePath)
        let diskAttachment = try VZDiskImageStorageDeviceAttachment(url: diskURL, readOnly: false)
        let disk = VZVirtioBlockDeviceConfiguration(attachment: diskAttachment)
        config.storageDevices = [disk]

        // Networking — NAT
        let networkDevice = VZVirtioNetworkDeviceConfiguration()
        networkDevice.attachment = VZNATNetworkDeviceAttachment()
        config.networkDevices = [networkDevice]

        // Shared directories via virtio-fs
        var shares: [VZVirtioFileSystemDeviceConfiguration] = []

        // /workspace — user's project directory
        let workspaceURL = URL(fileURLWithPath: profile.workspacePath)
        if FileManager.default.fileExists(atPath: workspaceURL.path) {
            let workspaceShare = VZVirtioFileSystemDeviceConfiguration(tag: "workspace")
            let workspaceDir = VZSharedDirectory(url: workspaceURL, readOnly: false)
            workspaceShare.share = VZSingleDirectoryShare(directory: workspaceDir)
            shares.append(workspaceShare)
        }

        // /sigil-profile — persisted daemon state + credentials
        let profileDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".sigil/profiles/default")
        try FileManager.default.createDirectory(at: profileDir, withIntermediateDirectories: true)
        let profileShare = VZVirtioFileSystemDeviceConfiguration(tag: "sigil-profile")
        let profileDirectory = VZSharedDirectory(url: profileDir, readOnly: false)
        profileShare.share = VZSingleDirectoryShare(directory: profileDirectory)
        shares.append(profileShare)

        // /sigil-models — local LLM model files (read-only)
        let modelsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".sigil/models")
        if FileManager.default.fileExists(atPath: modelsDir.path) {
            let modelsShare = VZVirtioFileSystemDeviceConfiguration(tag: "sigil-models")
            let modelsDirectory = VZSharedDirectory(url: modelsDir, readOnly: true)
            modelsShare.share = VZSingleDirectoryShare(directory: modelsDirectory)
            shares.append(modelsShare)
        }

        config.directorySharingDevices = shares

        // Entropy device (required for Linux guests)
        config.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]

        // Memory balloon for dynamic memory management
        config.memoryBalloonDevices = [VZVirtioTraditionalMemoryBalloonDeviceConfiguration()]

        try config.validate()
        return config
    }
}

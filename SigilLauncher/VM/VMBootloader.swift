import Foundation
import Virtualization

/// Creates a VZLinuxBootLoader for direct kernel boot of the NixOS image.
public enum VMBootloader {

    public static func create(from profile: LauncherProfile) throws -> VZLinuxBootLoader {
        let kernelURL = URL(fileURLWithPath: profile.kernelPath)
        let initrdURL = URL(fileURLWithPath: profile.initrdPath)

        guard FileManager.default.fileExists(atPath: kernelURL.path) else {
            throw VMError.missingKernel(profile.kernelPath)
        }
        guard FileManager.default.fileExists(atPath: initrdURL.path) else {
            throw VMError.missingInitrd(profile.initrdPath)
        }

        let bootloader = VZLinuxBootLoader(kernelURL: kernelURL)
        bootloader.initialRamdiskURL = initrdURL
        bootloader.commandLine = profile.kernelCommandLine

        return bootloader
    }
}

public enum VMError: LocalizedError {
    case missingKernel(String)
    case missingInitrd(String)
    case missingDiskImage(String)
    case bootFailed(String)
    case sshTimeout
    case daemonTimeout

    public var errorDescription: String? {
        switch self {
        case .missingKernel(let path): return "Kernel not found at \(path)"
        case .missingInitrd(let path): return "Initrd not found at \(path)"
        case .missingDiskImage(let path): return "Disk image not found at \(path)"
        case .bootFailed(let msg): return "VM boot failed: \(msg)"
        case .sshTimeout: return "SSH did not become available within 30 seconds"
        case .daemonTimeout: return "sigild did not start within 30 seconds"
        }
    }
}

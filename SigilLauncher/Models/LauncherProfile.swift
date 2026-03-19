import Foundation

/// Persisted launcher settings stored at ~/.sigil/launcher/settings.json.
struct LauncherProfile: Codable {
    /// RAM allocated to the VM in bytes.
    var memorySize: UInt64

    /// Number of CPU cores allocated to the VM.
    var cpuCount: Int

    /// Host directory to mount as /workspace in the VM.
    var workspacePath: String

    /// Path to the VM disk image.
    var diskImagePath: String

    /// Path to the kernel (vmlinuz).
    var kernelPath: String

    /// Path to the initrd.
    var initrdPath: String

    /// SSH port forwarded from localhost to the VM.
    var sshPort: UInt16

    /// The kernel command line arguments.
    var kernelCommandLine: String

    static let defaultProfile = LauncherProfile(
        memorySize: 4 * 1024 * 1024 * 1024, // 4 GB
        cpuCount: 2,
        workspacePath: NSHomeDirectory() + "/workspace",
        diskImagePath: NSHomeDirectory() + "/.sigil/images/sigil-vm.img",
        kernelPath: NSHomeDirectory() + "/.sigil/images/vmlinuz",
        initrdPath: NSHomeDirectory() + "/.sigil/images/initrd",
        sshPort: 2222,
        kernelCommandLine: "console=hvc0 root=/dev/vda rw"
    )

    static var settingsURL: URL {
        let base = FileManager.default.homeDirectoryForCurrentUser
        return base.appendingPathComponent(".sigil/launcher/settings.json")
    }

    static func load() -> LauncherProfile {
        guard let data = try? Data(contentsOf: settingsURL),
              let profile = try? JSONDecoder().decode(LauncherProfile.self, from: data) else {
            return .defaultProfile
        }
        return profile
    }

    func save() throws {
        let dir = LauncherProfile.settingsURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(self)
        try data.write(to: LauncherProfile.settingsURL)
    }
}

import Foundation

/// Persisted launcher settings stored at ~/.sigil/launcher/settings.json.
public struct LauncherProfile: Codable {
    /// RAM allocated to the VM in bytes.
    public var memorySize: UInt64

    /// Number of CPU cores allocated to the VM.
    public var cpuCount: Int

    /// Host directory to mount as /workspace in the VM.
    public var workspacePath: String

    /// Path to the VM disk image.
    public var diskImagePath: String

    /// Path to the kernel (vmlinuz).
    public var kernelPath: String

    /// Path to the initrd.
    public var initrdPath: String

    /// SSH port forwarded from localhost to the VM.
    public var sshPort: UInt16

    /// The kernel command line arguments.
    public var kernelCommandLine: String

    /// Editor to install in the VM: "vscode", "neovim", "both", or "none".
    public var editor: String

    /// Container engine: "docker" or "none".
    public var containerEngine: String

    /// Default shell: "zsh" or "bash".
    public var shell: String

    /// Notification/suggestion level (0=silent, 1=digest, 2=ambient, 3=conversational, 4=autonomous).
    public var notificationLevel: Int

    /// Selected local model ID from the catalog, or nil for cloud-only inference.
    public var modelId: String?

    /// Path to the downloaded model file on disk, or nil if no local model.
    public var modelPath: String?

    public enum CodingKeys: String, CodingKey {
        case memorySize
        case cpuCount
        case workspacePath
        case diskImagePath
        case kernelPath
        case initrdPath
        case sshPort
        case kernelCommandLine
        case editor
        case containerEngine
        case shell
        case notificationLevel
        case modelId
        case modelPath
    }

    public init(
        memorySize: UInt64,
        cpuCount: Int,
        workspacePath: String,
        diskImagePath: String,
        kernelPath: String,
        initrdPath: String,
        sshPort: UInt16,
        kernelCommandLine: String,
        editor: String = "vscode",
        containerEngine: String = "docker",
        shell: String = "zsh",
        notificationLevel: Int = 2,
        modelId: String? = nil,
        modelPath: String? = nil
    ) {
        self.memorySize = memorySize
        self.cpuCount = cpuCount
        self.workspacePath = workspacePath
        self.diskImagePath = diskImagePath
        self.kernelPath = kernelPath
        self.initrdPath = initrdPath
        self.sshPort = sshPort
        self.kernelCommandLine = kernelCommandLine
        self.editor = editor
        self.containerEngine = containerEngine
        self.shell = shell
        self.notificationLevel = notificationLevel
        self.modelId = modelId
        self.modelPath = modelPath
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        memorySize = try container.decode(UInt64.self, forKey: .memorySize)
        cpuCount = try container.decode(Int.self, forKey: .cpuCount)
        workspacePath = try container.decode(String.self, forKey: .workspacePath)
        diskImagePath = try container.decode(String.self, forKey: .diskImagePath)
        kernelPath = try container.decode(String.self, forKey: .kernelPath)
        initrdPath = try container.decode(String.self, forKey: .initrdPath)
        sshPort = try container.decode(UInt16.self, forKey: .sshPort)
        kernelCommandLine = try container.decode(String.self, forKey: .kernelCommandLine)
        // New fields with backward-compatible defaults
        editor = try container.decodeIfPresent(String.self, forKey: .editor) ?? "vscode"
        containerEngine = try container.decodeIfPresent(String.self, forKey: .containerEngine) ?? "docker"
        shell = try container.decodeIfPresent(String.self, forKey: .shell) ?? "zsh"
        notificationLevel = try container.decodeIfPresent(Int.self, forKey: .notificationLevel) ?? 2
        modelId = try container.decodeIfPresent(String.self, forKey: .modelId)
        modelPath = try container.decodeIfPresent(String.self, forKey: .modelPath)
    }

    /// Returns true if any field that requires a VM rebuild has changed.
    public func needsRebuild(comparedTo other: LauncherProfile) -> Bool {
        return editor != other.editor ||
               containerEngine != other.containerEngine ||
               shell != other.shell ||
               modelId != other.modelId
    }

    public static let defaultProfile = LauncherProfile(
        memorySize: 4 * 1024 * 1024 * 1024, // 4 GB
        cpuCount: 2,
        workspacePath: NSHomeDirectory() + "/workspace",
        diskImagePath: NSHomeDirectory() + "/.sigil/images/sigil-vm.img",
        kernelPath: NSHomeDirectory() + "/.sigil/images/vmlinuz",
        initrdPath: NSHomeDirectory() + "/.sigil/images/initrd",
        sshPort: 2222,
        kernelCommandLine: "console=hvc0 root=/dev/vda rw"
    )

    public static var settingsURL: URL {
        let base = FileManager.default.homeDirectoryForCurrentUser
        return base.appendingPathComponent(".sigil/launcher/settings.json")
    }

    public static func load() -> LauncherProfile {
        guard let data = try? Data(contentsOf: settingsURL),
              let profile = try? JSONDecoder().decode(LauncherProfile.self, from: data) else {
            return .defaultProfile
        }
        return profile
    }

    public func save() throws {
        let dir = LauncherProfile.settingsURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(self)
        try data.write(to: LauncherProfile.settingsURL)
    }
}

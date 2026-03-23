import Foundation

public enum BuildState: String {
    case idle, building, complete, error
}

@MainActor
public class ImageBuilder: ObservableObject {
    @Published public var state: BuildState = .idle
    @Published public var progressMessage: String = ""
    @Published public var logOutput: String = ""
    @Published public var errorMessage: String?

    public init() {}

    public static let imagesDirectory: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".sigil/images")
    }()

    public static let profileDirectory: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".sigil/profiles/default")
    }()

    /// Check if a built image exists
    public var imageExists: Bool {
        FileManager.default.fileExists(atPath: Self.imagesDirectory.appendingPathComponent("vmlinuz").path)
    }

    /// Check if Nix is installed
    public static func nixPath() -> String? {
        let paths = ["/nix/var/nix/profiles/default/bin/nix", "/usr/local/bin/nix", "/opt/homebrew/bin/nix"]
        return paths.first { FileManager.default.fileExists(atPath: $0) }
    }

    /// Generate a flake.nix wrapper that imports sigil-os and applies tool selections
    public func generateFlake(profile: LauncherProfile, sigilOSPath: String) throws {
        let dir = Self.profileDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let flakeContent = """
        {
          inputs.sigil-os.url = "path:\(sigilOSPath)";
          inputs.nixpkgs.follows = "sigil-os/nixpkgs";

          outputs = { self, sigil-os, nixpkgs }: {
            nixosConfigurations.workspace = sigil-os.lib.mkLauncherVM {
              system = "aarch64-linux";
              tools = {
                editor = "\(profile.editor)";
                containerEngine = "\(profile.containerEngine)";
                shell = "\(profile.shell)";
                notificationLevel = \(profile.notificationLevel);
              };
            };
          };
        }
        """

        try flakeContent.write(to: dir.appendingPathComponent("flake.nix"), atomically: true, encoding: .utf8)
    }

    /// Build the VM image from the generated flake
    public func build(profile: LauncherProfile, sigilOSPath: String = "github:sigil-tech/sigil-os") async throws {
        guard let nix = Self.nixPath() else {
            throw ImageBuilderError.nixNotInstalled
        }

        state = .building
        progressMessage = "Generating configuration..."
        errorMessage = nil
        logOutput = ""

        do {
            // Generate the flake wrapper
            try generateFlake(profile: profile, sigilOSPath: sigilOSPath)

            progressMessage = "Building VM image (this may take several minutes)..."
            appendLog("$ nix build .#nixosConfigurations.workspace.config.system.build.toplevel\n")

            let profileDir = Self.profileDirectory.path

            // Build the system toplevel
            try await runNix(nix, args: [
                "--extra-experimental-features", "nix-command flakes",
                "build",
                "\(profileDir)#nixosConfigurations.workspace.config.system.build.toplevel",
                "--out-link", "\(profileDir)/result-toplevel",
                "--no-link", // Don't create symlink in CWD
            ], workingDir: profileDir)

            progressMessage = "Extracting kernel and initrd..."

            // Build kernel
            try await runNix(nix, args: [
                "--extra-experimental-features", "nix-command flakes",
                "build",
                "\(profileDir)#nixosConfigurations.workspace.config.system.build.kernel",
                "--out-link", "\(profileDir)/result-kernel",
            ], workingDir: profileDir)

            // Build initrd
            try await runNix(nix, args: [
                "--extra-experimental-features", "nix-command flakes",
                "build",
                "\(profileDir)#nixosConfigurations.workspace.config.system.build.initialRamdisk",
                "--out-link", "\(profileDir)/result-initrd",
            ], workingDir: profileDir)

            // Copy artifacts to images directory
            progressMessage = "Copying artifacts..."
            let imagesDir = Self.imagesDirectory
            try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

            let kernelSrc = "\(profileDir)/result-kernel/Image"  // aarch64 uses "Image" not "bzImage"
            let initrdSrc = "\(profileDir)/result-initrd/initrd"

            // Copy kernel
            let vmlinuzDest = imagesDir.appendingPathComponent("vmlinuz")
            if FileManager.default.fileExists(atPath: vmlinuzDest.path) {
                try FileManager.default.removeItem(at: vmlinuzDest)
            }
            try FileManager.default.copyItem(atPath: kernelSrc, toPath: vmlinuzDest.path)

            // Copy initrd
            let initrdDest = imagesDir.appendingPathComponent("initrd")
            if FileManager.default.fileExists(atPath: initrdDest.path) {
                try FileManager.default.removeItem(at: initrdDest)
            }
            try FileManager.default.copyItem(atPath: initrdSrc, toPath: initrdDest.path)

            // Create empty disk image if it doesn't exist
            let diskDest = imagesDir.appendingPathComponent("sigil-vm.img")
            if !FileManager.default.fileExists(atPath: diskDest.path) {
                progressMessage = "Creating disk image..."
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/dd")
                process.arguments = ["if=/dev/zero", "of=\(diskDest.path)", "bs=1m", "count=0", "seek=8192"]
                try process.run()
                process.waitUntilExit()
            }

            // Download model if selected
            if let modelId = profile.modelId,
               let model = ModelCatalog.models.first(where: { $0.id == modelId }) {
                let modelManager = ModelManager()
                if !modelManager.isModelDownloaded(model) {
                    progressMessage = "Downloading \(model.name) model..."
                    appendLog("Downloading \(model.filename) (\(model.sizeGB) GB)...\n")
                    _ = try await modelManager.downloadModel(model)
                }
            }

            progressMessage = "Build complete!"
            state = .complete
        } catch {
            state = .error
            errorMessage = error.localizedDescription
            appendLog("ERROR: \(error.localizedDescription)\n")
            throw error
        }
    }

    /// Run a nix command as a subprocess with real-time log capture
    private func runNix(_ nixPath: String, args: [String], workingDir: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: nixPath)
            process.arguments = args
            process.currentDirectoryURL = URL(fileURLWithPath: workingDir)

            let pipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = pipe
            process.standardError = errPipe

            // Stream stderr (nix outputs progress to stderr)
            errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self?.appendLog(str)
                    }
                }
            }

            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self?.appendLog(str)
                    }
                }
            }

            process.terminationHandler = { proc in
                pipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: ImageBuilderError.buildFailed(exitCode: Int(proc.terminationStatus)))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func appendLog(_ text: String) {
        logOutput += text
    }
}

public enum ImageBuilderError: LocalizedError {
    case nixNotInstalled
    case buildFailed(exitCode: Int)

    public var errorDescription: String? {
        switch self {
        case .nixNotInstalled:
            return "Nix is not installed. Install it from https://nixos.org/download/"
        case .buildFailed(let code):
            return "Build failed with exit code \(code). Check the build log for details."
        }
    }
}

import Foundation
import Virtualization
import Combine

/// Manages the VM lifecycle: create, start, stop, and health monitoring.
@MainActor
class VMManager: ObservableObject {
    @Published var state: VMState = .stopped
    @Published var errorMessage: String?
    @Published var sshReady = false
    @Published var daemonReady = false

    private var virtualMachine: VZVirtualMachine?
    private var profile: LauncherProfile
    private var healthCheckTask: Task<Void, Never>?

    init() {
        self.profile = LauncherProfile.load()
    }

    // MARK: - Lifecycle

    func start() async {
        guard state == .stopped || state == .error else { return }
        state = .starting
        errorMessage = nil
        sshReady = false
        daemonReady = false

        do {
            let config = try VMConfiguration.build(from: profile)
            let vm = VZVirtualMachine(configuration: config)
            self.virtualMachine = vm

            try await vm.start()
            state = .running

            // Start polling for SSH and daemon readiness
            healthCheckTask = Task {
                await pollForReady()
            }
        } catch {
            state = .error
            errorMessage = error.localizedDescription
        }
    }

    func stop() async {
        guard state == .running else { return }
        state = .stopping
        healthCheckTask?.cancel()

        guard let vm = virtualMachine else {
            state = .stopped
            return
        }

        // Try graceful shutdown via SSH first
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            process.arguments = [
                "-p", String(profile.sshPort),
                "-o", "StrictHostKeyChecking=no",
                "-o", "ConnectTimeout=5",
                "sigil@localhost",
                "sudo", "shutdown", "now"
            ]
            try process.run()
            process.waitUntilExit()

            // Wait up to 10 seconds for VM to stop
            for _ in 0..<20 {
                try await Task.sleep(nanoseconds: 500_000_000)
                if vm.state == .stopped {
                    break
                }
            }
        } catch {
            // Graceful shutdown failed — force stop
        }

        if vm.state != .stopped {
            do {
                try await vm.stop()
            } catch {
                // Already stopped or force failed
            }
        }

        virtualMachine = nil
        state = .stopped
        sshReady = false
        daemonReady = false
    }

    // MARK: - Health Checks

    private func pollForReady() async {
        // Poll SSH (timeout 30s)
        let sshDeadline = Date().addingTimeInterval(30)
        while !Task.isCancelled && Date() < sshDeadline {
            if await checkSSH() {
                sshReady = true
                break
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }

        guard sshReady else {
            errorMessage = "SSH did not become available"
            return
        }

        // Poll sigild (timeout 30s)
        let daemonDeadline = Date().addingTimeInterval(30)
        while !Task.isCancelled && Date() < daemonDeadline {
            if await checkDaemon() {
                daemonReady = true
                break
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        if !daemonReady {
            errorMessage = "sigild did not start"
        }

        // Bootstrap TLS credentials on first run
        if daemonReady {
            await bootstrapCredentials()
        }
    }

    private func checkSSH() async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = [
            "-p", String(profile.sshPort),
            "-o", "StrictHostKeyChecking=no",
            "-o", "ConnectTimeout=2",
            "-o", "BatchMode=yes",
            "sigil@localhost",
            "echo", "ok"
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func checkDaemon() async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = [
            "-p", String(profile.sshPort),
            "-o", "StrictHostKeyChecking=no",
            "-o", "ConnectTimeout=2",
            "sigil@localhost",
            "sigilctl", "status"
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Bootstraps TLS credentials for sigil-shell → sigild connection.
    /// On first run, generates a credential via sigilctl and writes it to the profile dir.
    private func bootstrapCredentials() async {
        let credPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".sigil/profiles/default/credentials.json")

        // Skip if credentials already exist
        if FileManager.default.fileExists(atPath: credPath.path) { return }

        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = [
            "-p", String(profile.sshPort),
            "-o", "StrictHostKeyChecking=no",
            "sigil@localhost",
            "sigilctl", "credential", "add", "sigil-shell"
        ]
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard !data.isEmpty else { return }

            // sigilctl credential add outputs the credential JSON
            let dir = credPath.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: credPath)

            // Also write daemon-settings.json for sigil-shell
            let settings: [String: Any] = [
                "transport": "tcp",
                "tcp_credential_path": credPath.path,
                "tcp_addr_override": "localhost:7773"
            ]
            let settingsData = try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
            let shellConfigDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config/sigil-shell")
            try FileManager.default.createDirectory(at: shellConfigDir, withIntermediateDirectories: true)
            try settingsData.write(to: shellConfigDir.appendingPathComponent("daemon-settings.json"))
        } catch {
            print("Credential bootstrap failed: \(error)")
        }
    }

    // MARK: - Shell Launch

    func launchShell() {
        guard daemonReady else { return }

        let process = Process()
        // Look for sigil-shell in /Applications or the build directory
        let shellPaths = [
            "/Applications/Sigil Shell.app/Contents/MacOS/sigil-shell",
            Bundle.main.bundlePath + "/../sigil-shell",
            NSHomeDirectory() + "/.sigil/bin/sigil-shell",
        ]

        guard let shellPath = shellPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            errorMessage = "sigil-shell not found"
            return
        }

        process.executableURL = URL(fileURLWithPath: shellPath)
        process.environment = ProcessInfo.processInfo.environment

        do {
            try process.run()
        } catch {
            errorMessage = "Failed to launch shell: \(error.localizedDescription)"
        }
    }

    // MARK: - Configuration

    func updateProfile(_ newProfile: LauncherProfile) {
        self.profile = newProfile
        try? newProfile.save()
    }

    var currentProfile: LauncherProfile { profile }
}

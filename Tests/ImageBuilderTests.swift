import XCTest
@testable import SigilLauncherLib

final class ImageBuilderTests: XCTestCase {

    // MARK: - generateFlake

    @MainActor
    func testGenerateFlakeProducesValidOutput() throws {
        let builder = ImageBuilder()
        let profile = LauncherProfile(
            memorySize: 8 * 1024 * 1024 * 1024,
            cpuCount: 4,
            workspacePath: "/tmp/workspace",
            diskImagePath: "/tmp/disk.img",
            kernelPath: "/tmp/vmlinuz",
            initrdPath: "/tmp/initrd",
            sshPort: 2222,
            kernelCommandLine: "console=hvc0 root=/dev/vda rw",
            editor: "neovim",
            containerEngine: "docker",
            shell: "bash",
            notificationLevel: 3
        )

        let sigilOSPath = "/tmp/sigil-os"
        try builder.generateFlake(profile: profile, sigilOSPath: sigilOSPath)

        // Read the generated flake.nix
        let flakeURL = ImageBuilder.profileDirectory.appendingPathComponent("flake.nix")
        let content = try String(contentsOf: flakeURL, encoding: .utf8)

        // Verify it contains the expected tool values
        XCTAssertTrue(content.contains("editor = \"neovim\""), "Flake should contain editor selection")
        XCTAssertTrue(content.contains("containerEngine = \"docker\""), "Flake should contain container engine")
        XCTAssertTrue(content.contains("shell = \"bash\""), "Flake should contain shell selection")
        XCTAssertTrue(content.contains("notificationLevel = 3"), "Flake should contain notification level")
        XCTAssertTrue(content.contains("path:\(sigilOSPath)"), "Flake should reference sigil-os path")
        XCTAssertTrue(content.contains("mkLauncherVM"), "Flake should call mkLauncherVM")
        XCTAssertTrue(content.contains("aarch64-linux"), "Flake should specify aarch64-linux")

        // Clean up generated file
        try? FileManager.default.removeItem(at: flakeURL)
    }

    @MainActor
    func testGenerateFlakeWithDifferentToolSelections() throws {
        let builder = ImageBuilder()
        let profile = LauncherProfile(
            memorySize: 4 * 1024 * 1024 * 1024,
            cpuCount: 2,
            workspacePath: "/tmp/workspace",
            diskImagePath: "/tmp/disk.img",
            kernelPath: "/tmp/vmlinuz",
            initrdPath: "/tmp/initrd",
            sshPort: 2222,
            kernelCommandLine: "console=hvc0 root=/dev/vda rw",
            editor: "both",
            containerEngine: "none",
            shell: "zsh",
            notificationLevel: 0
        )

        try builder.generateFlake(profile: profile, sigilOSPath: "github:sigil-tech/sigil-os")

        let flakeURL = ImageBuilder.profileDirectory.appendingPathComponent("flake.nix")
        let content = try String(contentsOf: flakeURL, encoding: .utf8)

        XCTAssertTrue(content.contains("editor = \"both\""))
        XCTAssertTrue(content.contains("containerEngine = \"none\""))
        XCTAssertTrue(content.contains("shell = \"zsh\""))
        XCTAssertTrue(content.contains("notificationLevel = 0"))

        // Clean up
        try? FileManager.default.removeItem(at: flakeURL)
    }

    // MARK: - nixPath

    func testNixPathMethodExists() {
        // nixPath is a static method that checks known paths for the nix binary.
        // On CI or systems without nix, it returns nil. On systems with nix, it
        // returns a valid path. Either way, the method should be callable.
        let result = ImageBuilder.nixPath()
        // We can only verify the method exists and returns String? — whether nix is
        // installed depends on the environment.
        if let path = result {
            XCTAssertTrue(FileManager.default.fileExists(atPath: path), "If nixPath returns a path, it should exist")
        }
        // If nil, nix is not installed — that is also a valid result.
    }

    // MARK: - Static Directories

    func testImagesDirectoryIsUnderSigilDir() {
        let path = ImageBuilder.imagesDirectory.path
        XCTAssertTrue(path.contains(".sigil/images"), "Images directory should be under .sigil/images")
    }

    func testProfileDirectoryIsUnderSigilDir() {
        let path = ImageBuilder.profileDirectory.path
        XCTAssertTrue(path.contains(".sigil/profiles/default"), "Profile directory should be under .sigil/profiles/default")
    }
}

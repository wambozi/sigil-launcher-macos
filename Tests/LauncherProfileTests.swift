import XCTest
@testable import SigilLauncherLib

final class LauncherProfileTests: XCTestCase {

    // MARK: - Default Profile

    func testDefaultProfileHasExpectedValues() {
        let profile = LauncherProfile.defaultProfile

        XCTAssertEqual(profile.memorySize, 4 * 1024 * 1024 * 1024)
        XCTAssertEqual(profile.cpuCount, 2)
        XCTAssertTrue(profile.workspacePath.hasSuffix("/workspace"))
        XCTAssertTrue(profile.diskImagePath.hasSuffix("/.sigil/images/sigil-vm.img"))
        XCTAssertTrue(profile.kernelPath.hasSuffix("/.sigil/images/vmlinuz"))
        XCTAssertTrue(profile.initrdPath.hasSuffix("/.sigil/images/initrd"))
        XCTAssertEqual(profile.sshPort, 2222)
        XCTAssertEqual(profile.kernelCommandLine, "console=hvc0 root=/dev/vda rw")
        XCTAssertEqual(profile.editor, "vscode")
        XCTAssertEqual(profile.containerEngine, "docker")
        XCTAssertEqual(profile.shell, "zsh")
        XCTAssertEqual(profile.notificationLevel, 2)
        XCTAssertNil(profile.modelId)
        XCTAssertNil(profile.modelPath)
    }

    // MARK: - Save + Load Round-Trip

    func testSaveAndLoadRoundTrip() throws {
        let profile = LauncherProfile(
            memorySize: 8 * 1024 * 1024 * 1024,
            cpuCount: 4,
            workspacePath: "/tmp/test-workspace",
            diskImagePath: "/tmp/test-disk.img",
            kernelPath: "/tmp/test-vmlinuz",
            initrdPath: "/tmp/test-initrd",
            sshPort: 3333,
            kernelCommandLine: "console=hvc0 root=/dev/vda rw quiet",
            editor: "neovim",
            containerEngine: "none",
            shell: "bash",
            notificationLevel: 3,
            modelId: "qwen2.5-1.5b-q4",
            modelPath: "/tmp/models/qwen.gguf"
        )

        // Encode and decode
        let encoder = JSONEncoder()
        let data = try encoder.encode(profile)
        let decoder = JSONDecoder()
        let loaded = try decoder.decode(LauncherProfile.self, from: data)

        XCTAssertEqual(loaded.memorySize, profile.memorySize)
        XCTAssertEqual(loaded.cpuCount, profile.cpuCount)
        XCTAssertEqual(loaded.workspacePath, profile.workspacePath)
        XCTAssertEqual(loaded.diskImagePath, profile.diskImagePath)
        XCTAssertEqual(loaded.kernelPath, profile.kernelPath)
        XCTAssertEqual(loaded.initrdPath, profile.initrdPath)
        XCTAssertEqual(loaded.sshPort, profile.sshPort)
        XCTAssertEqual(loaded.kernelCommandLine, profile.kernelCommandLine)
        XCTAssertEqual(loaded.editor, profile.editor)
        XCTAssertEqual(loaded.containerEngine, profile.containerEngine)
        XCTAssertEqual(loaded.shell, profile.shell)
        XCTAssertEqual(loaded.notificationLevel, profile.notificationLevel)
        XCTAssertEqual(loaded.modelId, profile.modelId)
        XCTAssertEqual(loaded.modelPath, profile.modelPath)
    }

    // MARK: - Backward Compatibility

    func testBackwardCompatibilityWithMissingNewFields() throws {
        // JSON from an older version that lacks editor, containerEngine, shell, notificationLevel, modelId, modelPath
        let oldJSON = """
        {
            "memorySize": 4294967296,
            "cpuCount": 2,
            "workspacePath": "/Users/test/workspace",
            "diskImagePath": "/Users/test/.sigil/images/sigil-vm.img",
            "kernelPath": "/Users/test/.sigil/images/vmlinuz",
            "initrdPath": "/Users/test/.sigil/images/initrd",
            "sshPort": 2222,
            "kernelCommandLine": "console=hvc0 root=/dev/vda rw"
        }
        """.data(using: .utf8)!

        let profile = try JSONDecoder().decode(LauncherProfile.self, from: oldJSON)

        // New fields should have their defaults
        XCTAssertEqual(profile.editor, "vscode")
        XCTAssertEqual(profile.containerEngine, "docker")
        XCTAssertEqual(profile.shell, "zsh")
        XCTAssertEqual(profile.notificationLevel, 2)
        XCTAssertNil(profile.modelId)
        XCTAssertNil(profile.modelPath)

        // Original fields should be preserved
        XCTAssertEqual(profile.memorySize, 4294967296)
        XCTAssertEqual(profile.cpuCount, 2)
        XCTAssertEqual(profile.sshPort, 2222)
    }

    // MARK: - needsRebuild

    func testNeedsRebuildReturnsTrueWhenEditorChanges() {
        var a = LauncherProfile.defaultProfile
        var b = LauncherProfile.defaultProfile

        a.editor = "vscode"
        b.editor = "neovim"

        XCTAssertTrue(a.needsRebuild(comparedTo: b))
    }

    func testNeedsRebuildReturnsTrueWhenContainerEngineChanges() {
        var a = LauncherProfile.defaultProfile
        var b = LauncherProfile.defaultProfile

        a.containerEngine = "docker"
        b.containerEngine = "none"

        XCTAssertTrue(a.needsRebuild(comparedTo: b))
    }

    func testNeedsRebuildReturnsTrueWhenShellChanges() {
        var a = LauncherProfile.defaultProfile
        var b = LauncherProfile.defaultProfile

        a.shell = "zsh"
        b.shell = "bash"

        XCTAssertTrue(a.needsRebuild(comparedTo: b))
    }

    func testNeedsRebuildReturnsTrueWhenModelIdChanges() {
        var a = LauncherProfile.defaultProfile
        var b = LauncherProfile.defaultProfile

        a.modelId = nil
        b.modelId = "qwen2.5-1.5b-q4"

        XCTAssertTrue(a.needsRebuild(comparedTo: b))
    }

    func testNeedsRebuildReturnsFalseWhenOnlyMemoryChanges() {
        var a = LauncherProfile.defaultProfile
        var b = LauncherProfile.defaultProfile

        a.memorySize = 4 * 1024 * 1024 * 1024
        b.memorySize = 8 * 1024 * 1024 * 1024

        XCTAssertFalse(a.needsRebuild(comparedTo: b))
    }

    func testNeedsRebuildReturnsFalseWhenOnlyCPUChanges() {
        var a = LauncherProfile.defaultProfile
        var b = LauncherProfile.defaultProfile

        a.cpuCount = 2
        b.cpuCount = 4

        XCTAssertFalse(a.needsRebuild(comparedTo: b))
    }

    func testNeedsRebuildReturnsFalseWhenOnlyNotificationLevelChanges() {
        var a = LauncherProfile.defaultProfile
        var b = LauncherProfile.defaultProfile

        a.notificationLevel = 0
        b.notificationLevel = 4

        XCTAssertFalse(a.needsRebuild(comparedTo: b))
    }
}

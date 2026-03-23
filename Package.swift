// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SigilLauncher",
    platforms: [
        .macOS(.v13) // Ventura — required for virtio-fs support
    ],
    targets: [
        .target(
            name: "SigilLauncherLib",
            path: "SigilLauncher",
            exclude: ["SigilLauncher.entitlements", "App"],
            sources: [
                "Models/LauncherProfile.swift",
                "Models/ModelCatalog.swift",
                "Models/ModelManager.swift",
                "Models/VMState.swift",
                "Services/HardwareDetector.swift",
                "Services/ImageBuilder.swift",
                "VM/VMBootloader.swift",
                "VM/VMConfiguration.swift",
                "VM/VMManager.swift",
                "Views/ConfigurationView.swift",
                "Views/LauncherView.swift",
                "Views/SetupWizard.swift",
            ]
        ),
        .executableTarget(
            name: "SigilLauncher",
            dependencies: ["SigilLauncherLib"],
            path: "Sources/SigilLauncherApp"
        ),
        .testTarget(
            name: "SigilLauncherTests",
            dependencies: ["SigilLauncherLib"],
            path: "Tests"
        ),
    ]
)

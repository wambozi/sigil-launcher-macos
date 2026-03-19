// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SigilLauncher",
    platforms: [
        .macOS(.v13) // Ventura — required for virtio-fs support
    ],
    targets: [
        .executableTarget(
            name: "SigilLauncher",
            path: "SigilLauncher",
            exclude: ["SigilLauncher.entitlements"]
        ),
    ]
)

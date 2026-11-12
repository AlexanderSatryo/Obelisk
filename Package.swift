// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Obelisk",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Obelisk", targets: ["Obelisk"]),
        .library(name: "ObeliskMediaRemoteNative", type: .dynamic, targets: ["ObeliskMediaRemoteNative"])
    ],
    targets: [
        .target(
            name: "ObeliskMediaRemoteNative",
            path: "Sources/ObeliskMediaRemoteNative",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "Obelisk",
            dependencies: [
                "ObeliskMediaRemoteNative"
            ],
            path: "Sources/Obelisk"
        )
    ]
)

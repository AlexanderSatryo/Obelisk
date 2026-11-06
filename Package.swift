// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Obelisk",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Obelisk", targets: ["Obelisk"])
    ],
    targets: [
        .executableTarget(
            name: "Obelisk",
            path: "Sources/Obelisk"
        )
    ]
)


// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BlockpMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "BlockpMacCore",
            targets: ["BlockpMacCore"]
        ),
        .executable(
            name: "blockpmac",
            targets: ["blockpmac"]
        )
        ,
        .executable(
            name: "BlockpMacApp",
            targets: ["BlockpMacApp"]
        )
    ],
    targets: [
        .target(
            name: "BlockpMacCore"
        ),
        .executableTarget(
            name: "blockpmac",
            dependencies: ["BlockpMacCore"]
        ),
        .executableTarget(
            name: "BlockpMacApp",
            dependencies: ["BlockpMacCore"]
        )
    ]
)

// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "openwith",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.6"),
        // swift-testing is bundled with full Xcode but not with Command Line Tools,
        // so we declare it as an explicit dependency for CLT-only setups.
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.10.0")
    ],
    targets: [
        .target(
            name: "OpenWithCore",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ]
        ),
        .executableTarget(
            name: "openwith",
            dependencies: ["OpenWithCore"]
        ),
        .testTarget(
            name: "OpenWithCoreTests",
            dependencies: [
                "OpenWithCore",
                .product(name: "Testing", package: "swift-testing")
            ]
        )
    ]
)

// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "triage",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.1"),
        // swift-testing is bundled with full Xcode but not with Command Line Tools,
        // so we declare it as an explicit dependency for CLT-only setups.
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "6.3.1")
    ],
    targets: [
        .target(
            name: "TriageCore",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ]
        ),
        .executableTarget(
            name: "triage",
            dependencies: ["TriageCore"]
        ),
        .testTarget(
            name: "TriageCoreTests",
            dependencies: [
                "TriageCore",
                .product(name: "Testing", package: "swift-testing")
            ]
        )
    ]
)

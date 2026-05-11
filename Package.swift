// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "triage",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.1")
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
            dependencies: ["TriageCore"]
        )
    ],
    // Keep Swift 5 language mode under the Swift 6.2 toolchain. The toolchain
    // bump is needed so `import Testing` resolves against the bundled
    // swift-testing; the strict-concurrency migration is tracked separately.
    swiftLanguageModes: [.v5]
)

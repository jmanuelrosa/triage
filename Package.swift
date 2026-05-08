// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "openwith",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.6")
    ],
    targets: [
        .executableTarget(
            name: "openwith",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ]
        )
    ]
)

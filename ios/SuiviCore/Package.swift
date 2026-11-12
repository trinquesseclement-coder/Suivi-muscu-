// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SuiviCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SuiviCore", targets: ["SuiviCore"])
    ],
    targets: [
        .target(name: "SuiviCore"),
        .testTarget(name: "SuiviCoreTests", dependencies: ["SuiviCore"])
    ]
)

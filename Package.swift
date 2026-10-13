// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NahtKey",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "NahtKeyCore", targets: ["NahtKeyCore"]),
        .executable(name: "NahtKey", targets: ["NahtKeyApp"])
    ],
    targets: [
        .target(name: "NahtKeyCore"),
        .executableTarget(name: "NahtKeyApp", dependencies: ["NahtKeyCore"]),
        .testTarget(name: "NahtKeyCoreTests", dependencies: ["NahtKeyCore"]),
        .testTarget(name: "NahtKeyAppTests", dependencies: ["NahtKeyApp"])
    ]
)

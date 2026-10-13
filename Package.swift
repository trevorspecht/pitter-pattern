// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "PitterPattern",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PitterCore", targets: ["PitterCore"])
    ],
    dependencies: [
        // swift-testing is NOT shipped with Command Line Tools toolchains
        // (only full Xcode provides it); pulled as a pinned dependency so
        // `swift test` works headlessly. Harmless when Xcode is installed.
        .package(url: "https://github.com/swiftlang/swift-testing", from: "0.12.0"),
    ],
    targets: [
        .target(name: "PitterCore"),
        .testTarget(
            name: "PitterCoreTests",
            dependencies: [
                .target(name: "PitterCore"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        )
    ]
)

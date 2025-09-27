// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "kubex",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "kubex", targets: ["kubex"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "kubex"
        ),
        .testTarget(
            name: "kubexTests",
            dependencies: [
                "kubex",
                .product(name: "Testing", package: "swift-testing")
            ]
        )
    ]
)

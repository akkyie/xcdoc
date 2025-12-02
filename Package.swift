// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "xcdoc",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "xcdoc", targets: ["xcdoc"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.3.0"),
        .package(url: "https://github.com/swiftlang/swift-subprocess", from: "0.2.1"),
        .package(url: "https://github.com/swiftlang/swift-docc", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "xcdoc",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "HeapModule", package: "swift-collections"),
                .product(name: "Subprocess", package: "swift-subprocess"),
                .product(name: "SwiftDocC", package: "swift-docc"),
            ]
        ),
        .testTarget(
            name: "XcdocTests",
            dependencies: [
                "xcdoc",
                .product(name: "Subprocess", package: "swift-subprocess"),
                .product(name: "SwiftDocC", package: "swift-docc"),
            ]
        ),
    ],
)

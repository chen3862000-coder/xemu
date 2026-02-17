// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AppHost",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .executable(name: "AppHost", targets: ["AppHost"])
    ],
    targets: [
        .executableTarget(
            name: "AppHost",
            path: "Sources/AppHost"
        ),
        .testTarget(
            name: "AppHostTests",
            dependencies: ["AppHost"],
            path: "Tests"
        ),
    ]
)

// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AppHost",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AppHost", type: .static, targets: ["AppHost"])
    ],
    targets: [
        .target(
            name: "AppHost",
            path: "Sources",
            resources: [
                .process("AppHost/Model.xcdatamodeld")
            ]
        ),
        .testTarget(
            name: "AppHostTests",
            dependencies: ["AppHost"],
            path: "Tests"
        ),
    ]
)

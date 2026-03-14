// swift-tools-version: 5.10
import PackageDescription

let useRealCores = false // Set to false for macOS testing, true for iOS Simulator builds

let package = Package(
    name: "Xemu",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Xemu",
            targets: ["Xemu"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "XemuCoresLib",
            path: "Sources/XemuCoresLib",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("c++"),
                .linkedLibrary("resolv"),
            ]
        ),
        
        .target(
            name: "XemuCores",
            dependencies: ["XemuCoresLib"],
            path: "Sources/XemuCores",
            publicHeadersPath: "include"
        ),
        
        .target(
            name: "Xemu",
            dependencies: ["XemuCores"],
            path: "Sources",
            exclude: [
                "AppHost/iOSApp.swift",
                "XemuCores"
            ],
            resources: [
                .process("Features/Covers/Resources"),
                .process("../Resources/MockData")
            ],
            linkerSettings: [
                .linkedLibrary("c++"),
                .linkedLibrary("resolv"),
                .linkedLibrary("sqlite3")
            ]
        ),
        
        .testTarget(
            name: "XemuTests",
            dependencies: ["Xemu"],
            path: "Tests/AppHostTests"
        ),
    ],
    cLanguageStandard: .c11,
    cxxLanguageStandard: .cxx17
)

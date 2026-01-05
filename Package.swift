// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Yunjian",
    defaultLocalization: "zh-Hans",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "YunjianCore", targets: ["YunjianCore"]),
        .library(name: "EditorEngine", targets: ["EditorEngine"]),
        .library(name: "StorageService", targets: ["StorageService"]),
        .library(name: "SyncEngine", targets: ["SyncEngine"]),
        .library(name: "UIComponents", targets: ["UIComponents"]),
        .executable(name: "YunjianDev", targets: ["YunjianDev"])
    ],
    dependencies: [
        // Apple 官方 Markdown 解析库
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.3.0")
    ],
    targets: [
        .target(
            name: "YunjianCore"
        ),
        .target(
            name: "EditorEngine",
            dependencies: [
                "YunjianCore",
                .product(name: "Markdown", package: "swift-markdown")
            ]
        ),
        .target(
            name: "StorageService",
            dependencies: ["YunjianCore"]
        ),
        .target(
            name: "SyncEngine",
            dependencies: ["YunjianCore", "StorageService"]
        ),
        .target(
            name: "UIComponents",
            dependencies: ["YunjianCore", "EditorEngine", "StorageService", "SyncEngine"]
            ,
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "YunjianDev",
            dependencies: [
                "UIComponents",
                "StorageService",
                "SyncEngine",
                "YunjianCore"
            ]
        )
    ]
)

// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Purpl",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "Purpl", targets: ["Purpl"]),
        .library(name: "PurplUI", targets: ["PurplUI"])
    ],
    targets: [
        // StoreKit 구매와 권한 관리를 제공하는 핵심 SDK 타겟
        .target(
            name: "Purpl",
            resources: [.process("Resources")]
        ),

        // SwiftUI 페이월을 제공하는 선택 UI 타겟
        .target(
            name: "PurplUI",
            dependencies: ["Purpl"],
            resources: [.process("Resources")]
        ),

        // Purpl 핵심 SDK 테스트 타겟
        .testTarget(
            name: "PurplTests",
            dependencies: ["Purpl"]
        ),

        // Purpl SwiftUI 페이월 테스트 타겟
        .testTarget(
            name: "PurplUITests",
            dependencies: ["Purpl", "PurplUI"]
        )
    ]
)

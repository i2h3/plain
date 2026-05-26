// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PlainLang",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "plain",
            path: "Sources/PlainLang"
        ),
        .testTarget(
            name: "PlainLangTests",
            dependencies: [],
            path: "Tests/PlainLangTests"
        )
    ]
)

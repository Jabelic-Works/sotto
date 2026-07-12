// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Sotto",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Sotto", targets: ["Sotto"]),
    ],
    targets: [
        .executableTarget(name: "Sotto"),
        .testTarget(name: "SottoTests", dependencies: ["Sotto"]),
    ]
)

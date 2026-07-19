// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Sotto",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Sotto", targets: ["Sotto"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", .upToNextMinor(from: "3.31.4")),
        .package(url: "https://github.com/huggingface/swift-huggingface", from: "0.9.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", .upToNextMinor(from: "1.3.3")),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "Sotto",
            dependencies: [
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "Tokenizers", package: "swift-transformers"),
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
        .testTarget(name: "SottoTests", dependencies: ["Sotto"]),
    ]
)

// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "HelloAudioStream",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "audio_stream_client", targets: ["AudioStreamClient"]),
        .executable(name: "audio_stream_server", targets: ["AudioStreamServer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.80.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
    ],
    targets: [
        .target(
            name: "AudioStreamCommon",
            dependencies: [],
            path: "Sources",
            sources: [
                "Logger.swift",
                "Types.swift",
            ]
        ),
        .executableTarget(
            name: "AudioStreamClient",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "AudioStreamCommon",
            ],
            path: "Sources",
            sources: [
                "main.swift",
                "Client/AudioClientApplication.swift",
                "Client/Core/WebSocketClient.swift",
                "Client/Core/ChunkManager.swift",
                "Client/Core/UploadManager.swift",
                "Client/Core/DownloadManager.swift",
                "Client/Core/FileManager.swift",
                "Client/Util/ErrorHandler.swift",
                "Client/Util/PerformanceMonitor.swift",
                "Client/Util/StreamIdGenerator.swift",
                "Client/Util/VerificationModule.swift",
            ]
        ),
        .executableTarget(
            name: "AudioStreamServer",
            dependencies: [
                "AudioStreamCommon",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOWebSocket", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources",
            sources: [
                "Server/AudioServerApplication.swift",
                "Server/Handler/WebSocketMessageHandler.swift",
                "Server/Memory/MemoryMappedCache.swift",
                "Server/Memory/MemoryPoolManager.swift",
                "Server/Memory/StreamContext.swift",
                "Server/Memory/StreamManager.swift",
                "Server/Network/AudioWebSocketServer.swift",
            ]
        ),
    ],
    swiftLanguageVersions: [.v6]
)

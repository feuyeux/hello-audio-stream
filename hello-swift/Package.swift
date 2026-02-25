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
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AudioStreamClient",
            dependencies: [],
            path: "Sources/Client"
        ),
        .executableTarget(
            name: "AudioStreamServer",
            dependencies: [],
            path: "Sources/Server"
        ),
    ],
    swiftLanguageModes: [.v5]
)

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Audio stream WebSocket client.
final class Client: NSObject, @unchecked Sendable {
    private let serverUri: String
    private var wsTask: URLSessionWebSocketTask?
    private lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()
    private var connContinuation: CheckedContinuation<Void, Error>?
    private var isConnected = false

    init(serverUri: String) {
        self.serverUri = serverUri
        super.init()
    }

    // MARK: - Public API

    func run(input: String, output: String, streamId: String) async throws {
        let inputURL = URL(fileURLWithPath: input)
        let inputData = try Data(contentsOf: inputURL)
        print("Input: \(input) (\(inputData.count) bytes)")
        print("Server: \(serverUri)")

        try await connect()
        defer { close() }

        // Upload
        try await upload(streamId: streamId, data: inputData)
        print("Upload complete")

        // Wait briefly then download
        try await Task.sleep(nanoseconds: 1_000_000_000)
        try await download(streamId: streamId, output: output, expectedSize: inputData.count)
        print("Download complete: \(output)")

        // Verify
        verify(input: input, output: output)

        // Close stream
        try await sendJson(["command": "CLOSE", "streamId": streamId])
        let _ = try await receiveText()
    }

    // MARK: - Upload

    private func upload(streamId: String, data: Data) async throws {
        try await sendJson(["command": "CREATE", "streamId": streamId])
        let resp = try await receiveText()
        guard resp.contains("CREATED") else { throw ClientError.unexpected(resp) }

        let chunkSize = 8192
        var offset = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            let chunk = data[offset..<end]
            try await wsTask?.send(.data(Data(chunk)))
            offset = end
        }

        try await sendJson(["command": "COMPLETE"])
        let compResp = try await receiveText()
        guard compResp.contains("COMPLETED") else { throw ClientError.unexpected(compResp) }
    }

    // MARK: - Download

    private func download(streamId: String, output: String, expectedSize: Int) async throws {
        // Ensure output directory exists
        let dir = (output as NSString).deletingLastPathComponent
        if !dir.isEmpty {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }

        var downloaded = Data()
        var offset = 0
        let chunkSize = 65536

        while offset < expectedSize {
            let length = min(chunkSize, expectedSize - offset)
            try await sendJson([
                "command": "READ",
                "streamId": streamId,
                "offset": offset,
                "length": length,
            ] as [String: Any])

            guard let chunk = try await receiveBinary() else {
                throw ClientError.noData
            }
            downloaded.append(chunk)
            offset += chunk.count
        }

        try downloaded.write(to: URL(fileURLWithPath: output))
    }

    // MARK: - Verify

    private func verify(input: String, output: String) {
        guard let inData = try? Data(contentsOf: URL(fileURLWithPath: input)),
              let outData = try? Data(contentsOf: URL(fileURLWithPath: output)) else {
            print("Verification: FAILED (cannot read files)")
            return
        }
        if inData == outData {
            print("Verification: OK (size=\(inData.count))")
        } else {
            print("Verification: FAILED (size \(inData.count) vs \(outData.count))")
        }
    }

    // MARK: - WebSocket I/O

    private func connect() async throws {
        guard let url = URL(string: serverUri) else { throw ClientError.badUri }
        wsTask = session.webSocketTask(with: url)
        startReceiving()
        wsTask?.resume()

        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            connContinuation = c
        }

        // Consume CONNECTED message
        let _ = try await receiveText()
        print("Connected")
    }

    private func close() {
        wsTask?.cancel(with: .goingAway, reason: nil)
        isConnected = false
    }

    private func sendJson(_ dict: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: dict)
        guard let text = String(data: data, encoding: .utf8) else { throw ClientError.encodingError }
        try await wsTask?.send(.string(text))
    }

    private var textCont: CheckedContinuation<String, Error>?
    private var binaryCont: CheckedContinuation<Data, Error>?

    private func receiveText() async throws -> String {
        return try await withCheckedThrowingContinuation { c in
            textCont = c
        }
    }

    private func receiveBinary() async throws -> Data? {
        return try await withCheckedThrowingContinuation { c in
            binaryCont = c
        }
    }

    private func startReceiving() {
        wsTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let msg):
                switch msg {
                case .string(let text):
                    if let c = self.textCont {
                        self.textCont = nil
                        c.resume(returning: text)
                    }
                case .data(let data):
                    if let c = self.binaryCont {
                        self.binaryCont = nil
                        c.resume(returning: data)
                    }
                @unknown default: break
                }
                self.startReceiving()
            case .failure(let error):
                self.textCont?.resume(throwing: error)
                self.textCont = nil
                self.binaryCont?.resume(throwing: error)
                self.binaryCont = nil
            }
        }
    }
}

extension Client: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        isConnected = true
        connContinuation?.resume()
        connContinuation = nil
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        isConnected = false
    }
}

enum ClientError: Error, CustomStringConvertible {
    case badUri, encodingError, noData, unexpected(String)

    var description: String {
        switch self {
        case .badUri: return "Invalid server URI"
        case .encodingError: return "JSON encoding error"
        case .noData: return "No data received"
        case .unexpected(let msg): return "Unexpected response: \(msg)"
        }
    }
}

// MARK: - Entry point

let args = CommandLine.arguments
var input: String?
var output: String?
var serverUri = "ws://localhost:8080"
var streamId: String?

var idx = 1
while idx < args.count {
    switch args[idx] {
    case "--input", "-i":
        if idx + 1 < args.count { idx += 1; input = args[idx] }
    case "--output", "-o":
        if idx + 1 < args.count { idx += 1; output = args[idx] }
    case "--server", "-s":
        if idx + 1 < args.count { idx += 1; serverUri = args[idx] }
    case "--stream-id":
        if idx + 1 < args.count { idx += 1; streamId = args[idx] }
    default: break
    }
    idx += 1
}

guard let inputPath = input else {
    print("Usage: audio_stream_client --input FILE [--output FILE] [--server URI]")
    exit(1)
}
guard FileManager.default.fileExists(atPath: inputPath) else {
    print("Input file not found: \(inputPath)")
    exit(1)
}

if output == nil {
    let df = DateFormatter()
    df.dateFormat = "yyyyMMdd-HHmmss"
    let ts = df.string(from: Date())
    let filename = URL(fileURLWithPath: inputPath).lastPathComponent
    output = "audio/output/output-\(ts)-\(filename)"
}
if streamId == nil {
    streamId = "stream-\(Int(Date().timeIntervalSince1970 * 1000))"
}

let client = Client(serverUri: serverUri)
let state = (hasError: false, finished: false)
var errorFlag = false

Task {
    do {
        try await client.run(input: inputPath, output: output!, streamId: streamId!)
    } catch {
        print("Error: \(error)")
        errorFlag = true
    }
    exit(errorFlag ? 1 : 0)
}

RunLoop.current.run()

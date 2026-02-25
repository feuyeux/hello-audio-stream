#include "client/client.h"
#include "server/protocol.h"
#include "server/message.h"
#include <chrono>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <nlohmann/json.hpp>
#include <sstream>
#include <thread>

namespace audio_stream
{

    // ── lifecycle ───────────────────────────────────────────────────────

    Client::Client(const std::string &uri) : uri_(uri)
    {
        ws_.clear_access_channels(websocketpp::log::alevel::all);
        ws_.clear_error_channels(websocketpp::log::elevel::all);
        ws_.init_asio();

        ws_.set_open_handler([this](ConnHdl)
                             { connected_ = true; });
        ws_.set_close_handler([this](ConnHdl)
                              { connected_ = false; });
        ws_.set_fail_handler([this](ConnHdl)
                             { connected_ = false; });

        ws_.set_message_handler([this](ConnHdl, WsClient::message_ptr msg)
                                {
        if (msg->get_opcode() == websocketpp::frame::opcode::text) {
            { std::lock_guard<std::mutex> lk(textMu_); textQ_.push(msg->get_payload()); }
            textCv_.notify_one();
        } else if (msg->get_opcode() == websocketpp::frame::opcode::binary) {
            const auto& p = msg->get_payload();
            { std::lock_guard<std::mutex> lk(binMu_); binQ_.push({p.begin(), p.end()}); }
            binCv_.notify_one();
        } });
    }

    Client::~Client() { disconnect(); }

    bool Client::connect()
    {
        websocketpp::lib::error_code ec;
        auto con = ws_.get_connection(uri_, ec);
        if (ec)
        {
            std::cerr << "[Client] Connection error: " << ec.message() << "\n";
            return false;
        }

        conn_ = con->get_handle();
        ws_.connect(con);
        ioThread_ = std::thread([this]
                                { ws_.run(); });

        // Wait for CONNECTED
        auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
        while (!connected_ && std::chrono::steady_clock::now() < deadline)
        {
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
        if (!connected_)
        {
            std::cerr << "[Client] Connect timeout\n";
            return false;
        }

        // Consume the CONNECTED message
        auto resp = sendAndWait("", 3000); // just wait, don't send
        (void)resp;
        std::cout << "[Client] Connected to " << uri_ << "\n";
        return true;
    }

    void Client::disconnect()
    {
        if (connected_)
        {
            websocketpp::lib::error_code ec;
            ws_.close(conn_, websocketpp::close::status::normal, "bye", ec);
            connected_ = false;
        }
        ws_.stop();
        if (ioThread_.joinable())
            ioThread_.join();
    }

    // ── upload ──────────────────────────────────────────────────────────

    std::string Client::upload(const std::string &filePath, const std::string &streamId)
    {
        std::cout << "[Client] Uploading " << filePath << " as " << streamId << "\n";

        // CREATE
        nlohmann::json createCmd = {{"command", "CREATE"}, {"streamId", streamId}};
        auto resp = sendAndWait(createCmd.dump());
        auto j = nlohmann::json::parse(resp);
        if (j.value("command", "") != "CREATED")
        {
            std::cerr << "[Client] CREATE failed: " << resp << "\n";
            return "";
        }

        // Send binary chunks
        std::ifstream in(filePath, std::ios::binary);
        if (!in)
        {
            std::cerr << "[Client] Cannot open: " << filePath << "\n";
            return "";
        }

        std::vector<uint8_t> buf(CHUNK_SIZE);
        size_t totalSent = 0;
        while (in)
        {
            in.read(reinterpret_cast<char *>(buf.data()), CHUNK_SIZE);
            auto n = static_cast<size_t>(in.gcount());
            if (n == 0)
                break;
            websocketpp::lib::error_code ec;
            ws_.send(conn_, buf.data(), n, websocketpp::frame::opcode::binary, ec);
            if (ec)
            {
                std::cerr << "[Client] Send binary error: " << ec.message() << "\n";
                return "";
            }
            totalSent += n;
        }
        in.close();
        std::cout << "[Client] Sent " << totalSent << " bytes\n";

        // COMPLETE
        nlohmann::json completeCmd = {{"command", "COMPLETE"}};
        resp = sendAndWait(completeCmd.dump());
        j = nlohmann::json::parse(resp);
        if (j.value("command", "") != "COMPLETED")
        {
            std::cerr << "[Client] COMPLETE failed: " << resp << "\n";
            return "";
        }
        std::cout << "[Client] Upload completed: " << streamId << "\n";
        return streamId;
    }

    // ── download ────────────────────────────────────────────────────────

    bool Client::download(const std::string &streamId, const std::string &outputPath)
    {
        std::cout << "[Client] Downloading " << streamId << " -> " << outputPath << "\n";

        // GET_STATUS to know size
        nlohmann::json statusCmd = {{"command", "GET_STATUS"}, {"streamId", streamId}};
        auto resp = sendAndWait(statusCmd.dump());
        auto j = nlohmann::json::parse(resp);
        if (j.value("command", "") != "STATUS")
        {
            std::cerr << "[Client] GET_STATUS failed: " << resp << "\n";
            return false;
        }
        int64_t totalSize = j.value("size", static_cast<int64_t>(0));
        std::cout << "[Client] Stream size: " << totalSize << " bytes\n";

        // Create output directory
        std::filesystem::path outPath(outputPath);
        if (outPath.has_parent_path())
            std::filesystem::create_directories(outPath.parent_path());

        std::ofstream out(outputPath, std::ios::binary | std::ios::trunc);
        if (!out)
        {
            std::cerr << "[Client] Cannot open output: " << outputPath << "\n";
            return false;
        }

        int64_t offset = 0;
        while (offset < totalSize)
        {
            int64_t len = std::min(static_cast<int64_t>(CHUNK_SIZE), totalSize - offset);
            nlohmann::json readCmd = {{"command", "READ"}, {"streamId", streamId}, {"offset", offset}, {"length", len}};
            ws_.send(conn_, readCmd.dump(), websocketpp::frame::opcode::text);

            auto data = waitBinary(10000);
            if (data.empty())
            {
                std::cerr << "[Client] No data at offset " << offset << "\n";
                out.close();
                return false;
            }
            out.write(reinterpret_cast<const char *>(data.data()), data.size());
            offset += static_cast<int64_t>(data.size());
        }
        out.close();

        std::cout << "[Client] Downloaded " << offset << " bytes\n";
        return true;
    }

    // ── helpers ─────────────────────────────────────────────────────────

    std::string Client::sendAndWait(const std::string &json, int timeoutMs)
    {
        if (!json.empty())
        {
            websocketpp::lib::error_code ec;
            ws_.send(conn_, json, websocketpp::frame::opcode::text, ec);
            if (ec)
                return "";
        }

        std::unique_lock<std::mutex> lk(textMu_);
        if (textCv_.wait_for(lk, std::chrono::milliseconds(timeoutMs),
                             [this]
                             { return !textQ_.empty(); }))
        {
            auto msg = textQ_.front();
            textQ_.pop();
            return msg;
        }
        return "";
    }

    std::vector<uint8_t> Client::waitBinary(int timeoutMs)
    {
        std::unique_lock<std::mutex> lk(binMu_);
        if (binCv_.wait_for(lk, std::chrono::milliseconds(timeoutMs),
                            [this]
                            { return !binQ_.empty(); }))
        {
            auto data = std::move(binQ_.front());
            binQ_.pop();
            return data;
        }
        return {};
    }

    std::string Client::md5File(const std::string &filePath)
    {
        std::ifstream in(filePath, std::ios::binary);
        if (!in)
            return "";

        websocketpp::md5::md5_state_t state;
        websocketpp::md5::md5_init(&state);

        char buf[8192];
        while (in.read(buf, sizeof(buf)) || in.gcount() > 0)
        {
            websocketpp::md5::md5_append(&state,
                                         reinterpret_cast<const websocketpp::md5::md5_byte_t *>(buf),
                                         static_cast<int>(in.gcount()));
            if (in.gcount() < static_cast<std::streamsize>(sizeof(buf)))
                break;
        }

        websocketpp::md5::md5_byte_t hash[16];
        websocketpp::md5::md5_finish(&state, hash);

        std::ostringstream oss;
        for (int i = 0; i < 16; ++i)
            oss << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(hash[i]);
        return oss.str();
    }

} // namespace audio_stream

// ── main ────────────────────────────────────────────────────────────

int main(int argc, char *argv[])
{
    std::string serverUri = "ws://localhost:8080";
    std::string inputFile;
    std::string outputFile;

    for (int i = 1; i < argc; ++i)
    {
        std::string arg = argv[i];
        if ((arg == "--server" || arg == "-s") && i + 1 < argc)
            serverUri = argv[++i];
        else if ((arg == "--input" || arg == "-i") && i + 1 < argc)
            inputFile = argv[++i];
        else if ((arg == "--output" || arg == "-o") && i + 1 < argc)
            outputFile = argv[++i];
    }

    if (inputFile.empty())
    {
        std::cerr << "Usage: audio_stream_client --server <uri> --input <file> [--output <file>]\n";
        return 1;
    }

    // Derive output if not specified
    if (outputFile.empty())
    {
        std::filesystem::path p(inputFile);
        outputFile = "audio/output/" + p.filename().string();
    }

    // Generate stream ID from filename
    std::filesystem::path inPath(inputFile);
    std::string streamId = inPath.stem().string();

    std::cout << "Audio Stream Client (C++)\n"
              << "  Server: " << serverUri << "\n"
              << "  Input:  " << inputFile << "\n"
              << "  Output: " << outputFile << "\n\n";

    audio_stream::Client client(serverUri);

    if (!client.connect())
    {
        std::cerr << "Failed to connect\n";
        return 1;
    }

    auto sid = client.upload(inputFile, streamId);
    if (sid.empty())
    {
        std::cerr << "Upload failed\n";
        return 1;
    }

    // Small delay for server processing
    std::this_thread::sleep_for(std::chrono::milliseconds(500));

    if (!client.download(sid, outputFile))
    {
        std::cerr << "Download failed\n";
        return 1;
    }

    // Verify
    auto md5In = audio_stream::Client::md5File(inputFile);
    auto md5Out = audio_stream::Client::md5File(outputFile);
    std::cout << "\n=== Verification ===\n"
              << "  Input  MD5: " << md5In << "\n"
              << "  Output MD5: " << md5Out << "\n"
              << "  Match: " << (md5In == md5Out ? "YES" : "NO") << "\n";

    client.disconnect();
    return (md5In == md5Out) ? 0 : 1;
}

#ifndef AUDIO_STREAM_CLIENT_H
#define AUDIO_STREAM_CLIENT_H

#include <atomic>
#include <condition_variable>
#include <functional>
#include <mutex>
#include <queue>
#include <string>
#include <thread>
#include <vector>

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <winsock2.h>
#endif

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wnull-pointer-subtraction"
#include <websocketpp/config/asio_no_tls.hpp>
#include <websocketpp/client.hpp>
#pragma GCC diagnostic pop

#include <websocketpp/common/md5.hpp>

namespace audio_stream
{

    using WsClient = websocketpp::client<websocketpp::config::asio>;
    using ConnHdl = websocketpp::connection_hdl;

    class Client
    {
    public:
        explicit Client(const std::string &uri);
        ~Client();

        bool connect();
        void disconnect();

        /// Upload a file, returning the streamId assigned by the caller.
        std::string upload(const std::string &filePath, const std::string &streamId);

        /// Download a stream to outputPath. Returns true on success.
        bool download(const std::string &streamId, const std::string &outputPath);

        /// Compute MD5 of a file (hex string).
        static std::string md5File(const std::string &filePath);

    private:
        std::string sendAndWait(const std::string &json, int timeoutMs = 5000);
        std::vector<uint8_t> waitBinary(int timeoutMs = 5000);

        std::string uri_;
        WsClient ws_;
        ConnHdl conn_;
        std::atomic<bool> connected_{false};
        std::thread ioThread_;

        // text message queue
        std::queue<std::string> textQ_;
        std::mutex textMu_;
        std::condition_variable textCv_;

        // binary message queue
        std::queue<std::vector<uint8_t>> binQ_;
        std::mutex binMu_;
        std::condition_variable binCv_;
    };

} // namespace audio_stream

#endif // AUDIO_STREAM_CLIENT_H

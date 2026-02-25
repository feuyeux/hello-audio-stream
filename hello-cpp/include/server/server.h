#ifndef AUDIO_STREAM_SERVER_H
#define AUDIO_STREAM_SERVER_H

#include "handler.h"
#include "stream_manager.h"
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <thread>

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <winsock2.h>
#ifdef ERROR
#undef ERROR
#endif
#endif

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wnull-pointer-subtraction"
#include <websocketpp/config/asio_no_tls.hpp>
#include <websocketpp/server.hpp>
#pragma GCC diagnostic pop

namespace audio_stream
{

    using WsServer = websocketpp::server<websocketpp::config::asio>;
    using ConnHdl = websocketpp::connection_hdl;

    class Server
    {
    public:
        Server(int port, const StreamManagerConfig &cfg);
        ~Server();

        void start(); // blocks
        void stop();

    private:
        void onOpen(ConnHdl hdl);
        void onClose(ConnHdl hdl);

        template <typename MsgPtr>
        void onMessage(ConnHdl hdl, MsgPtr msg);

        void sendText(ConnHdl hdl, const std::string &text);
        void sendBinary(ConnHdl hdl, const std::vector<uint8_t> &data);

        int port_;
        WsServer ws_;
        std::shared_ptr<StreamManager> sm_;

        std::map<ConnHdl, std::shared_ptr<Handler>, std::owner_less<ConnHdl>> handlers_;
        std::mutex mu_;
        int connSeq_ = 0;

        bool running_ = false;
        std::thread cleanupThread_;
    };

} // namespace audio_stream

#endif // AUDIO_STREAM_SERVER_H

#include "server/server.h"
#include "server/message.h"
#include <chrono>
#include <csignal>
#include <iostream>

namespace audio_stream
{

    Server::Server(int port, const StreamManagerConfig &cfg) : port_(port)
    {
        sm_ = std::make_shared<StreamManager>(cfg);

        ws_.clear_access_channels(websocketpp::log::alevel::all);
        ws_.clear_error_channels(websocketpp::log::elevel::all);
        ws_.init_asio();
        ws_.set_reuse_addr(true);

        ws_.set_open_handler([this](ConnHdl h)
                             { onOpen(h); });
        ws_.set_close_handler([this](ConnHdl h)
                              { onClose(h); });
        ws_.set_message_handler([this](ConnHdl h, WsServer::message_ptr m)
                                { onMessage(h, m); });
    }

    Server::~Server() { stop(); }

    void Server::start()
    {
        ws_.listen(port_);
        ws_.start_accept();
        running_ = true;

        // Cleanup thread: every 30 seconds
        cleanupThread_ = std::thread([this]
                                     {
        while (running_) {
            std::this_thread::sleep_for(std::chrono::seconds(30));
            if (running_) sm_->cleanup();
        } });

        std::cout << "[Server] Listening on port " << port_
                  << " (streams=" << sm_->count() << ")\n";
        ws_.run(); // blocks
    }

    void Server::stop()
    {
        if (!running_)
            return;
        running_ = false;
        ws_.stop();
        if (cleanupThread_.joinable())
            cleanupThread_.join();
        std::cout << "[Server] Stopped\n";
    }

    void Server::onOpen(ConnHdl hdl)
    {
        std::lock_guard<std::mutex> lk(mu_);
        std::string connId = "c-" + std::to_string(++connSeq_);

        auto st = [this, hdl](const std::string &t)
        { sendText(hdl, t); };
        auto sb = [this, hdl](const std::vector<uint8_t> &d)
        { sendBinary(hdl, d); };
        auto h = std::make_shared<Handler>(connId, sm_, st, sb);
        handlers_[hdl] = h;

        sendText(hdl, Message::connected(connId).toJson());
        std::cout << "[Server] Client connected: " << connId << "\n";
    }

    void Server::onClose(ConnHdl hdl)
    {
        std::lock_guard<std::mutex> lk(mu_);
        auto it = handlers_.find(hdl);
        if (it != handlers_.end())
        {
            it->second->onDisconnect();
            std::cout << "[Server] Client disconnected: " << it->second->connId() << "\n";
            handlers_.erase(it);
        }
    }

    template <typename MsgPtr>
    void Server::onMessage(ConnHdl hdl, MsgPtr msg)
    {
        std::shared_ptr<Handler> h;
        {
            std::lock_guard<std::mutex> lk(mu_);
            auto it = handlers_.find(hdl);
            if (it == handlers_.end())
                return;
            h = it->second;
        }

        if (msg->get_opcode() == websocketpp::frame::opcode::text)
        {
            h->onText(msg->get_payload());
        }
        else if (msg->get_opcode() == websocketpp::frame::opcode::binary)
        {
            const auto &payload = msg->get_payload();
            std::vector<uint8_t> data(payload.begin(), payload.end());
            h->onBinary(data);
        }
    }

    void Server::sendText(ConnHdl hdl, const std::string &text)
    {
        try
        {
            ws_.send(hdl, text, websocketpp::frame::opcode::text);
        }
        catch (const std::exception &e)
        {
            std::cerr << "[Server] Send text error: " << e.what() << "\n";
        }
    }

    void Server::sendBinary(ConnHdl hdl, const std::vector<uint8_t> &data)
    {
        try
        {
            ws_.send(hdl, data.data(), data.size(), websocketpp::frame::opcode::binary);
        }
        catch (const std::exception &e)
        {
            std::cerr << "[Server] Send binary error: " << e.what() << "\n";
        }
    }

} // namespace audio_stream

// ── main ────────────────────────────────────────────────────────────

static audio_stream::Server *g_server = nullptr;

void signalHandler(int)
{
    if (g_server)
        g_server->stop();
}

int main(int argc, char *argv[])
{
    int port = audio_stream::DEFAULT_PORT;
    if (argc >= 2)
        port = std::atoi(argv[1]);

    std::cout << "Audio Stream Cache Server (C++)\n";

    std::signal(SIGINT, signalHandler);
    std::signal(SIGTERM, signalHandler);

    audio_stream::StreamManagerConfig cfg;
    audio_stream::Server server(port, cfg);
    g_server = &server;

    try
    {
        server.start();
    }
    catch (const std::exception &e)
    {
        std::cerr << "[Server] Fatal: " << e.what() << "\n";
        return 1;
    }
    return 0;
}

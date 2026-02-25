#ifndef AUDIO_STREAM_HANDLER_H
#define AUDIO_STREAM_HANDLER_H

#include "message.h"
#include "stream_manager.h"
#include <functional>
#include <memory>
#include <string>
#include <vector>

namespace audio_stream
{

    /// Per-connection handler. Holds connId and current streamId.
    class Handler
    {
    public:
        using SendText = std::function<void(const std::string &)>;
        using SendBinary = std::function<void(const std::vector<uint8_t> &)>;

        Handler(const std::string &connId, std::shared_ptr<StreamManager> sm,
                SendText sendText, SendBinary sendBinary);

        void onText(const std::string &json);
        void onBinary(const std::vector<uint8_t> &data);
        void onDisconnect();

        const std::string &connId() const { return connId_; }

    private:
        void handleStream(const CommandInfo &ci, const Message &msg);
        void handleData(const CommandInfo &ci, const Message &msg);
        void handleQuery(const CommandInfo &ci, const Message &msg);
        void sendError(const std::string &err);

        std::string connId_;
        std::string streamId_;
        std::shared_ptr<StreamManager> sm_;
        SendText sendText_;
        SendBinary sendBinary_;
    };

} // namespace audio_stream

#endif // AUDIO_STREAM_HANDLER_H

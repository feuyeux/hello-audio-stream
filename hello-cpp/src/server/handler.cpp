#include "server/handler.h"
#include <iostream>

namespace audio_stream
{

    Handler::Handler(const std::string &connId, std::shared_ptr<StreamManager> sm,
                     SendText sendText, SendBinary sendBinary)
        : connId_(connId), sm_(std::move(sm)),
          sendText_(std::move(sendText)), sendBinary_(std::move(sendBinary)) {}

    void Handler::onText(const std::string &json)
    {
        try
        {
            Message msg = Message::parse(json);
            auto [ci, m] = msg.parseCommand();

            switch (ci.type)
            {
            case CommandType::STREAM:
                handleStream(ci, m);
                break;
            case CommandType::DATA:
                handleData(ci, m);
                break;
            case CommandType::QUERY:
                handleQuery(ci, m);
                break;
            }
        }
        catch (const nlohmann::json::parse_error &)
        {
            sendError("Invalid JSON");
        }
        catch (const std::exception &e)
        {
            sendError(e.what());
        }
    }

    void Handler::onBinary(const std::vector<uint8_t> &data)
    {
        if (streamId_.empty())
        {
            sendError("No active stream for binary data");
            return;
        }
        if (!sm_->write(streamId_, data))
        {
            sendError("Failed to write data to stream: " + streamId_);
        }
    }

    void Handler::onDisconnect()
    {
        if (!streamId_.empty())
        {
            sm_->markError(streamId_);
            std::cout << "[Handler] Connection " << connId_
                      << " disconnected, marked stream " << streamId_ << " as ERROR\n";
            streamId_.clear();
        }
    }

    // ── command dispatch ────────────────────────────────────────────────

    void Handler::handleStream(const CommandInfo &ci, const Message &msg)
    {
        switch (static_cast<StreamCommand>(ci.ordinal))
        {
        case StreamCommand::CREATE:
        {
            if (msg.streamId.empty())
            {
                sendError("Missing streamId");
                return;
            }
            if (!sm_->create(msg.streamId))
            {
                sendError("Failed to create stream: " + msg.streamId);
                return;
            }
            streamId_ = msg.streamId;
            sendText_(Message::created(streamId_).toJson());
            break;
        }
        case StreamCommand::COMPLETE:
        {
            if (streamId_.empty())
            {
                sendError("No active stream");
                return;
            }
            if (!sm_->complete(streamId_))
            {
                sendError("Failed to complete stream: " + streamId_);
                return;
            }
            sendText_(Message::completed(streamId_).toJson());
            break;
        }
        case StreamCommand::CLOSE:
        {
            std::string sid = msg.streamId.empty() ? streamId_ : msg.streamId;
            if (sid.empty())
            {
                sendError("Missing streamId");
                return;
            }
            sm_->remove(sid);
            if (sid == streamId_)
                streamId_.clear();
            sendText_(Message::closed(sid).toJson());
            break;
        }
        }
    }

    void Handler::handleData(const CommandInfo & /*ci*/, const Message &msg)
    {
        // READ
        std::string sid = msg.streamId.empty() ? streamId_ : msg.streamId;
        if (sid.empty())
        {
            sendError("Missing streamId");
            return;
        }
        if (msg.offset < 0 || msg.length < 0)
        {
            sendError("Missing offset/length");
            return;
        }

        auto data = sm_->read(sid, static_cast<uint64_t>(msg.offset), static_cast<size_t>(msg.length));
        if (data.empty())
        {
            sendError("No data available");
        }
        else
        {
            sendBinary_(data);
        }
    }

    void Handler::handleQuery(const CommandInfo &ci, const Message &msg)
    {
        switch (static_cast<QueryCommand>(ci.ordinal))
        {
        case QueryCommand::GET_STATUS:
        {
            std::string sid = msg.streamId.empty() ? streamId_ : msg.streamId;
            if (sid.empty())
            {
                sendError("Missing streamId");
                return;
            }
            auto [st, sz] = sm_->statusOf(sid);
            if (st.empty())
            {
                sendError("Stream not found: " + sid);
                return;
            }
            sendText_(Message::statusOf(sid, st, sz).toJson());
            break;
        }
        case QueryCommand::LIST_STREAMS:
        {
            sendText_(Message::streamList(sm_->list()).toJson());
            break;
        }
        }
    }

    void Handler::sendError(const std::string &err)
    {
        sendText_(Message::error(err).toJson());
    }

} // namespace audio_stream

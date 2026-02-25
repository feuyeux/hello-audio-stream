package org.feuyeux.mmap;

import io.netty.buffer.ByteBuf;
import io.netty.buffer.Unpooled;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.SimpleChannelInboundHandler;
import io.netty.handler.codec.http.websocketx.BinaryWebSocketFrame;
import io.netty.handler.codec.http.websocketx.TextWebSocketFrame;
import io.netty.handler.codec.http.websocketx.WebSocketFrame;
import io.netty.handler.codec.http.websocketx.WebSocketServerProtocolHandler;

import java.util.concurrent.atomic.AtomicLong;

public class Handler extends SimpleChannelInboundHandler<WebSocketFrame> {
    private static final AtomicLong ID = new AtomicLong(0);
    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(Handler.class);

    private final StreamManager mgr;
    private String conn;
    private String streamId;

    public Handler(StreamManager mgr) {
        this.mgr = mgr;
    }

    @Override
    protected void channelRead0(ChannelHandlerContext ctx, WebSocketFrame frame) {
        try {
            if (frame instanceof TextWebSocketFrame t) {
                log.info("Text: {}", t.text());
                handleText(ctx, t.text());
            }
            else if (frame instanceof BinaryWebSocketFrame b) {
                log.info("Binary: {} bytes", b.content().readableBytes());
                handleBinary(ctx, b.content());
            }
        } catch (Exception e) {
            log.error("Error handling frame", e);
        }
    }

    private void handleText(ChannelHandlerContext ctx, String json) {
        try {
            var msg = Message.parse(json);
            var cmdInfo = msg.parseCommand();
            log.info("Command: {}, streamId: {}", msg.command(), msg.streamId());
            
            if (cmdInfo == null) { 
                sendErr(ctx, "Invalid command"); 
                return; 
            }

            switch (cmdInfo.type()) {
                case STREAM -> handleStreamCommand(ctx, msg, cmdInfo.asStreamCommand());
                case DATA -> handleDataCommand(ctx, msg, cmdInfo.asDataCommand());
                case QUERY -> handleQueryCommand(ctx, msg, cmdInfo.asQueryCommand());
            }
        } catch (Exception e) {
            log.error("Parse error", e);
            sendErr(ctx, "Parse error");
        }
    }

    private void handleStreamCommand(ChannelHandlerContext ctx, Message msg, 
                                     org.feuyeux.mmap.protocol.StreamCommand cmd) {
        switch (cmd) {
            case CREATE -> {
                String sid = msg.streamId() != null ? msg.streamId() : conn;
                if (mgr.create(sid)) {
                    streamId = sid;
                    send(ctx, Message.created(sid));
                } else {
                    sendErr(ctx, "Create failed");
                }
            }
            case COMPLETE -> {
                if (streamId == null) {
                    sendErr(ctx, "No stream"); 
                    return;
                }
                if (mgr.complete(streamId)) {
                    send(ctx, Message.completed(streamId));
                } else {
                    sendErr(ctx, "Complete failed");
                }
            }
            case CLOSE -> {
                String sid = msg.streamId() != null ? msg.streamId() : streamId;
                if (sid == null) {
                    sendErr(ctx, "No stream"); 
                    return;
                }
                mgr.delete(sid);
                send(ctx, Message.closed(sid));
                if (sid.equals(streamId)) {
                    streamId = null;
                }
            }
        }
    }

    private void handleDataCommand(ChannelHandlerContext ctx, Message msg, 
                                   org.feuyeux.mmap.protocol.DataCommand cmd) {
        if (cmd == org.feuyeux.mmap.protocol.DataCommand.READ) {
            if (msg.offset() == null || msg.length() == null) {
                sendErr(ctx, "Missing params"); 
                return;
            }
            String sid = msg.streamId() != null ? msg.streamId() : streamId;
            if (sid == null) {
                sendErr(ctx, "No stream"); 
                return;
            }
            var data = mgr.read(sid, msg.offset(), msg.length());
            if (data != null && data.length > 0) {
                ctx.writeAndFlush(new BinaryWebSocketFrame(Unpooled.wrappedBuffer(data)));
            } else {
                sendErr(ctx, "No data");
            }
        }
    }

    private void handleQueryCommand(ChannelHandlerContext ctx, Message msg, 
                                    org.feuyeux.mmap.protocol.QueryCommand cmd) {
        switch (cmd) {
            case GET_STATUS -> {
                String sid = msg.streamId() != null ? msg.streamId() : streamId;
                if (sid == null) {
                    sendErr(ctx, "No stream"); 
                    return;
                }
                var s = mgr.get(sid);
                if (s != null) {
                    send(ctx, Message.status(sid, s.status.name(), s.off));
                } else {
                    sendErr(ctx, "Stream not found");
                }
            }
            case LIST_STREAMS -> {
                var ids = mgr.list();
                send(ctx, Message.streamList(ids));
            }
        }
    }

    private void handleBinary(ChannelHandlerContext ctx, ByteBuf buf) {
        if (streamId == null) { sendErr(ctx, "No stream"); return; }
        byte[] data = new byte[buf.readableBytes()];
        buf.readBytes(data);
        mgr.write(streamId, data);
    }

    private void send(ChannelHandlerContext ctx, Message msg) {
        try { 
            ctx.writeAndFlush(new TextWebSocketFrame(msg.toJson()));
        }
        catch (Exception e) { log.error("Send error", e); }
    }

    private void sendErr(ChannelHandlerContext ctx, String err) {
        try { ctx.writeAndFlush(new TextWebSocketFrame(Message.error(err).toJson())); }
        catch (Exception e) { log.error("Send error", e); }
    }

    @Override
    public void channelActive(ChannelHandlerContext ctx) {
        conn = "c-" + ID.incrementAndGet();
        log.info("New connection: {}", conn);
        // Don't send CONNECTED here - wait for WebSocket handshake to complete
    }

    @Override
    public void userEventTriggered(ChannelHandlerContext ctx, Object evt) throws Exception {
        if (evt instanceof WebSocketServerProtocolHandler.HandshakeComplete) {
            log.info("WebSocket handshake complete for: {}", conn);
            send(ctx, Message.connected(conn));
        }
        super.userEventTriggered(ctx, evt);
    }

    @Override
    public void channelInactive(ChannelHandlerContext ctx) {
        log.info("Connection closed: {}", conn);
        // Clean up if stream is still uploading
        if (streamId != null) {
            var s = mgr.get(streamId);
            if (s != null && s.status == StreamManager.Stream.Status.UPLOADING) {
                log.warn("Connection closed during upload, marking stream as error: {}", streamId);
                // Mark as error but don't delete - let cleanup handle it
                s.status = StreamManager.Stream.Status.ERROR;
            }
        }
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable t) {
        log.error("Exception on {}", conn, t);
        ctx.close();
    }
}

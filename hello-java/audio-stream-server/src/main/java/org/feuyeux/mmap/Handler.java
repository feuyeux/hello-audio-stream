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
            var type = msg.typeEnum();
            log.info("Message type: {}, streamId: {}", type, msg.streamId());
            if (type == null) { sendErr(ctx, "Invalid type"); return; }

            switch (type) {
                case START -> {
                    String sid = msg.streamId() != null ? msg.streamId() : conn;
                    if (mgr.create(sid)) {
                        streamId = sid;
                        send(ctx, Message.started(sid));
                    } else {
                        sendErr(ctx, "Create failed");
                    }
                }
                case STOP -> {
                    send(ctx, Message.stopped(streamId));
                    // Don't clear streamId - client may download after upload on same connection
                }
                case GET -> {
                    if (msg.offset() == null || msg.length() == null) {
                        sendErr(ctx, "Missing params"); return;
                    }
                    // Use message's streamId if provided, otherwise use connection's current streamId
                    String sid = msg.streamId() != null ? msg.streamId() : streamId;
                    if (sid == null) {
                        sendErr(ctx, "No stream"); return;
                    }
                    var data = mgr.read(sid, msg.offset(), msg.length());
                    if (data != null && data.length > 0) {
                        ctx.writeAndFlush(new BinaryWebSocketFrame(Unpooled.wrappedBuffer(data)));
                    } else {
                        sendErr(ctx, "No data");
                    }
                }
            }
        } catch (Exception e) {
            log.error("Parse error", e);
            sendErr(ctx, "Parse error");
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
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable t) {
        log.error("Exception on {}", conn, t);
        ctx.close();
    }
}

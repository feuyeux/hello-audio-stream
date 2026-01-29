package org.feuyeux.mmap.audio.server.handler;

import com.fasterxml.jackson.core.JsonProcessingException;
import io.netty.buffer.ByteBuf;
import io.netty.buffer.Unpooled;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.SimpleChannelInboundHandler;
import io.netty.handler.codec.http.websocketx.BinaryWebSocketFrame;
import io.netty.handler.codec.http.websocketx.TextWebSocketFrame;
import io.netty.handler.codec.http.websocketx.WebSocketFrame;
import org.feuyeux.mmap.audio.server.memory.StreamManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.concurrent.atomic.AtomicLong;

/**
 * WebSocket message handler using legacy protocol.
 * 
 * Protocol:
 * - Text messages: {"type":"start|stop|get", "streamId":"xxx", ...}
 * - Binary frames: raw audio data
 */
public class WebSocketMessageHandler extends SimpleChannelInboundHandler<WebSocketFrame> {
    private static final Logger logger = LoggerFactory.getLogger(WebSocketMessageHandler.class);
    private static final AtomicLong connectionCounter = new AtomicLong(0);

    private final StreamManager streamManager;

    private String connectionId;
    private String streamId;

    public WebSocketMessageHandler(StreamManager streamManager) {
        this.streamManager = streamManager;
    }

    @Override
    protected void channelRead0(ChannelHandlerContext ctx, WebSocketFrame frame) {
        if (frame instanceof TextWebSocketFrame textFrame) {
            handleTextMessage(ctx, textFrame);
        } else if (frame instanceof BinaryWebSocketFrame binaryFrame) {
            handleBinaryMessage(ctx, binaryFrame);
        } else {
            logger.warn("Unsupported frame type: {}", frame.getClass().getName());
        }
    }

    private void handleTextMessage(ChannelHandlerContext ctx, TextWebSocketFrame frame) {
        String message = frame.text();
        logger.debug("Received text message: {}", message);

        try {
            WebSocketMessage msg = WebSocketMessage.fromJson(message);
            MessageType messageType = msg.getMessageTypeEnum();

            if (messageType == null) {
                sendErrorResponse(ctx, "Missing message type");
                return;
            }

            switch (messageType) {
                case START:
                    handleStartMessage(ctx, msg);
                    break;
                case STOP:
                    handleStopMessage(ctx, msg);
                    break;
                case GET:
                    handleGetMessage(ctx, msg);
                    break;
                default:
                    logger.warn("Unknown message type: {}", messageType);
                    sendErrorResponse(ctx, "Unknown message type: " + messageType);
            }
        } catch (JsonProcessingException e) {
            logger.error("Error parsing JSON message", e);
            sendErrorResponse(ctx, "Invalid JSON format: " + e.getMessage());
        } catch (Exception e) {
            logger.error("Error processing text message", e);
            sendErrorResponse(ctx, "Failed to process message: " + e.getMessage());
        }
    }

    private void handleStartMessage(ChannelHandlerContext ctx, WebSocketMessage msg) {
        String streamIdFromMessage = msg.getStreamId();
        if (streamIdFromMessage != null && !streamIdFromMessage.isEmpty()) {
            this.streamId = streamIdFromMessage;
        } else {
            logger.warn("Start message missing streamId, using connectionId as streamId");
            this.streamId = connectionId;
        }
        
        // Create stream in StreamManager
        if (streamManager.createStream(streamId)) {
            logger.info("Stream started with ID: {} for connection: {}", streamId, connectionId);
            sendResponse(ctx, WebSocketMessage.started(streamId, "Stream started"));
        } else {
            logger.error("Failed to create stream: {}", streamId);
            sendErrorResponse(ctx, "Failed to create stream");
        }
    }

    private void handleStopMessage(ChannelHandlerContext ctx, WebSocketMessage msg) {
        String streamIdFromMessage = msg.getStreamId();
        if (streamIdFromMessage != null && !streamIdFromMessage.isEmpty()) {
            this.streamId = streamIdFromMessage;
        }
        logger.info("Stream stopped: {} for connection: {}", streamId, connectionId);
        sendResponse(ctx, WebSocketMessage.stopped(streamId, "Stream stopped"));
        this.streamId = null;
    }

    private void handleGetMessage(ChannelHandlerContext ctx, WebSocketMessage msg) {
        String streamIdFromRequest = msg.getStreamId();
        try {
            if (streamIdFromRequest == null || streamIdFromRequest.isEmpty()) {
                sendErrorResponse(ctx, "Missing streamId in get request");
                return;
            }

            Long offset = msg.getOffset();
            Integer length = msg.getLength();

            if (offset == null || length == null) {
                sendErrorResponse(ctx, "Missing offset or length in get request");
                return;
            }

            byte[] data = streamManager.readChunk(streamIdFromRequest, offset, length);

            if (data != null && data.length > 0) {
                ctx.writeAndFlush(new BinaryWebSocketFrame(Unpooled.wrappedBuffer(data)));
                logger.debug("Sent {} bytes for stream: {} offset: {}", data.length, streamIdFromRequest, offset);
            } else {
                sendErrorResponse(ctx, "No data available at offset " + offset);
            }
        } catch (Exception e) {
            logger.error("Error processing get request for stream: {}", streamIdFromRequest, e);
            sendErrorResponse(ctx, "Failed to retrieve data: " + e.getMessage());
        }
    }

    private void handleBinaryMessage(ChannelHandlerContext ctx, BinaryWebSocketFrame frame) {
        if (streamId == null) {
            logger.warn("Received binary data without active stream for connection: {}", connectionId);
            sendErrorResponse(ctx, "No active stream. Send start message first.");
            return;
        }

        try {
            ByteBuf buf = frame.content();
            byte[] data = new byte[buf.readableBytes()];
            buf.readBytes(data);
            
            streamManager.writeChunk(streamId, data);
            
            logger.debug("Wrote {} bytes to stream: {}", data.length, streamId);
        } catch (Exception e) {
            logger.error("Error writing binary data for stream: {}", streamId, e);
            sendErrorResponse(ctx, "Failed to write data: " + e.getMessage());
        }
    }

    private void sendResponse(ChannelHandlerContext ctx, WebSocketMessage response) {
        try {
            ctx.writeAndFlush(new TextWebSocketFrame(response.toJson()));
        } catch (JsonProcessingException e) {
            logger.error("Error serializing response", e);
        }
    }

    private void sendErrorResponse(ChannelHandlerContext ctx, String errorMessage) {
        try {
            WebSocketMessage error = WebSocketMessage.error(errorMessage);
            ctx.writeAndFlush(new TextWebSocketFrame(error.toJson()));
        } catch (JsonProcessingException e) {
            logger.error("Error serializing error response", e);
        }
    }

    @Override
    public void channelActive(ChannelHandlerContext ctx) {
        connectionId = "conn-" + connectionCounter.incrementAndGet();
        logger.info("New connection established: {}", connectionId);
        
        // Send connection established message using POJO
        sendResponse(ctx, WebSocketMessage.connected(connectionId, "Connection established"));
        
        try {
            super.channelActive(ctx);
        } catch (Exception e) {
            logger.error("Error in channelActive for connection: {}", connectionId, e);
        }
    }

    @Override
    public void channelInactive(ChannelHandlerContext ctx) {
        if (connectionId != null) {
            logger.info("Connection closed: {}", connectionId);
        }
        
        try {
            super.channelInactive(ctx);
        } catch (Exception e) {
            logger.error("Error in channelInactive for connection: {}", connectionId, e);
        }
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) {
        logger.error("Exception in WebSocket handler for connection: {}", connectionId, cause);
        ctx.close();
    }
}

package org.feuyeux.mmap.audio.server.network;

import io.netty.bootstrap.ServerBootstrap;
import io.netty.channel.*;
import io.netty.channel.nio.NioIoHandler;
import io.netty.channel.socket.SocketChannel;
import io.netty.channel.socket.nio.NioServerSocketChannel;
import io.netty.handler.codec.http.HttpObjectAggregator;
import io.netty.handler.codec.http.HttpServerCodec;
import io.netty.handler.codec.http.websocketx.WebSocketServerProtocolHandler;
import io.netty.handler.logging.LogLevel;
import io.netty.handler.logging.LoggingHandler;
import io.netty.handler.stream.ChunkedWriteHandler;
import org.feuyeux.mmap.audio.server.handler.WebSocketMessageHandler;
import org.feuyeux.mmap.audio.server.memory.StreamManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class AudioWebSocketServer {
    private static final Logger logger = LoggerFactory.getLogger(AudioWebSocketServer.class);

    private final int port;
    private final String websocketPath;
    private final StreamManager streamManager;
    private EventLoopGroup bossGroup;
    private EventLoopGroup workerGroup;
    public Channel serverChannel;

    public AudioWebSocketServer(int port, StreamManager streamManager) {
        this.port = port;
        this.websocketPath = System.getProperty("server.websocket.path", "/audio");
        this.streamManager = streamManager;
    }

    public void start() throws InterruptedException {
        // Use Netty 4.2 API: MultiThreadIoEventLoopGroup with NioIoHandler for network I/O (platform threads)
        // Virtual threads are used in handlers for business logic
        bossGroup = new MultiThreadIoEventLoopGroup(1, NioIoHandler.newFactory());
        workerGroup = new MultiThreadIoEventLoopGroup(0, NioIoHandler.newFactory());
        try {
            ServerBootstrap bootstrap = new ServerBootstrap();
            bootstrap.group(bossGroup, workerGroup)
                    .channel(NioServerSocketChannel.class)
                    .handler(new LoggingHandler(LogLevel.INFO))
                    .childHandler(new ChannelInitializer<SocketChannel>() {
                        @Override
                        protected void initChannel(SocketChannel ch) {
                            ChannelPipeline pipeline = ch.pipeline();
                            pipeline.addLast(new HttpServerCodec());
                            pipeline.addLast(new HttpObjectAggregator(65536));
                            pipeline.addLast(new ChunkedWriteHandler());
                            pipeline.addLast(new WebSocketServerProtocolHandler(websocketPath));
                            pipeline.addLast(new WebSocketMessageHandler(streamManager));
                        }
                    })
                    .option(ChannelOption.SO_BACKLOG, 1024)
                    .option(ChannelOption.SO_REUSEADDR, true)
                    .childOption(ChannelOption.SO_KEEPALIVE, true)
                    .childOption(ChannelOption.TCP_NODELAY, true)
                    .childOption(ChannelOption.SO_RCVBUF, 64 * 1024)
                    .childOption(ChannelOption.SO_SNDBUF, 64 * 1024);
            ChannelFuture future = bootstrap.bind(port).sync();
            serverChannel = future.channel();
            logger.info("Audio WebSocket Server started on port {} with path {}", port, websocketPath);
        } catch (Exception e) {
            logger.error("Failed to start WebSocket server", e);
            shutdown();
            throw e;
        }
    }

    public void shutdown() {
        if (serverChannel != null) {
            serverChannel.close().syncUninterruptibly();
        }
        if (workerGroup != null) {
            workerGroup.shutdownGracefully();
        }
        if (bossGroup != null) {
            bossGroup.shutdownGracefully();
        }
        logger.info("Audio WebSocket Server stopped");
    }
}


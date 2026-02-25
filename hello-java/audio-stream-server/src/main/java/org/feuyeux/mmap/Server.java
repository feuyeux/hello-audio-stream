package org.feuyeux.mmap;

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

public class Server {
    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(Server.class);
    private static final int PORT = 8080;
    private static final String PATH = System.getProperty("ws.path", "/audio");

    private EventLoopGroup boss, worker;
    private Channel ch;

    public static void main(String[] args) {
        var mgr = new StreamManager();
        var srv = new Server();
        
        var scheduler = java.util.concurrent.Executors.newSingleThreadScheduledExecutor();
        scheduler.scheduleAtFixedRate(mgr::cleanup, 30, 30, java.util.concurrent.TimeUnit.SECONDS);

        Runtime.getRuntime().addShutdownHook(java.lang.Thread.ofVirtual().unstarted(() -> {
            srv.shutdown();
            for (var id : mgr.list()) mgr.delete(id);
        }));

        try {
            srv.start(mgr);
            srv.ch.closeFuture().sync();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    public void start(StreamManager mgr) throws InterruptedException {
        boss = new MultiThreadIoEventLoopGroup(1, NioIoHandler.newFactory());
        worker = new MultiThreadIoEventLoopGroup(0, NioIoHandler.newFactory());

        var b = new ServerBootstrap();
        b.group(boss, worker)
            .channel(NioServerSocketChannel.class)
            .handler(new LoggingHandler(LogLevel.INFO))
            .childHandler(new ChannelInitializer<SocketChannel>() {
                @Override
                protected void initChannel(SocketChannel ch) {
                    var p = ch.pipeline();
                    p.addLast(new HttpServerCodec());
                    p.addLast(new HttpObjectAggregator(65536));
                    p.addLast(new ChunkedWriteHandler());
                    p.addLast(new WebSocketServerProtocolHandler(PATH));
                    p.addLast(new Handler(mgr));
                }
            })
            .option(ChannelOption.SO_BACKLOG, 1024)
            .childOption(ChannelOption.SO_KEEPALIVE, true)
            .childOption(ChannelOption.TCP_NODELAY, true)
            .childOption(ChannelOption.SO_RCVBUF, 64 * 1024)
            .childOption(ChannelOption.SO_SNDBUF, 64 * 1024);

        ch = b.bind(PORT).sync().channel();
        log.info("Server started on port {}", PORT);
    }

    public void shutdown() {
        if (ch != null) ch.close().syncUninterruptibly();
        if (worker != null) worker.shutdownGracefully();
        if (boss != null) boss.shutdownGracefully();
    }
}

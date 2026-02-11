package org.feuyeux.mmap.audio.server;

import org.feuyeux.mmap.audio.server.memory.StreamManager;
import org.feuyeux.mmap.audio.server.network.AudioWebSocketServer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

public class AudioServer {
    private static final Logger logger = LoggerFactory.getLogger(AudioServer.class);
    private static final int port = 8080;

    private AudioWebSocketServer webSocketServer;
    private StreamManager streamManager;
    private ScheduledExecutorService statisticsScheduler;

    void main() {
        AudioServer app = new AudioServer();
        app.start();
    }

    public void start() {
        logger.info("Starting Audio Server Application...");
        logger.info("JDK Version: {}", System.getProperty("java.version"));
        streamManager = new StreamManager();
        try {
            webSocketServer = new AudioWebSocketServer(port, streamManager);
            webSocketServer.start();
            startStatisticsTimer();
            Runtime.getRuntime().addShutdownHook(Thread.ofVirtual().unstarted(this::shutdown));
            logger.info("Audio Server Application started successfully on port {}", port);
            logger.info("WebSocket endpoint: ws://localhost:{}", port);
            webSocketServer.serverChannel.closeFuture().sync();
        } catch (InterruptedException e) {
            logger.error("Application interrupted", e);
            Thread.currentThread().interrupt();
        } catch (Exception e) {
            logger.error("Failed to start application", e);
            System.exit(1);
        }
    }

    private void startStatisticsTimer() {
        statisticsScheduler = Executors.newSingleThreadScheduledExecutor(
                Thread.ofVirtual().factory()
        );
        statisticsScheduler.scheduleAtFixedRate(this::logStatistics, 30, 30, TimeUnit.SECONDS);
    }

    private void logStatistics() {
        logger.debug("=== Application Statistics ===");
        logger.debug("Stream Manager - Active Streams: {}", streamManager.listActiveStreams().size());

        logger.debug("JVM - Heap: {} MB / {} MB, Used: {} MB",
                Runtime.getRuntime().totalMemory() / (1024 * 1024),
                Runtime.getRuntime().maxMemory() / (1024 * 1024),
                (Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory()) / (1024 * 1024));
        logger.debug("============================");
    }

    public void shutdown() {
        logger.info("Shutting down Audio Server Application...");

        if (statisticsScheduler != null) {
            statisticsScheduler.shutdown();
        }

        if (webSocketServer != null) {
            webSocketServer.shutdown();
        }

        // Cleanup old streams before shutdown
        if (streamManager != null) {
            streamManager.cleanupOldStreams();
        }

        logger.info("Audio Server Application shutdown complete");
    }
}

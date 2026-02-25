package org.feuyeux.mmap.client;

import java.net.URI;
import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

public class Client {
    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(Client.class);
    private static final String DEFAULT_URI = "ws://localhost:8080/audio";
    private static final int CHUNK = 64 * 1024;

    private final BlockingQueue<byte[]> binQ = new LinkedBlockingQueue<>(100);
    private final BlockingQueue<String> txtQ = new LinkedBlockingQueue<>(100);
    private org.java_websocket.client.WebSocketClient ws;
    private volatile boolean connected;

    public static void main(String[] args) throws Exception {
        String input = null;
        for (int i = 0; i < args.length; i++) {
            if ("--input".equals(args[i]) && i + 1 < args.length) input = args[++i];
        }
        if (input == null) {
            log.error("Usage: --input <file>");
            System.exit(1);
        }

        var in = Path.of(input);
        var out = Path.of("audio/output/out-" + System.currentTimeMillis() + "-" + in.getFileName());
        Files.createDirectories(out.getParent());

        var client = new Client();
        if (!client.connect(DEFAULT_URI, 3)) {
            log.error("Connect failed");
            System.exit(1);
        }

        String streamId = "s-" + System.currentTimeMillis();
        log.info("=== Upload ===");
        client.upload(in, streamId);

        log.info("=== Download ===");
        client.download(streamId, out);

        log.info("=== Verify ===");
        if (check(in, out)) {
            log.info("SUCCESS");
            client.close();
            System.exit(0);
        } else {
            log.error("FAILED");
            client.close();
            System.exit(1);
        }
    }

    public boolean connect(String uri, int retries) {
        for (int i = 0; i < retries; i++) {
            try {
                var latch = new java.util.concurrent.CountDownLatch(1);
                ws = new org.java_websocket.client.WebSocketClient(java.net.URI.create(uri)) {
                    @Override public void onOpen(org.java_websocket.handshake.ServerHandshake h) { 
                        connected = true; 
                        latch.countDown();
                    }
                    @Override public void onMessage(String m) { 
                        txtQ.offer(m); 
                    }
                    @Override public void onMessage(ByteBuffer b) {
                        byte[] d = new byte[b.remaining()];
                        b.get(d);
                        binQ.offer(d);
                    }
                    @Override public void onClose(int c, String r, boolean rmt) { 
                        connected = false; 
                        log.debug("Connection closed: code={}, reason={}", c, r);
                    }
                    @Override public void onError(Exception e) { 
                        log.error("WebSocket error", e); 
                    }
                };
                ws.connect();
                if (latch.await(5, TimeUnit.SECONDS)) {
                    // Wait for CONNECTED message from server
                    var connectedMsg = txtQ.poll(3, TimeUnit.SECONDS);
                    if (connectedMsg != null && connectedMsg.contains("CONNECTED")) {
                        Thread.sleep(100);
                        return true;
                    }
                }
                ws.close();
                Thread.sleep(1000L * (i + 1));
            } catch (Exception e) {
                log.error("Connection attempt {} failed", i + 1, e);
            }
        }
        return false;
    }

    public void upload(Path file, String streamId) throws Exception {
        send(Message.create(streamId).toJson());
        
        // Wait for CREATED response
        var resp = txtQ.poll(5, TimeUnit.SECONDS);
        log.info("Server response: {}", resp);
        if (resp == null || !resp.contains("CREATED")) {
            throw new RuntimeException("Server not ready");
        }
        
        try (var ch = java.nio.channels.FileChannel.open(file, java.nio.file.StandardOpenOption.READ)) {
            var buf = ByteBuffer.allocate(CHUNK);
            long total = 0;
            while (ch.read(buf) != -1) {
                buf.flip();
                byte[] chunk = new byte[buf.remaining()];
                buf.get(chunk);
                ws.send(chunk);
                total += chunk.length;
                buf.clear();
            }
            log.info("Uploaded {} bytes", total);
        }

        Thread.sleep(100);
        send(Message.complete().toJson());
        
        // Wait for COMPLETED response
        resp = txtQ.poll(5, TimeUnit.SECONDS);
        log.info("Server response: {}", resp);
    }

    public void download(String streamId, Path output) throws Exception {
        long off = 0;
        
        // First READ should start from offset 0
        send(Message.read(0, CHUNK).toJson());
        
        try (var ch = java.nio.channels.FileChannel.open(output, 
            java.nio.file.StandardOpenOption.CREATE, 
            java.nio.file.StandardOpenOption.WRITE,
            java.nio.file.StandardOpenOption.TRUNCATE_EXISTING)) {
            
            while (true) {
                var data = binQ.poll(5, TimeUnit.SECONDS);
                if (data == null || data.length == 0) break;
                ch.write(ByteBuffer.wrap(data));
                off += data.length;
                log.debug("Downloaded {} bytes", off);
                if (data.length < CHUNK) break;
                
                // Request next chunk
                send(Message.read(off, CHUNK).toJson());
            }
            log.info("Download complete: {} bytes", off);
        }
    }

    private void send(String msg) {
        if (connected) ws.send(msg);
    }

    public void close() {
        if (ws != null) {
            try {
                ws.closeBlocking();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
    }

    private static boolean check(Path a, Path b) throws Exception {
        var hex = HexFormat.of();
        var md = MessageDigest.getInstance("MD5");
        md.update(Files.readAllBytes(a));
        var ha = md.digest();
        md.reset();
        md.update(Files.readAllBytes(b));
        var hb = md.digest();
        var hashA = hex.formatHex(ha);
        var hashB = hex.formatHex(hb);
        log.info("Input  MD5: {}", hashA);
        log.info("Output MD5: {}", hashB);
        return hashA.equals(hashB);
    }
}

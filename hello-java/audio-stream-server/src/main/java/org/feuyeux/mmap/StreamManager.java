package org.feuyeux.mmap;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.locks.ReentrantLock;

public class StreamManager {
    private final Config config;
    private final Map<String, Stream> streams = new ConcurrentHashMap<>();
    private final Map<String, ReentrantLock> locks = new ConcurrentHashMap<>();
    private final ReentrantLock regLock = new ReentrantLock();

    public record Config(
        String cacheDir,
        long maxIdleHours,
        long maxUploadingHours,
        long maxStreams
    ) {
        public static Config defaults() {
            return new Config(
                System.getProperty("cache.dir", "cache"),
                24, 1, 1000
            );
        }
    }

    public record Stats(
        int totalStreams,
        long uploadingStreams,
        long readyStreams,
        long errorStreams
    ) {}

    public static class Stream {
        public final String id;
        public final String path;
        public final MmapCache cache;
        public long off = 0;
        public final Instant created = Instant.now();
        private final java.util.concurrent.atomic.AtomicReference<Instant> lastAccess =
            new java.util.concurrent.atomic.AtomicReference<>(Instant.now());
        public Status status = Status.UPLOADING;

        public enum Status { UPLOADING, READY, ERROR }

        public Stream(String id, String path) throws IOException {
            this.id = id;
            this.path = path;
            this.cache = new MmapCache(path);
            this.cache.create(0);
        }

        public void write(byte[] data) throws IOException {
            var buf = ByteBuffer.wrap(data);
            int n = cache.write(off, buf);
            if (n > 0) off += n;
        }

        public byte[] read(long off, int len) throws IOException {
            var buf = cache.read(off, len);
            if (buf == null) return null;
            byte[] r = new byte[buf.remaining()];
            buf.get(r);
            return r;
        }

        public void touch() {
            lastAccess.set(Instant.now());
        }

        public Instant getLastAccess() {
            return lastAccess.get();
        }

        public void close() throws IOException {
            cache.close();
        }
    }

    public StreamManager() {
        this(Config.defaults());
    }

    public StreamManager(Config config) {
        this.config = config;
        try {
            var p = Paths.get(config.cacheDir);
            if (!Files.exists(p)) Files.createDirectories(p);
        } catch (IOException e) {
            throw new RuntimeException("Cannot init cache dir", e);
        }
    }

    public boolean create(String id) {
        regLock.lock();
        try {
            if (streams.containsKey(id)) return false;
            if (streams.size() >= config.maxStreams) return false;
            var s = new Stream(id, config.cacheDir + "/" + id + ".cache");
            locks.put(id, new ReentrantLock());
            streams.put(id, s);
            return true;
        } catch (Exception e) {
            return false;
        } finally {
            regLock.unlock();
        }
    }

    public Stream get(String id) {
        return streams.computeIfPresent(id, (k, s) -> {
            s.touch();
            return s;
        });
    }

    public boolean complete(String id) {
        var s = get(id);
        if (s == null || s.status != Stream.Status.UPLOADING) return false;
        var lock = locks.get(id);
        if (lock == null) return false;
        lock.lock();
        try {
            if (s.status == Stream.Status.UPLOADING) {
                s.status = Stream.Status.READY;
                return true;
            }
            return false;
        } finally {
            lock.unlock();
        }
    }

    public void write(String id, byte[] data) {
        var s = get(id);
        if (s == null || s.status != Stream.Status.UPLOADING) return;
        var lock = locks.get(id);
        if (lock == null) return;
        lock.lock();
        try {
            s.write(data);
        } catch (IOException e) {
            s.status = Stream.Status.ERROR;
        } finally {
            lock.unlock();
        }
    }

    public byte[] read(String id, long off, int len) {
        var s = get(id);
        if (s == null) return new byte[0];
        var lock = locks.get(id);
        if (lock == null) return new byte[0];
        lock.lock();
        try {
            return s.read(off, len);
        } catch (IOException e) {
            return new byte[0];
        } finally {
            lock.unlock();
        }
    }

    public void delete(String id) {
        regLock.lock();
        try {
            var s = streams.remove(id);
            if (s != null) {
                try { s.close(); } catch (IOException e) {}
                Files.deleteIfExists(Paths.get(s.path));
            }
            locks.remove(id);
        } catch (IOException e) {
            // ignore
        } finally {
            regLock.unlock();
        }
    }

    public List<String> list() {
        return List.copyOf(streams.keySet());
    }

    public void cleanup() {
        regLock.lock();
        try {
            var now = Instant.now();
            var toDelete = new java.util.ArrayList<String>();
            for (var e : streams.entrySet()) {
                var s = e.getValue();
                var idle = java.time.Duration.between(s.getLastAccess(), now);
                // Clean up streams idle for more than maxIdleHours, or uploading for more than maxUploadingHours
                if (idle.toHours() > config.maxIdleHours ||
                    (s.status == Stream.Status.UPLOADING && idle.toHours() > config.maxUploadingHours)) {
                    toDelete.add(e.getKey());
                }
            }
            for (var id : toDelete) {
                delete(id);
            }
        } finally {
            regLock.unlock();
        }
    }

    public Stats getStats() {
        var values = streams.values();
        return new Stats(
            values.size(),
            values.stream().filter(s -> s.status == Stream.Status.UPLOADING).count(),
            values.stream().filter(s -> s.status == Stream.Status.READY).count(),
            values.stream().filter(s -> s.status == Stream.Status.ERROR).count()
        );
    }
}

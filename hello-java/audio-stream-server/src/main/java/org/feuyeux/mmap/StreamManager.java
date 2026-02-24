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
    private final String cacheDir;
    private final Map<String, Stream> streams = new ConcurrentHashMap<>();
    private final Map<String, ReentrantLock> locks = new ConcurrentHashMap<>();
    private final ReentrantLock regLock = new ReentrantLock();

    public static class Stream {
        public final String id;
        public final String path;
        public final MmapCache cache;
        public long off = 0;
        public Instant created = Instant.now();
        public Instant lastAccess = Instant.now();
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

        public void close() throws IOException {
            cache.close();
        }
    }

    public StreamManager() {
        this(System.getProperty("cache.dir", "cache"));
    }

    public StreamManager(String cacheDir) {
        this.cacheDir = cacheDir;
        try {
            var p = Paths.get(cacheDir);
            if (!Files.exists(p)) Files.createDirectories(p);
        } catch (IOException e) {
            throw new RuntimeException("Cannot init cache dir", e);
        }
    }

    public boolean create(String id) {
        regLock.lock();
        try {
            if (streams.containsKey(id)) return false;
            var s = new Stream(id, cacheDir + "/" + id + ".cache");
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
        var s = streams.get(id);
        if (s != null) s.lastAccess = Instant.now();
        return s;
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
            for (var e : streams.entrySet()) {
                if (java.time.Duration.between(e.getValue().lastAccess, now).toHours() > 24) {
                    delete(e.getKey());
                }
            }
        } finally {
            regLock.unlock();
        }
    }
}

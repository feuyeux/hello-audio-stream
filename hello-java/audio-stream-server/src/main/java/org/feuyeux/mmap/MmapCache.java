package org.feuyeux.mmap;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.locks.ReadWriteLock;
import java.util.concurrent.locks.ReentrantReadWriteLock;

public class MmapCache implements AutoCloseable {
    private static final long SEGMENT = 1024L * 1024 * 1024;
    private static final long MAX_SIZE = 8L * 1024 * 1024 * 1024;

    private final String path;
    private final ReadWriteLock lock = new ReentrantReadWriteLock();
    private final Map<Long, MappedByteBuffer> segs = new ConcurrentHashMap<>();

    private FileChannel ch;
    private java.io.RandomAccessFile raf;
    private long size;
    private boolean active;

    public MmapCache(String path) {
        this.path = path;
    }

    public void create(long initSize) throws IOException {
        lock.writeLock().lock();
        try {
            if (initSize < 0 || initSize > MAX_SIZE) throw new IOException("Invalid size");
            Files.deleteIfExists(Paths.get(path));
            raf = new java.io.RandomAccessFile(path, "rw");
            ch = raf.getChannel();
            if (initSize > 0) {
                raf.setLength(initSize);
                size = initSize;
            }
            active = true;
        } finally {
            lock.writeLock().unlock();
        }
    }

    public void open() throws IOException {
        lock.writeLock().lock();
        try {
            var p = Paths.get(path);
            if (!Files.exists(p)) return;
            raf = new java.io.RandomAccessFile(p.toFile(), "rw");
            ch = raf.getChannel();
            size = raf.length();
            active = true;
        } finally {
            lock.writeLock().unlock();
        }
    }

    @Override
    public void close() {
        lock.writeLock().lock();
        try {
            if (!active) return;
            for (var s : segs.values()) s.force();
            segs.clear();
            if (ch != null) ch.close();
            if (raf != null) raf.close();
            active = false;
        } catch (IOException e) {
            throw new RuntimeException(e);
        } finally {
            lock.writeLock().unlock();
        }
    }

    public int write(long off, ByteBuffer data) throws IOException {
        lock.writeLock().lock();
        try {
            if (!active) create(off + data.remaining());
            long need = off + data.remaining();
            if (need > size) resize(need);

            int written = 0;
            long pos = off;
            while (data.hasRemaining()) {
                var seg = getSeg(pos);
                int offInSeg = (int) (pos % SEGMENT);
                int n = Math.min(data.remaining(), (int) SEGMENT - offInSeg);
                seg.position(offInSeg);
                seg.put(data.slice().limit(n));
                data.position(data.position() + n);
                pos += n;
                written += n;
            }
            return written;
        } finally {
            lock.writeLock().unlock();
        }
    }

    public ByteBuffer read(long off, int len) throws IOException {
        lock.readLock().lock();
        try {
            if (!active) {
                lock.readLock().unlock();
                lock.writeLock().lock();
                try { if (!active) open(); }
                finally { lock.writeLock().unlock(); }
                lock.readLock().lock();
            }
            if (off >= size) return null;

            int actual = (int) Math.min(len, size - off);
            ByteBuffer buf = ByteBuffer.allocate(actual);
            long pos = off;
            int r = 0;
            while (r < actual) {
                var seg = getSeg(pos);
                int offInSeg = (int) (pos % SEGMENT);
                int n = Math.min(actual - r, (int) SEGMENT - offInSeg);
                seg.position(offInSeg);
                seg.limit(offInSeg + n);
                buf.put(seg);
                seg.limit(seg.capacity());
                pos += n;
                r += n;
            }
            buf.flip();
            return buf;
        } finally {
            lock.readLock().unlock();
        }
    }

    private void resize(long newSize) throws IOException {
        if (newSize > MAX_SIZE) {
            throw new IOException("Size exceeds limit: " + newSize + " > " + MAX_SIZE);
        }
        for (var s : segs.values()) s.force();
        segs.clear();
        raf.setLength(newSize);
        size = newSize;
    }

    private MappedByteBuffer getSeg(long off) {
        long idx = off / SEGMENT;
        return segs.computeIfAbsent(idx, i -> {
            try {
                long segOff = i * SEGMENT;
                long segSize = Math.min(SEGMENT, size - segOff);
                if (segSize <= 0) segSize = SEGMENT;
                return ch.map(FileChannel.MapMode.READ_WRITE, segOff, segSize);
            } catch (IOException e) { throw new RuntimeException(e); }
        });
    }
}

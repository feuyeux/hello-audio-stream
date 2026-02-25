package server

import java.io.RandomAccessFile
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import java.nio.file.Files
import java.nio.file.Paths

/** File-backed memory-mapped cache for a single stream. */
class MmapCache(private val path: String) : AutoCloseable {

    companion object {
        private const val DEFAULT_PAGE_SIZE = 64L * 1024 * 1024  // 64 MB
        private const val MAX_CACHE_SIZE = 8L * 1024 * 1024 * 1024 // 8 GB
    }

    private var file: RandomAccessFile? = null
    private var channel: FileChannel? = null
    private var buffer: MappedByteBuffer? = null
    private var capacity: Long = 0

    fun create(initialSize: Long = 0) {
        val size = maxOf(initialSize, DEFAULT_PAGE_SIZE)
        val filePath = Paths.get(path)
        if (Files.exists(filePath)) Files.delete(filePath)
        RandomAccessFile(path, "rw").use { it.setLength(size) }
        open(size)
    }

    fun write(offset: Long, data: ByteArray) {
        val required = offset + data.size
        if (required > capacity) resize(required)
        buffer!!.position(offset.toInt())
        buffer!!.put(data)
    }

    fun read(offset: Long, length: Int): ByteArray {
        ensureOpen()
        val buf = ByteArray(length)
        buffer!!.position(offset.toInt())
        buffer!!.get(buf)
        return buf
    }

    fun finalize(finalSize: Long) {
        closeMapping()
        RandomAccessFile(path, "rw").use { it.setLength(finalSize) }
        open(finalSize)
        buffer!!.force()
    }

    override fun close() {
        closeMapping()
    }

    // ── Internal ────────────────────────────────────────────────────────

    private fun open(size: Long) {
        file = RandomAccessFile(path, "rw")
        channel = file!!.channel
        buffer = channel!!.map(FileChannel.MapMode.READ_WRITE, 0, size)
        capacity = size
    }

    private fun ensureOpen() {
        if (buffer != null) return
        if (!Files.exists(Paths.get(path))) throw java.io.FileNotFoundException("Cache file not found: $path")
        val size = java.io.File(path).length()
        open(size)
    }

    private fun closeMapping() {
        buffer = null
        channel?.close(); channel = null
        file?.close(); file = null
    }

    private fun resize(required: Long) {
        var newSize = capacity
        while (newSize < required) newSize = minOf(newSize * 2, MAX_CACHE_SIZE)
        if (newSize > MAX_CACHE_SIZE) throw IllegalStateException("Cache exceeds max size")
        closeMapping()
        RandomAccessFile(path, "rw").use { it.setLength(newSize) }
        open(newSize)
    }
}

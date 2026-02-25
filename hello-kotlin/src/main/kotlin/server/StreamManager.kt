package server

import java.io.File
import java.time.Duration
import java.time.Instant

/** Stream lifecycle status. */
enum class StreamStatus { UPLOADING, READY, ERROR }

/** Manages all active streams and their caches. */
class StreamManager(private val cacheDir: String = "audio/output") {

    companion object {
        const val MAX_STREAMS = 1000
        private val MAX_IDLE = Duration.ofHours(24)
        private val MAX_UPLOADING = Duration.ofHours(1)
    }

    private val streams = mutableMapOf<String, Stream>()
    private val lock = Any()

    init { File(cacheDir).mkdirs() }

    fun create(streamId: String) {
        synchronized(lock) {
            if (streams.size >= MAX_STREAMS) throw IllegalStateException("Max streams ($MAX_STREAMS) reached")
            if (streams.containsKey(streamId)) throw IllegalStateException("Stream already exists: $streamId")
            val cache = MmapCache("$cacheDir/$streamId.cache")
            cache.create()
            streams[streamId] = Stream(streamId, cache)
        }
    }

    fun write(streamId: String, data: ByteArray) {
        val s = getStream(streamId)
        synchronized(s.lock) {
            s.cache.write(s.offset, data)
            s.offset += data.size
            s.lastAccess = Instant.now()
        }
    }

    fun complete(streamId: String) {
        val s = getStream(streamId)
        synchronized(s.lock) {
            s.cache.finalize(s.offset)
            s.status = StreamStatus.READY
            s.lastAccess = Instant.now()
        }
    }

    fun read(streamId: String, offset: Long, length: Int): ByteArray {
        val s = getStream(streamId)
        synchronized(s.lock) {
            s.lastAccess = Instant.now()
            return s.cache.read(offset, length)
        }
    }

    fun delete(streamId: String) {
        synchronized(lock) {
            streams.remove(streamId)?.cache?.close()
        }
    }

    fun markError(streamId: String) {
        synchronized(lock) {
            streams[streamId]?.status = StreamStatus.ERROR
        }
    }

    fun statusOf(streamId: String): Pair<StreamStatus, Long> {
        val s = getStream(streamId)
        synchronized(s.lock) { return s.status to s.offset }
    }

    fun list(): List<String> = synchronized(lock) { streams.keys.toList() }

    fun cleanup(): Int {
        synchronized(lock) {
            val now = Instant.now()
            val toRemove = streams.filter { (_, s) ->
                val idle = Duration.between(s.lastAccess, now)
                idle > MAX_IDLE
                    || (s.status == StreamStatus.UPLOADING && idle > MAX_UPLOADING)
                    || s.status == StreamStatus.ERROR
            }.keys.toList()
            toRemove.forEach { streams.remove(it)?.cache?.close() }
            return toRemove.size
        }
    }

    data class Stats(val total: Int, val uploading: Int, val ready: Int, val error: Int)

    fun stats(): Stats {
        synchronized(lock) {
            var u = 0; var r = 0; var e = 0
            for (s in streams.values) {
                when (s.status) {
                    StreamStatus.UPLOADING -> u++
                    StreamStatus.READY -> r++
                    StreamStatus.ERROR -> e++
                }
            }
            return Stats(streams.size, u, r, e)
        }
    }

    // ── Internal ────────────────────────────────────────────────────────

    private fun getStream(streamId: String): Stream =
        synchronized(lock) { streams[streamId] ?: throw NoSuchElementException("Stream not found: $streamId") }

    class Stream(
        val id: String,
        val cache: MmapCache,
        var offset: Long = 0,
        val created: Instant = Instant.now(),
        var lastAccess: Instant = Instant.now(),
        var status: StreamStatus = StreamStatus.UPLOADING,
        val lock: Any = Any(),
    )
}

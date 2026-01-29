package client.util

import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import kotlin.random.Random

/**
 * Stream ID generation utilities
 */
object StreamIdGenerator {
    private val formatter = DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss")
    
    /**
     * Generate a unique stream ID
     */
    fun generate(): String {
        val timestamp = LocalDateTime.now().format(formatter)
        val random = Random.nextInt(0, 0xFFFFFF).toString(16).padStart(8, '0')
        return "stream-$timestamp-$random"
    }
}

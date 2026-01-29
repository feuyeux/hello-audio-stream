import kotlinx.serialization.Serializable
import kotlinx.serialization.SerialName

/**
 * WebSocket message types enum
 * All type values are uppercase as per protocol specification
 */
enum class MessageType(val value: String) {
    START("START"),
    STARTED("STARTED"),
    STOP("STOP"),
    STOPPED("STOPPED"),
    GET("GET"),
    ERROR("ERROR"),
    CONNECTED("CONNECTED");

    companion object {
        /**
         * Parse string to MessageType enum.
         * Case-insensitive comparison for backward compatibility.
         */
        fun fromString(value: String?): MessageType? {
            return entries.find { it.value.equals(value, ignoreCase = true) }
        }
    }
}

/**
 * Configuration for the audio client
 */
data class Config(
    val inputPath: String,
    val outputPath: String,
    val serverUri: String,
    val verbose: Boolean
)

/**
 * WebSocket message for communication
 */
@Serializable
data class WebSocketMessage(
    @SerialName("type") val type: String,
    @SerialName("streamId") val streamId: String? = null,
    @SerialName("offset") val offset: Long? = null,
    @SerialName("length") val length: Int? = null,
    @SerialName("message") val message: String? = null
)

/**
 * Verification result
 */
data class VerificationResult(
    val passed: Boolean,
    val originalSize: Long,
    val downloadedSize: Long,
    val originalChecksum: String,
    val downloadedChecksum: String
)

/**
 * Performance report
 */
data class PerformanceReport(
    val uploadDurationMs: Long,
    val uploadThroughputMbps: Double,
    val downloadDurationMs: Long,
    val downloadThroughputMbps: Double,
    val totalDurationMs: Long,
    val averageThroughputMbps: Double
)

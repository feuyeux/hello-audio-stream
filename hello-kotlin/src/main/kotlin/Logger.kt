import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Simple logging utility
 */
object Logger {
    private val formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSS")
    private var verboseEnabled = false
    
    fun setVerbose(enabled: Boolean) {
        verboseEnabled = enabled
    }
    
    fun debug(message: String) {
        if (verboseEnabled) {
            log("debug", message)
        }
    }
    
    fun info(message: String) {
        log("info", message)
    }
    
    fun warn(message: String) {
        log("warn", message)
    }
    
    fun error(message: String) {
        log("error", message)
    }
    
    private fun log(level: String, message: String) {
        val timestamp = LocalDateTime.now().format(formatter)
        println("[$timestamp] [$level] $message")
    }
}

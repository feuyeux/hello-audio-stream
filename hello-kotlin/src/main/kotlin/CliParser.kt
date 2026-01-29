import java.io.File
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Command-line argument parser
 */
object CliParser {
    fun parse(args: Array<String>): Config? {
        var inputPath: String? = null
        var outputPath: String? = null
        var serverUri = "ws://localhost:8080/audio"
        var verbose = false
        
        var i = 0
        while (i < args.size) {
            when (args[i]) {
                "--input" -> {
                    if (i + 1 < args.size) {
                        inputPath = args[++i]
                    } else {
                        Logger.error("--input requires a value")
                        return null
                    }
                }
                "--output" -> {
                    if (i + 1 < args.size) {
                        outputPath = args[++i]
                    } else {
                        Logger.error("--output requires a value")
                        return null
                    }
                }
                "--server" -> {
                    if (i + 1 < args.size) {
                        serverUri = args[++i]
                    } else {
                        Logger.error("--server requires a value")
                        return null
                    }
                }
                "--verbose" -> {
                    verbose = true
                }
                "--help" -> {
                    printHelp()
                    return null
                }
                else -> {
                    Logger.error("Unknown argument: ${args[i]}")
                    printHelp()
                    return null
                }
            }
            i++
        }
        
        if (inputPath == null) {
            Logger.error("--input is required")
            printHelp()
            return null
        }
        
        val inputFile = File(inputPath)
        if (!inputFile.exists()) {
            Logger.error("Input file does not exist: $inputPath")
            return null
        }
        
        if (!inputFile.isFile) {
            Logger.error("Input path is not a file: $inputPath")
            return null
        }
        
        if (outputPath == null) {
            val timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss"))
            val filename = inputFile.name
            outputPath = "audio/output/output-$timestamp-$filename"
        }
        
        Logger.setVerbose(verbose)
        
        return Config(
            inputPath = inputPath,
            outputPath = outputPath,
            serverUri = serverUri,
            verbose = verbose
        )
    }
    
    private fun printHelp() {
        println("""
            Audio Stream Client
            
            Usage: audio_stream_client [OPTIONS]
            
            Options:
              --input <path>      Path to input audio file (required)
              --output <path>     Path to output audio file (optional, default: audio/output/output-<timestamp>-<filename>)
              --server <uri>      WebSocket server URI (optional, default: ws://localhost:8080/audio)
              --verbose           Enable verbose logging (optional)
              --help              Display this help message
            
            Examples:
              audio_stream_client --input audio/input/test.mp3
              audio_stream_client --input audio/input/test.mp3 --output /tmp/output.mp3
              audio_stream_client --input audio/input/test.mp3 --server ws://192.168.1.100:8080/audio --verbose
        """.trimIndent())
    }
}

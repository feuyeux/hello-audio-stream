package client.core

import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.MessageDigest

/**
 * File I/O operations
 */
object FileManager {
    private const val CHUNK_SIZE = 65536 // 64KB
    
    fun readChunk(path: String, offset: Long, size: Int): ByteArray {
        FileInputStream(path).use { input ->
            input.skip(offset)
            val buffer = ByteArray(size)
            val bytesRead = input.read(buffer)
            return if (bytesRead < size) {
                buffer.copyOf(bytesRead)
            } else {
                buffer
            }
        }
    }
    
    fun writeChunk(path: String, data: ByteArray, append: Boolean = true) {
        val file = File(path)
        file.parentFile?.mkdirs()
        
        FileOutputStream(file, append).use { output ->
            output.write(data)
        }
    }
    
    fun computeSha256(path: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        FileInputStream(path).use { input ->
            val buffer = ByteArray(CHUNK_SIZE)
            var bytesRead: Int
            while (input.read(buffer).also { bytesRead = it } != -1) {
                digest.update(buffer, 0, bytesRead)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
    
    fun getFileSize(path: String): Long {
        return File(path).length()
    }
    
    fun deleteFile(path: String) {
        File(path).delete()
    }
}

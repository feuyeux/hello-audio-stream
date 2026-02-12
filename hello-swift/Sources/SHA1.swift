
import Foundation

/// Pure Swift implementation of SHA1
/// Note: SHA1 is cryptographically broken and should not be used for security.
/// We use it here only for WebSocket handshake compliance (RFC 6455).
public struct SHA1 {
    
    public static func hash(data: Data) -> Data {
        var context = SHA1Context()
        data.withUnsafeBytes { buffer in
            if let baseAddress = buffer.baseAddress {
                let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
                context.append(bytes: bytes, count: buffer.count)
            }
        }
        return context.finalize()
    }
    
    public static func hexString(from data: Data) -> String {
        return data.map { String(format: "%02x", $0) }.joined()
    }
    
    // Internal context
    private struct SHA1Context {
        // Initial hash values (RFC 3174)
        private var h: (UInt32, UInt32, UInt32, UInt32, UInt32) = (
            0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0
        )
        
        private var len: UInt64 = 0
        private var buffer = [UInt8]()
        
        mutating func append(bytes: UnsafePointer<UInt8>, count: Int) {
            len += UInt64(count) * 8
            for i in 0..<count {
                buffer.append(bytes[i])
                if buffer.count == 64 {
                    process()
                }
            }
        }
        
        mutating func finalize() -> Data {
            // Padding
            buffer.append(0x80)
            while buffer.count % 64 != 56 {
                buffer.append(0x00)
            }
            
            // Append length (big endian)
            buffer.append(UInt8((len >> 56) & 0xFF))
            buffer.append(UInt8((len >> 48) & 0xFF))
            buffer.append(UInt8((len >> 40) & 0xFF))
            buffer.append(UInt8((len >> 32) & 0xFF))
            buffer.append(UInt8((len >> 24) & 0xFF))
            buffer.append(UInt8((len >> 16) & 0xFF))
            buffer.append(UInt8((len >> 8) & 0xFF))
            buffer.append(UInt8(len & 0xFF))
            
            while buffer.count >= 64 {
                process()
            }
            
            var result = Data(count: 20)
            result.withUnsafeMutableBytes { ptr in
                let t = ptr.bindMemory(to: UInt32.self)
                t[0] = h.0.bigEndian
                t[1] = h.1.bigEndian
                t[2] = h.2.bigEndian
                t[3] = h.3.bigEndian
                t[4] = h.4.bigEndian
            }
            return result
        }
        
        private mutating func process() {
            guard buffer.count >= 64 else { return }
            var w = [UInt32](repeating: 0, count: 80)
            
            // Break chunk into sixteen 32-bit big-endian words w[i]
            for i in 0..<16 {
                let j = i * 4
                w[i] = UInt32(buffer[j]) << 24 |
                    UInt32(buffer[j + 1]) << 16 |
                    UInt32(buffer[j + 2]) << 8 |
                    UInt32(buffer[j + 3])
            }
            buffer.removeFirst(64)
            
            // Extend the sixteen 32-bit words into eighty 32-bit words
            for i in 16..<80 {
                let n = w[i-3] ^ w[i-8] ^ w[i-14] ^ w[i-16]
                w[i] = (n << 1) | (n >> 31)
            }
            
            var a = h.0
            var b = h.1
            var c = h.2
            var d = h.3
            var e = h.4
            
            for i in 0..<80 {
                var f: UInt32 = 0
                var k: UInt32 = 0
                
                if i < 20 {
                    f = (b & c) | ((~b) & d)
                    k = 0x5A827999
                } else if i < 40 {
                    f = b ^ c ^ d
                    k = 0x6ED9EBA1
                } else if i < 60 {
                    f = (b & c) | (b & d) | (c & d)
                    k = 0x8F1BBCDC
                } else {
                    f = b ^ c ^ d
                    k = 0xCA62C1D6
                }
                
                let temp = (a << 5) | (a >> 27)
                let temp2 = temp &+ f &+ e &+ k &+ w[i]
                e = d
                d = c
                c = (b << 30) | (b >> 2)
                b = a
                a = temp2
            }
            
            h.0 = h.0 &+ a
            h.1 = h.1 &+ b
            h.2 = h.2 &+ c
            h.3 = h.3 &+ d
            h.4 = h.4 &+ e
        }
    }
}

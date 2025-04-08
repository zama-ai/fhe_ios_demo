// Copyright © 2025 Zama. All rights reserved.

import Compression
import Foundation

struct CompressionHelper {
    static func compressLZFSE(_ data: Data) -> Data? {
        data.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) -> Data? in
            guard let srcBaseAddress = rawBuffer.baseAddress else { return nil }

            let dstBufferSize = 64 * 1024
            let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: dstBufferSize)

            defer { dstBuffer.deallocate() }

            let compressedSize = compression_encode_buffer(
                dstBuffer,
                dstBufferSize,
                srcBaseAddress.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                COMPRESSION_LZFSE
            )

            guard compressedSize != 0 else { return nil }

            return Data(bytes: dstBuffer, count: compressedSize)
        }
    }

    static func decompressLZFSE(_ data: Data) -> Data? {
        data.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) -> Data? in
            guard let srcBaseAddress = rawBuffer.baseAddress else { return nil }

            let dstBufferSize = 64 * 1024
            let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: dstBufferSize)

            defer { dstBuffer.deallocate() }

            let decompressedSize = compression_decode_buffer(
                dstBuffer,
                dstBufferSize,
                srcBaseAddress.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                COMPRESSION_LZFSE
            )

            guard decompressedSize != 0 else { return nil }

            return Data(bytes: dstBuffer, count: decompressedSize)
        }
    }
}

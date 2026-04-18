import Foundation
import Compression

enum CompressedJSON {
    static func load(resource: String, subdirectory: String? = nil, bundle: Bundle = .main) throws -> Data {
        guard let url = bundle.url(
            forResource: resource + ".json",
            withExtension: "zlib",
            subdirectory: subdirectory
        ) else {
            throw CompressedJSONError.missingResource(resource)
        }
        let compressed = try Data(contentsOf: url)
        return try decompress(compressed)
    }

    static func decode<T: Decodable>(_ type: T.Type, resource: String, subdirectory: String? = nil, bundle: Bundle = .main) throws -> T {
        let data = try load(resource: resource, subdirectory: subdirectory, bundle: bundle)
        return try JSONDecoder().decode(type, from: data)
    }

    private static func decompress(_ data: Data) throws -> Data {
        // Python zlib.compress produces RFC 1950 format:
        // 2-byte header + raw deflate + 4-byte Adler-32 checksum.
        // Apple's COMPRESSION_ZLIB expects raw deflate (RFC 1951), so strip the wrapper.
        guard data.count > 6 else { throw CompressedJSONError.decompressFailed }
        let deflatePayload = Data(data.dropFirst(2).dropLast(4))

        let pageSize = 65_536
        var result = Data()

        try deflatePayload.withUnsafeBytes { srcPtr in
            guard let src = srcPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw CompressedJSONError.decompressFailed
            }
            let stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
            defer { stream.deallocate() }

            var status = compression_stream_init(stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
            guard status == COMPRESSION_STATUS_OK else { throw CompressedJSONError.decompressFailed }
            defer { compression_stream_destroy(stream) }

            stream.pointee.src_ptr = src
            stream.pointee.src_size = deflatePayload.count

            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: pageSize)
            defer { buffer.deallocate() }

            repeat {
                stream.pointee.dst_ptr = buffer
                stream.pointee.dst_size = pageSize

                status = compression_stream_process(stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))

                let written = pageSize - stream.pointee.dst_size
                if written > 0 {
                    result.append(buffer, count: written)
                }
            } while status == COMPRESSION_STATUS_OK

            guard status == COMPRESSION_STATUS_END else {
                throw CompressedJSONError.decompressFailed
            }
        }

        return result
    }
}

enum CompressedJSONError: LocalizedError {
    case missingResource(String)
    case decompressFailed

    var errorDescription: String? {
        switch self {
        case .missingResource(let name): return "Missing compressed resource: \(name).json.zlib"
        case .decompressFailed: return "Failed to decompress zlib data"
        }
    }
}

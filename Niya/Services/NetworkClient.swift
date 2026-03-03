import Foundation

enum NetworkError: LocalizedError {
    case badStatus(Int)
    case decodingFailed(Error)
    case requestFailed(Error)

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "HTTP \(code)"
        case .decodingFailed(let error): return "Decoding failed: \(error.localizedDescription)"
        case .requestFailed(let error): return error.localizedDescription
        }
    }
}

struct NetworkClient: Sendable {
    static let shared = NetworkClient()

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
    }

    func fetch<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        let (data, _) = try await fetchRaw(from: url)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }

    func fetchRaw(from url: URL) async throws -> (Data, HTTPURLResponse) {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw NetworkError.requestFailed(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(URLError(.badServerResponse))
        }
        guard (200...299).contains(http.statusCode) else {
            throw NetworkError.badStatus(http.statusCode)
        }
        return (data, http)
    }

    func download(from url: URL) async throws -> URL {
        let (tempURL, response): (URL, URLResponse)
        do {
            (tempURL, response) = try await session.download(from: url)
        } catch {
            throw NetworkError.requestFailed(error)
        }
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw NetworkError.badStatus((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return tempURL
    }

    func download(from url: URL, onProgress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let delegate = DownloadDelegate(onProgress: onProgress)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        let delegateSession = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { delegateSession.finishTasksAndInvalidate() }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                delegate.continuation = continuation
                let task = delegateSession.downloadTask(with: url)
                delegate.task = task
                task.resume()
            }
        } onCancel: {
            delegate.task?.cancel()
        }
    }
}

final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let onProgress: ((Double) -> Void)?
    var continuation: CheckedContinuation<URL, Error>?
    var task: URLSessionDownloadTask?

    init(onProgress: ((Double) -> Void)?) {
        self.onProgress = onProgress
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let fraction: Double
        if totalBytesExpectedToWrite > 0 {
            fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        } else {
            // Server didn't send Content-Length; estimate based on typical surah size (~5MB)
            fraction = min(Double(totalBytesWritten) / 5_000_000, 0.95)
        }
        onProgress?(fraction)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let cont = continuation else { return }
        continuation = nil

        let tempDir = FileManager.default.temporaryDirectory
        let dest = tempDir.appendingPathComponent(UUID().uuidString + ".tmp")
        do {
            try FileManager.default.copyItem(at: location, to: dest)
            if let http = downloadTask.response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                try? FileManager.default.removeItem(at: dest)
                cont.resume(throwing: NetworkError.badStatus(http.statusCode))
            } else {
                cont.resume(returning: dest)
            }
        } catch {
            cont.resume(throwing: NetworkError.requestFailed(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let error, let cont = continuation else { return }
        continuation = nil
        cont.resume(throwing: NetworkError.requestFailed(error))
    }
}

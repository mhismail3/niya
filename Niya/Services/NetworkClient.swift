import Foundation
import os

enum NetworkError: LocalizedError {
    case badStatus(Int)
    case requestFailed(Error)

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "HTTP \(code)"
        case .requestFailed(let error): return error.localizedDescription
        }
    }
}

/// Recitation downloads with progress. (Everything else the app shows is bundled.)
struct NetworkClient: Sendable {
    static let shared = NetworkClient()

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
            delegate.cancel()
        }
    }
}

final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let onProgress: (@Sendable (Double) -> Void)?
    private let state = OSAllocatedUnfairLock(initialState: DelegateState())

    struct DelegateState {
        var continuation: CheckedContinuation<URL, Error>?
        var task: URLSessionDownloadTask?
        var cancellationRequested = false
        var lastReportedProgress = 0
    }

    var continuation: CheckedContinuation<URL, Error>? {
        get { state.withLock { $0.continuation } }
        set { state.withLock { $0.continuation = newValue } }
    }

    var task: URLSessionDownloadTask? {
        get { state.withLock { $0.task } }
        set {
            let cancel = state.withLock { state -> Bool in
                state.task = newValue
                return state.cancellationRequested
            }
            if cancel { newValue?.cancel() }
        }
    }

    func cancel() {
        let task = state.withLock { state -> URLSessionDownloadTask? in
            state.cancellationRequested = true
            return state.task
        }
        task?.cancel()
    }

    init(onProgress: (@Sendable (Double) -> Void)?) {
        self.onProgress = onProgress
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let fraction: Double
        if totalBytesExpectedToWrite > 0 {
            fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        } else {
            fraction = min(Double(totalBytesWritten) / 5_000_000, 0.95)
        }
        let percent = Int(fraction * 100)
        let shouldReport = state.withLock { state -> Bool in
            guard percent > state.lastReportedProgress else { return false }
            state.lastReportedProgress = percent
            return true
        }
        if shouldReport { onProgress?(fraction) }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let cont: CheckedContinuation<URL, Error>? = state.withLock {
            let c = $0.continuation
            $0.continuation = nil
            return c
        }
        guard let cont else { return }

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
        guard let error else { return }
        let cont: CheckedContinuation<URL, Error>? = state.withLock {
            let c = $0.continuation
            $0.continuation = nil
            return c
        }
        guard let cont else { return }
        cont.resume(throwing: NetworkError.requestFailed(error))
    }
}

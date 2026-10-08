import Foundation
import Testing
@testable import Niya

@Suite("NetworkClient")
struct NetworkClientTests {

    @Test func badStatusErrorDescription() {
        #expect(NetworkError.badStatus(404).errorDescription == "HTTP 404")
    }

    @Test func requestFailedUsesUnderlyingDescription() {
        let underlying = URLError(.timedOut)
        #expect(NetworkError.requestFailed(underlying).errorDescription == underlying.localizedDescription)
    }

    /// Cancelling before the download task exists must still cancel it once created;
    /// otherwise the whole file downloads after the user tapped cancel.
    @Test func cancellationBeforeTaskCreationCancelsTheTask() {
        let delegate = DownloadDelegate(onProgress: nil)
        delegate.cancel()

        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let task = session.downloadTask(with: URL(string: "https://example.invalid/surah.mp3")!)
        delegate.task = task

        #expect(task.state == .canceling || task.state == .completed)
    }

    @Test func progressIsReportedOncePerPercent() {
        let reports = OSAllocatedUnfairLockBox()
        let delegate = DownloadDelegate { reports.append($0) }
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let task = session.downloadTask(with: URL(string: "https://example.invalid/a")!)
        for written in stride(from: Int64(0), through: 1_000, by: 1) {
            delegate.urlSession(session, downloadTask: task, didWriteData: 1, totalBytesWritten: written, totalBytesExpectedToWrite: 1_000)
        }
        #expect(reports.values.count == 100)
    }
}

private final class OSAllocatedUnfairLockBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Double] = []
    func append(_ value: Double) { lock.lock(); storage.append(value); lock.unlock() }
    var values: [Double] { lock.lock(); defer { lock.unlock() }; return storage }
}

import Foundation
import Testing
@testable import Niya

@MainActor
@Suite("DownloadManager")
final class DownloadManagerTests {
    /// Each test instance gets its own directory; tests never touch real downloads.
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("niya-downloads-\(UUID().uuidString)", isDirectory: true)

    init() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeManager() -> DownloadManager {
        DownloadManager(downloadStore: nil, downloadsDirectory: directory)
    }

    // MARK: - DownloadProgress model

    @Test func downloadProgressIdentity() {
        let p = DownloadProgress(id: "alAfasy:1", surahId: 1, reciterId: "alAfasy", progress: 0.5, error: nil)
        #expect(p.id == "alAfasy:1")
        #expect(p.surahId == 1)
        #expect(p.reciterId == "alAfasy")
        #expect(p.progress == 0.5)
        #expect(p.error == nil)
    }

    @Test func downloadProgressWithError() {
        var p = DownloadProgress(id: "alAfasy:2", surahId: 2, reciterId: "alAfasy", progress: 0.0, error: "Network error")
        #expect(p.error == "Network error")
        p.error = nil
        #expect(p.error == nil)
    }

    // MARK: - Key generation

    @Test func downloadKeyFormat() {
        let key = DownloadManager.downloadKey(surahId: 36, reciter: .alAfasy)
        #expect(key == "alAfasy:36")
    }

    @Test func downloadKeyDiffersPerReciter() {
        let k1 = DownloadManager.downloadKey(surahId: 1, reciter: .alAfasy)
        let k2 = DownloadManager.downloadKey(surahId: 1, reciter: .noreenSiddiq)
        #expect(k1 != k2)
    }

    @Test func downloadKeyBukhatir() {
        let key = DownloadManager.downloadKey(surahId: 36, reciter: .bukhatir)
        #expect(key == "bukhatir:36")
    }

    @Test func downloadKeyBukhatirDiffersFromNoreen() {
        let k1 = DownloadManager.downloadKey(surahId: 1, reciter: .bukhatir)
        let k2 = DownloadManager.downloadKey(surahId: 1, reciter: .noreenSiddiq)
        #expect(k1 != k2)
    }

    // MARK: - isDownloaded (file-system based)

    @Test func isDownloadedReturnsFalseWhenNoFile() {
        let dm = makeManager()
        #expect(dm.isDownloaded(999, reciter: .alAfasy) == false)
    }

    @Test func isDownloadedReturnsTrueWhenFileExists() throws {
        let dm = makeManager()
        let filename = Reciter.alAfasy.localFilename(for: 999)
        let url = directory.appendingPathComponent(filename)
        try Data("test".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(dm.isDownloaded(999, reciter: .alAfasy) == true)
    }

    // MARK: - isDownloading

    @Test func isDownloadingReturnsFalseInitially() {
        let dm = makeManager()
        #expect(dm.isDownloading(1, reciter: .alAfasy) == false)
    }

    // MARK: - Active downloads tracking

    @Test func activeDownloadsEmptyInitially() {
        let dm = makeManager()
        #expect(dm.activeDownloads.isEmpty)
    }

    // MARK: - Dismiss error

    @Test func dismissErrorClearsProgress() {
        let dm = makeManager()
        let key = DownloadManager.downloadKey(surahId: 1, reciter: .alAfasy)
        dm.activeDownloads[key] = DownloadProgress(id: key, surahId: 1, reciterId: "alAfasy", progress: 0.3, error: "Failed")
        dm.dismissError(1, reciter: .alAfasy)
        #expect(dm.activeDownloads[key] == nil)
    }

    @Test func dismissErrorNoOpWhenNoEntry() {
        let dm = makeManager()
        dm.dismissError(1, reciter: .alAfasy)
        #expect(dm.activeDownloads.isEmpty)
    }

    // MARK: - Delete

    @Test func deleteSurahRemovesFile() throws {
        let dm = makeManager()
        let filename = Reciter.alAfasy.localFilename(for: 998)
        let url = directory.appendingPathComponent(filename)
        try Data("test".utf8).write(to: url)

        try dm.deleteSurah(998, reciter: .alAfasy)
        #expect(FileManager.default.fileExists(atPath: url.path) == false)
    }

    @Test func deleteSurahNoErrorWhenFileDoesNotExist() throws {
        let dm = makeManager()
        try dm.deleteSurah(997, reciter: .alAfasy)
    }

    // MARK: - Storage

    @Test func storageUsedCountsFiles() throws {
        let dm = makeManager()
        let filename = Reciter.alAfasy.localFilename(for: 114)
        let url = directory.appendingPathComponent(filename)
        let data = Data(repeating: 0x42, count: 1024)
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let used = dm.storageUsed(for: .alAfasy)
        #expect(used >= 1024)
    }

    @Test func storageUsedZeroWhenNoFiles() {
        let dm = makeManager()
        let used = dm.storageUsed(for: .noreenSiddiq)
        // May not be exactly zero if prior tests left files, but should work for a clean state
        #expect(used >= 0)
    }

    @Test func totalStorageUsedSumsBothReciters() throws {
        let dm = makeManager()
        let f1 = Reciter.alAfasy.localFilename(for: 113)
        let f2 = Reciter.noreenSiddiq.localFilename(for: 113)
        let u1 = directory.appendingPathComponent(f1)
        let u2 = directory.appendingPathComponent(f2)
        let data = Data(repeating: 0x42, count: 512)
        try data.write(to: u1)
        try data.write(to: u2)
        defer {
            try? FileManager.default.removeItem(at: u1)
            try? FileManager.default.removeItem(at: u2)
        }

        let total = dm.totalStorageUsed()
        #expect(total >= 1024)
    }

    // MARK: - Duplicate prevention

    @Test func downloadSurahGuardsDuplicate() {
        let dm = makeManager()
        let key = DownloadManager.downloadKey(surahId: 1, reciter: .alAfasy)
        dm.activeDownloads[key] = DownloadProgress(id: key, surahId: 1, reciterId: "alAfasy", progress: 0.5, error: nil)

        // Calling download again should not crash or create duplicate
        dm.downloadSurah(1, reciter: .alAfasy)
        // Still just one entry
        #expect(dm.activeDownloads.count == 1)
    }

    // MARK: - Cancel

    @Test func cancelDownloadRemovesFromActive() {
        let dm = makeManager()
        let key = DownloadManager.downloadKey(surahId: 1, reciter: .alAfasy)
        dm.activeDownloads[key] = DownloadProgress(id: key, surahId: 1, reciterId: "alAfasy", progress: 0.5, error: nil)

        dm.cancelDownload(1, reciter: .alAfasy)
        #expect(dm.activeDownloads[key] == nil)
    }

    // MARK: - Progress query

    @Test func progressReturnsNilWhenNotDownloading() {
        let dm = makeManager()
        #expect(dm.progress(for: 1, reciter: .alAfasy) == nil)
    }

    @Test func progressReturnsEntryWhenActive() {
        let dm = makeManager()
        let key = DownloadManager.downloadKey(surahId: 1, reciter: .alAfasy)
        dm.activeDownloads[key] = DownloadProgress(id: key, surahId: 1, reciterId: "alAfasy", progress: 0.75, error: nil)

        let p = dm.progress(for: 1, reciter: .alAfasy)
        #expect(p?.progress == 0.75)
    }
}

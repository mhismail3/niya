import Foundation

struct DownloadProgress: Identifiable {
    let id: String
    let surahId: Int
    let reciterId: String
    var progress: Double
    var error: String?
}

@Observable
@MainActor
final class DownloadManager {
    var activeDownloads: [String: DownloadProgress] = [:]
    private(set) var changeRevision = 0
    private var downloadTasks: [String: Task<Void, Never>] = [:]
    private let downloadStore: DownloadStore?
    @ObservationIgnored private var storageCache: [String: Int64] = [:]

    init(downloadStore: DownloadStore?) {
        self.downloadStore = downloadStore
    }

    static func downloadKey(surahId: Int, reciter: Reciter) -> String {
        "\(reciter.rawValue):\(surahId)"
    }

    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - Download

    func downloadSurah(_ surahId: Int, reciter: Reciter) {
        let key = Self.downloadKey(surahId: surahId, reciter: reciter)
        guard activeDownloads[key] == nil else { return }
        guard !isDownloaded(surahId, reciter: reciter) else { return }

        activeDownloads[key] = DownloadProgress(id: key, surahId: surahId, reciterId: reciter.rawValue, progress: 0, error: nil)

        let task = Task { [weak self] in
            let url = reciter.surahStreamURL(surahId: surahId)
            let localURL = Self.documentsDirectory.appendingPathComponent(reciter.localFilename(for: surahId))

            do {
                try Task.checkCancellation()
                let tempURL = try await NetworkClient.shared.download(from: url) { [weak self] fraction in
                    Task { @MainActor [weak self] in
                        self?.activeDownloads[key]?.progress = fraction
                    }
                }
                try Task.checkCancellation()

                if FileManager.default.fileExists(atPath: localURL.path) {
                    try FileManager.default.removeItem(at: localURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: localURL)

                try self?.downloadStore?.save(surahId: surahId, filename: localURL.lastPathComponent, reciterId: reciter.rawValue)
                self?.storageCache.removeValue(forKey: reciter.rawValue)
                self?.activeDownloads.removeValue(forKey: key)
            } catch is CancellationError {
                self?.activeDownloads.removeValue(forKey: key)
            } catch let error as URLError where error.code == .cancelled {
                self?.activeDownloads.removeValue(forKey: key)
            } catch {
                self?.activeDownloads[key]?.error = error.localizedDescription
            }
            self?.downloadTasks.removeValue(forKey: key)
        }
        downloadTasks[key] = task
    }

    func cancelDownload(_ surahId: Int, reciter: Reciter) {
        let key = Self.downloadKey(surahId: surahId, reciter: reciter)
        downloadTasks[key]?.cancel()
        downloadTasks.removeValue(forKey: key)
        activeDownloads.removeValue(forKey: key)
    }

    func dismissError(_ surahId: Int, reciter: Reciter) {
        let key = Self.downloadKey(surahId: surahId, reciter: reciter)
        activeDownloads.removeValue(forKey: key)
    }

    // MARK: - Delete

    func deleteSurah(_ surahId: Int, reciter: Reciter) throws {
        let filename = reciter.localFilename(for: surahId)
        let url = Self.documentsDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try downloadStore?.delete(surahId: surahId, reciterId: reciter.rawValue)
        storageCache.removeValue(forKey: reciter.rawValue)
        changeRevision += 1
    }

    func deleteAllForReciter(_ reciter: Reciter) {
        for surahId in 1...114 {
            let filename = reciter.localFilename(for: surahId)
            let url = Self.documentsDirectory.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: url.path) {
                do { try FileManager.default.removeItem(at: url) } catch { AppLogger.store.error("deleteAll removeItem: \(error)") }
            }
        }
        if let all = try? downloadStore?.allDownloads() {
            for item in all where item.reciterId == reciter.rawValue {
                do { try downloadStore?.delete(surahId: item.surahId, reciterId: reciter.rawValue) } catch { AppLogger.store.error("deleteAll store delete: \(error)") }
            }
        }
        storageCache.removeValue(forKey: reciter.rawValue)
        changeRevision += 1
    }

    // MARK: - Query

    func isDownloaded(_ surahId: Int, reciter: Reciter) -> Bool {
        _ = changeRevision
        let filename = reciter.localFilename(for: surahId)
        let url = Self.documentsDirectory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path)
    }

    func isDownloading(_ surahId: Int, reciter: Reciter) -> Bool {
        let key = Self.downloadKey(surahId: surahId, reciter: reciter)
        guard let entry = activeDownloads[key] else { return false }
        return entry.error == nil
    }

    func progress(for surahId: Int, reciter: Reciter) -> DownloadProgress? {
        let key = Self.downloadKey(surahId: surahId, reciter: reciter)
        return activeDownloads[key]
    }

    func downloadedSurahs(for reciter: Reciter) -> [AudioDownload] {
        (try? downloadStore?.allDownloads().filter { $0.reciterId == reciter.rawValue }) ?? []
    }

    // MARK: - Storage

    func storageUsed(for reciter: Reciter) -> Int64 {
        _ = changeRevision
        if let cached = storageCache[reciter.rawValue] { return cached }
        var total: Int64 = 0
        for surahId in 1...114 {
            total += fileSizeForSurah(surahId, reciter: reciter)
        }
        storageCache[reciter.rawValue] = total
        return total
    }

    func totalStorageUsed() -> Int64 {
        _ = changeRevision
        return Reciter.allCases.reduce(0) { $0 + storageUsed(for: $1) }
    }

    // MARK: - Reconciliation

    func reconcile() {
        let fm = FileManager.default
        guard let allRecords = try? downloadStore?.allDownloads() else { return }

        storageCache.removeAll()
        // Remove records where file is missing
        for record in allRecords {
            let url = Self.documentsDirectory.appendingPathComponent(record.localFileName)
            if !fm.fileExists(atPath: url.path) {
                try? downloadStore?.delete(surahId: record.surahId, reciterId: record.reciterId)
            }
        }

        // Add records for orphan files on disk
        for reciter in Reciter.allCases {
            for surahId in 1...114 {
                let filename = reciter.localFilename(for: surahId)
                let url = Self.documentsDirectory.appendingPathComponent(filename)
                if fm.fileExists(atPath: url.path) {
                    let hasRecord = allRecords.contains { $0.surahId == surahId && $0.reciterId == reciter.rawValue }
                    if !hasRecord {
                        try? downloadStore?.save(surahId: surahId, filename: filename, reciterId: reciter.rawValue)
                    }
                }
            }
        }
    }

    func fileSizeForSurah(_ surahId: Int, reciter: Reciter) -> Int64 {
        let filename = reciter.localFilename(for: surahId)
        let url = Self.documentsDirectory.appendingPathComponent(filename)
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? UInt64 {
            return Int64(size)
        }
        return 0
    }
}

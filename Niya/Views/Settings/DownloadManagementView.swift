import SwiftUI

struct DownloadManagementView: View {
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(QuranDataService.self) private var dataService
    @State private var deleteAllReciter: Reciter?

    var body: some View {
        List {
            storageSection
            activeDownloadsSection
            ForEach(Reciter.allCases) { reciter in
                reciterSection(reciter)
            }
            if !hasAnyContent {
                emptyState
            }
        }
        .navigationTitle("Manage Downloads")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete All Downloads?",
            isPresented: Binding(
                get: { deleteAllReciter != nil },
                set: { if !$0 { deleteAllReciter = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let reciter = deleteAllReciter {
                Button("Delete All \(reciter.shortName) Downloads", role: .destructive) {
                    downloadManager.deleteAllForReciter(reciter)
                    deleteAllReciter = nil
                }
            }
            Button("Cancel", role: .cancel) { deleteAllReciter = nil }
        } message: {
            Text("This will remove all downloaded audio files for this reciter. You can re-download them later.")
        }
    }

    private var hasAnyContent: Bool {
        let hasActive = !downloadManager.activeDownloads.isEmpty
        let hasDownloads = Reciter.allCases.contains { reciter in
            (1...114).contains { downloadManager.isDownloaded($0, reciter: reciter) }
        }
        return hasActive || hasDownloads
    }

    // MARK: - Storage Overview

    @ViewBuilder
    private var storageSection: some View {
        let total = downloadManager.totalStorageUsed()
        if total > 0 {
            Section("Storage") {
                LabeledContent("Total Space Used") {
                    Text(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))
                        .foregroundStyle(Color.niyaTeal)
                }
            }
        }
    }

    // MARK: - Active Downloads

    @ViewBuilder
    private var activeDownloadsSection: some View {
        let active = downloadManager.activeDownloads.values.sorted { $0.id < $1.id }
        if !active.isEmpty {
            Section("Active Downloads") {
                ForEach(active) { prog in
                    activeDownloadRow(prog)
                }
            }
        }
    }

    private func activeDownloadRow(_ prog: DownloadProgress) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                let surah = dataService.surahs.first { $0.id == prog.surahId }
                Text(surah?.transliteration ?? "Surah \(prog.surahId)")
                Spacer()
                if let reciter = Reciter(rawValue: prog.reciterId) {
                    Button {
                        downloadManager.cancelDownload(prog.surahId, reciter: reciter)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.niyaSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            if let errorMsg = prog.error {
                Text(errorMsg)
                    .font(.caption)
                    .foregroundStyle(.red)
                if let reciter = Reciter(rawValue: prog.reciterId) {
                    Button("Retry") {
                        downloadManager.dismissError(prog.surahId, reciter: reciter)
                        downloadManager.downloadSurah(prog.surahId, reciter: reciter)
                    }
                    .font(.caption)
                }
            } else {
                ProgressView(value: prog.progress)
                    .tint(Color.niyaGold)
            }
        }
    }

    // MARK: - Per-Reciter Section

    @ViewBuilder
    private func reciterSection(_ reciter: Reciter) -> some View {
        let downloadedIds = (1...114).filter { downloadManager.isDownloaded($0, reciter: reciter) }
        if !downloadedIds.isEmpty {
            Section {
                ForEach(downloadedIds, id: \.self) { surahId in
                    surahRow(surahId: surahId, reciter: reciter)
                }
                .onDelete { offsets in
                    for offset in offsets {
                        let surahId = downloadedIds[offset]
                        try? downloadManager.deleteSurah(surahId, reciter: reciter)
                    }
                }
                Button("Delete All \(reciter.shortName) Downloads", role: .destructive) {
                    deleteAllReciter = reciter
                }
            } header: {
                HStack {
                    Text(reciter.shortName)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: downloadManager.storageUsed(for: reciter), countStyle: .file))
                        .font(.caption)
                }
            }
        }
    }

    private func surahRow(surahId: Int, reciter: Reciter) -> some View {
        let surah = dataService.surahs.first { $0.id == surahId }
        let size = downloadManager.fileSizeForSurah(surahId, reciter: reciter)
        return LabeledContent {
            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                .foregroundStyle(Color.niyaSecondary)
                .font(.caption)
        } label: {
            Text(surah?.transliteration ?? "Surah \(surahId)")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Section {
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.circle")
                    .font(.largeTitle)
                    .foregroundStyle(Color.niyaSecondary)
                Text("No Downloads")
                    .font(.headline)
                Text("Download surah audio from the reader settings for offline listening.")
                    .font(.caption)
                    .foregroundStyle(Color.niyaSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
            .listRowBackground(Color.clear)
        }
    }
}

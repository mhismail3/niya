import SwiftUI

struct SurahSearchView: View {
    @Environment(QuranDataService.self) private var dataService
    @Environment(HadithDataService.self) private var hadithDataService
    @Environment(DuaDataService.self) private var duaDataService
    @Environment(\.stores) private var stores
    @AppStorage(StorageKey.selectedScript) private var script: QuranScript = .hafs
    @AppStorage(StorageKey.selectedTranslations) private var selectedTranslationIds = "en_sahih"
    @State private var searchQuery = ""
    @State private var recentQueries: [RecentSearch] = []
    @State private var searchResults = SearchResults.empty
    @State private var isSearchPending = false
    @State private var indexStatus = SearchIndexStatus.idle
    @State private var configuredIndexKey: String?
    @State private var searchIndex = SearchIndex()
    @State private var searchTask: Task<Void, Never>?

    private var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    unifiedSearchResults
                } else {
                    recentsList
                }
            }
            .background(Color.niyaBackground)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .niyaToolbar()
        }
        .searchable(text: $searchQuery, prompt: "Quran, hadiths, and duas")
        .onChange(of: searchQuery) { _, newValue in
            scheduleSearch(for: newValue)
        }
        .onChange(of: script) { _, _ in rebuildIndexAndRefreshSearch() }
        .onChange(of: selectedTranslationIds) { _, _ in rebuildIndexAndRefreshSearch() }
        .onSubmit(of: .search) {
            stores.recentSearch.saveQuery(searchQuery)
            reloadRecents()
        }
        .onAppear {
            reloadRecents()
            rebuildIndexAndRefreshSearch()
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    // MARK: - Unified Search

    private var unifiedSearchResults: some View {
        let hasAny = !searchResults.isEmpty

        return List {
            if !searchResults.quranVerses.isEmpty {
                Section {
                    ForEach(searchResults.quranVerses) { item in
                        NavigationLink(destination: readerView(for: item)) {
                            QuranVerseSearchResultRow(result: item, script: script)
                        }
                        .listRowBackground(Color.niyaBackground)
                    }
                } header: {
                    sectionLabel("Quran Verses", count: searchResults.quranVerses.count)
                }
            }

            if !searchResults.surahs.isEmpty {
                Section {
                    ForEach(searchResults.surahs) { surah in
                        NavigationLink(destination: readerView(for: surah)) {
                            SurahRowView(surah: surah)
                        }
                        .listRowBackground(Color.niyaBackground)
                    }
                } header: {
                    sectionLabel("Surahs", count: searchResults.surahs.count)
                }
            }

            if searchResults.isHadithIndexing {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Indexing Hadith")
                        .font(.niyaCaption)
                        .foregroundStyle(Color.niyaSecondary)
                }
                .listRowBackground(Color.niyaBackground)
            }

            if !searchResults.hadiths.isEmpty {
                Section {
                    ForEach(searchResults.hadiths) { item in
                        NavigationLink {
                            HadithDetailView(
                                hadith: item.hadith,
                                collectionId: item.collectionId,
                                hasGrades: item.hasGrades
                            )
                        } label: {
                            HadithSearchResultRow(
                                collectionId: item.collectionId,
                                hadith: item.hadith,
                                collectionName: item.collectionName,
                                hasGrades: item.hasGrades
                            )
                        }
                        .listRowBackground(Color.niyaBackground)
                    }
                } header: {
                    sectionLabel("Hadith", count: searchResults.hadiths.count)
                }
            }

            if !searchResults.duas.isEmpty {
                Section {
                    ForEach(searchResults.duas) { item in
                        NavigationLink {
                            DuaDetailView(dua: item.dua, categoryId: item.categoryId)
                        } label: {
                            DuaSearchResultRow(
                                categoryName: item.categoryName,
                                dua: item.dua
                            )
                        }
                        .listRowBackground(Color.niyaBackground)
                    }
                } header: {
                    sectionLabel("Dua", count: searchResults.duas.count)
                }
            }

            if isSearchPending || indexStatus == .building {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Searching")
                        .font(.niyaCaption)
                        .foregroundStyle(Color.niyaSecondary)
                }
                .listRowBackground(Color.niyaBackground)
            } else if let message = searchResults.hadithError {
                Text(message)
                    .font(.niyaCaption)
                    .foregroundStyle(Color.niyaSecondary)
                    .listRowBackground(Color.niyaBackground)
            } else if !hasAny {
                ContentUnavailableView.search(text: searchQuery)
                    .listRowBackground(Color.niyaBackground)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func sectionLabel(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaSecondary)
            Spacer()
            Text("\(count)")
                .font(.niyaCaption2)
                .foregroundStyle(Color.niyaSecondary)
        }
    }

    // MARK: - Recents & Suggestions

    private let suggestedTerms = [
        "Al-Fatiha", "Al-Baqarah", "Yasin", "Al-Mulk", "Ar-Rahman",
        "Ayat al-Kursi", "patience", "mercy", "forgiveness", "paradise",
        "prayer", "fasting", "charity", "repentance", "gratitude",
        "الفاتحة", "يس", "الملك", "الرحمن", "الكهف",
        "صبر", "رحمة", "توبة", "دعاء", "جنة",
    ]

    private var recentsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !recentQueries.isEmpty {
                    sectionHeader("Recent Searches")
                    ForEach(recentQueries, id: \.id) { recent in
                        Button {
                            searchQuery = recent.query
                        } label: {
                            Label(recent.query, systemImage: "magnifyingglass")
                                .font(.niyaBody)
                                .foregroundStyle(Color.niyaText)
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Divider().padding(.horizontal)
                    }
                }

                sectionHeader("Suggested")
                FlowLayout(spacing: 8, rightToLeft: false) {
                    ForEach(suggestedTerms, id: \.self) { term in
                        Button {
                            searchQuery = term
                        } label: {
                            Text(term)
                                .font(.niyaCaption)
                                .foregroundStyle(Color.niyaText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.niyaSurface, in: .capsule)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.niyaCaption)
            .foregroundStyle(Color.niyaSecondary)
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 4)
    }

    private func readerView(for surah: Surah) -> some View {
        ReaderContainerView(
            vm: ReaderViewModel(
                surah: surah,
                dataService: dataService,
                script: script
            )
        )
    }

    @ViewBuilder
    private func readerView(for result: QuranVerseSearchResult) -> some View {
        if let surah = dataService.surah(id: result.surahId) {
            ReaderContainerView(
                vm: ReaderViewModel(
                    surah: surah,
                    dataService: dataService,
                    script: script,
                    initialAyahId: result.ayahId
                )
            )
        } else {
            EmptyView()
        }
    }

    private func scheduleSearch(for query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isSearchPending = false
            searchResults = .empty
            return
        }

        isSearchPending = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            await configureSearchIndex()
            await searchLoop(query: trimmed)
        }
    }

    private func rebuildIndexAndRefreshSearch() {
        searchTask?.cancel()
        searchTask = Task {
            await configureSearchIndex()
            guard !Task.isCancelled else { return }
            let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            await searchLoop(query: trimmed)
        }
    }

    @MainActor
    private func configureSearchIndex() async {
        if indexStatus == .building {
            while indexStatus == .building && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
            }
        }

        guard !Task.isCancelled else { return }
        await dataService.load()
        await hadithDataService.load()
        await duaDataService.load()
        guard !Task.isCancelled else { return }

        let key = currentIndexKey()
        if configuredIndexKey == key, indexStatus == .ready {
            return
        }

        indexStatus = .building
        let snapshot = SearchContentSnapshot(
            quran: dataService.searchSnapshot(script: script),
            hadithCollections: hadithDataService.searchCollectionsSnapshot(),
            duas: duaDataService.searchSnapshot()
        )
        await searchIndex.configure(snapshot: snapshot)
        configuredIndexKey = key
        indexStatus = .ready
    }

    @MainActor
    private func currentIndexKey() -> String {
        [
            script.rawValue,
            selectedTranslationIds,
            "\(dataService.surahs.count)",
            "\(hadithDataService.collections.count)",
            "\(duaDataService.categories.count)"
        ].joined(separator: "|")
    }

    @MainActor
    private func searchLoop(query: String) async {
        var latest = await searchIndex.search(query: query)
        while !Task.isCancelled {
            guard searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query else { return }
            searchResults = latest
            isSearchPending = false

            guard latest.isHadithIndexing else { return }
            try? await Task.sleep(for: .milliseconds(250))
            latest = await searchIndex.search(query: query)
        }
    }

    private func reloadRecents() {
        recentQueries = stores.recentSearch.recentQueries()
    }
}

private struct QuranVerseSearchResultRow: View {
    let result: QuranVerseSearchResult
    let script: QuranScript

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\(result.surahName) \(result.surahId):\(result.ayahId)")
                    .font(.niyaCaption2)
                    .foregroundStyle(Color.niyaTeal)
                Spacer()
                Text(result.translationName)
                    .font(.niyaCaption2)
                    .foregroundStyle(Color.niyaSecondary)
                    .lineLimit(1)
            }

            Text(result.translation)
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaText)
                .lineLimit(2)

            if !result.arabic.isEmpty {
                Text(result.arabic)
                    .font(.quranText(script: script, size: 18))
                    .foregroundStyle(Color.niyaSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
    }
}

enum SearchResultLimits {
    static let quranVerses = 25
    static let surahs = 10
    static let hadiths = 15
    static let duas = 15
}

enum SearchIndexStatus {
    case idle
    case building
    case ready
}

struct SearchContentSnapshot: Sendable {
    let quran: QuranSearchSnapshot
    let hadithCollections: [HadithCollectionSearchSource]
    let duas: [DuaSearchSource]
    let quranFingerprint: String
    let duaFingerprint: String

    init(quran: QuranSearchSnapshot, hadithCollections: [HadithCollectionSearchSource], duas: [DuaSearchSource]) {
        self.quran = quran
        self.hadithCollections = hadithCollections
        self.duas = duas
        quranFingerprint = Self.fingerprint(
            count: quran.verses.count,
            first: quran.verses.first?.id,
            last: quran.verses.last?.id,
            detail: [
                String(quran.surahs.count),
                quran.displayScript?.rawValue,
                quran.surahs.first.map { "\($0.id):\($0.transliteration)" },
                quran.surahs.last.map { "\($0.id):\($0.transliteration)" },
                quran.verses.first?.displayArabic,
                quran.verses.last?.displayArabic,
                quran.verses.first?.displayTranslation,
                quran.verses.first?.translationTexts.map(\.name).joined(separator: ",")
            ]
                .compactMap { $0 }
                .joined(separator: "|")
        )
        duaFingerprint = Self.fingerprint(
            count: duas.count,
            first: duas.first.map { "\($0.categoryId):\($0.dua.id)" },
            last: duas.last.map { "\($0.categoryId):\($0.dua.id)" },
            detail: nil
        )
    }

    private static func fingerprint(count: Int, first: String?, last: String?, detail: String?) -> String {
        [String(count), first ?? "", last ?? "", detail ?? ""].joined(separator: "|")
    }
}

struct QuranReference: Equatable, Sendable {
    let surahId: Int
    let ayahId: Int
}

struct SearchQuery: Sendable {
    let raw: String
    let normalized: String
    let tokens: [String]
    let surahNumber: Int?
    let reference: QuranReference?

    init(_ rawValue: String) {
        raw = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized = SearchTextNormalizer.normalize(raw)
        tokens = normalized
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }

        let normalizedReferenceText = raw.replacingOccurrences(of: "：", with: ":")
        let referenceParts = normalizedReferenceText.split(separator: ":", omittingEmptySubsequences: true)
        if referenceParts.count == 2,
           let surah = Int(referenceParts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
           let ayah = Int(referenceParts[1].trimmingCharacters(in: .whitespacesAndNewlines)) {
            reference = QuranReference(surahId: surah, ayahId: ayah)
            surahNumber = nil
        } else {
            reference = nil
            surahNumber = Int(raw)
        }
    }

    var isEmpty: Bool {
        normalized.isEmpty && surahNumber == nil && reference == nil
    }
}

enum SearchTextNormalizer {
    static func normalize(_ text: String) -> String {
        let folded = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        var scalars = String.UnicodeScalarView()
        var lastWasSpace = true

        for scalar in folded.unicodeScalars {
            if shouldRemove(scalar) { continue }
            if let replacement = replacement(for: scalar) {
                append(replacement, to: &scalars, lastWasSpace: &lastWasSpace)
            } else if isSearchableScalar(scalar) {
                scalars.append(scalar)
                lastWasSpace = false
            } else if !lastWasSpace {
                scalars.append(" ")
                lastWasSpace = true
            }
        }

        var normalized = String(scalars)
        if normalized.last == " " {
            normalized.removeLast()
        }
        return normalized
    }

    private static func append(_ text: String, to scalars: inout String.UnicodeScalarView, lastWasSpace: inout Bool) {
        for scalar in text.unicodeScalars {
            scalars.append(scalar)
            lastWasSpace = scalar == " "
        }
    }

    private static func isSearchableScalar(_ scalar: UnicodeScalar) -> Bool {
        CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar)
    }

    private static func shouldRemove(_ scalar: UnicodeScalar) -> Bool {
        let value = scalar.value
        return value == 0x0640 ||
            (0x0610...0x061A).contains(value) ||
            (0x064B...0x065F).contains(value) ||
            value == 0x0670 ||
            (0x06D6...0x06ED).contains(value)
    }

    private static func replacement(for scalar: UnicodeScalar) -> String? {
        switch scalar {
        case "\u{0622}", "\u{0623}", "\u{0625}", "\u{0671}":
            return "ا"
        case "\u{0649}":
            return "ي"
        case "\u{0624}":
            return "و"
        case "\u{0626}":
            return "ي"
        default:
            return nil
        }
    }
}

struct SearchField: Sendable {
    let text: String
    let normalized: String
    let weight: Int

    init(text: String, normalized: String? = nil, weight: Int) {
        self.text = text
        self.normalized = normalized ?? SearchTextNormalizer.normalize(text)
        self.weight = weight
    }
}

enum SearchTextMatcher {
    static func score(query: SearchQuery, fields: [SearchField]) -> Int? {
        guard !query.normalized.isEmpty else { return nil }
        var best: Int?
        for field in fields where !field.normalized.isEmpty {
            let candidate: Int?
            if field.normalized == query.normalized {
                candidate = 4_000 + field.weight
            } else if field.normalized.hasPrefix(query.normalized) {
                candidate = 3_000 + field.weight
            } else if field.normalized.contains(query.normalized) {
                candidate = 2_000 + field.weight
            } else {
                let matchCount = query.tokens.reduce(0) { count, token in
                    field.normalized.contains(token) ? count + 1 : count
                }
                if matchCount == query.tokens.count, matchCount > 0 {
                    candidate = 1_000 + field.weight + matchCount
                } else if matchCount > 0, query.normalized.count >= 3 {
                    candidate = 100 + field.weight + matchCount
                } else {
                    candidate = nil
                }
            }

            if let candidate {
                best = max(best ?? candidate, candidate)
            }
        }
        return best
    }
}

struct SearchResults: Sendable {
    var quranVerses: [QuranVerseSearchResult] = []
    var surahs: [Surah] = []
    var hadiths: [HadithSearchResult] = []
    var duas: [DuaSearchResult] = []
    var isHadithIndexing = false
    var hadithError: String?

    static let empty = SearchResults()

    var isEmpty: Bool {
        quranVerses.isEmpty && surahs.isEmpty && hadiths.isEmpty && duas.isEmpty
    }
}

struct QuranVerseSearchResult: Identifiable, Sendable {
    let id: String
    let surahId: Int
    let ayahId: Int
    let surahName: String
    let arabic: String
    let translation: String
    let translationName: String
}

struct HadithSearchResult: Identifiable, Sendable {
    let id: String
    let collectionId: String
    let collectionName: String
    let hasGrades: Bool
    let hadith: Hadith
}

struct DuaSearchResult: Identifiable, Sendable {
    let id: String
    let categoryId: String
    let categoryName: String
    let dua: Dua
}

actor SearchIndex {
    private var surahRecords: [SurahRecord] = []
    private var quranRecords: [QuranRecord] = []
    private var duaRecords: [DuaRecord] = []
    private var quranFingerprint = ""
    private var duaFingerprint = ""
    private var hadithCollectionSources: [HadithCollectionSearchSource] = []
    private var hadithRecords: [HadithRecord] = []
    private var hadithFingerprint = ""
    private var hadithGeneration = 0
    private var hadithState = HadithIndexState.notStarted
    private var pendingHadithBuilds = 0
    private var hadithError: String?

    func configure(snapshot: SearchContentSnapshot) {
        if snapshot.quranFingerprint != quranFingerprint {
            quranFingerprint = snapshot.quranFingerprint
            surahRecords = snapshot.quran.surahs.enumerated().map { index, surah in
                SurahRecord(surah: surah, ordinal: index)
            }
            quranRecords = snapshot.quran.verses.enumerated().map { index, source in
                QuranRecord(source: source, ordinal: index)
            }
        }

        if snapshot.duaFingerprint != duaFingerprint {
            duaFingerprint = snapshot.duaFingerprint
            duaRecords = snapshot.duas.enumerated().map { index, source in
                DuaRecord(source: source, ordinal: index)
            }
        }

        let nextFingerprint = snapshot.hadithCollections
            .map { "\($0.id):\($0.name):\($0.hasGrades)" }
            .joined(separator: "|")
        if nextFingerprint != hadithFingerprint {
            hadithFingerprint = nextFingerprint
            hadithGeneration += 1
            hadithCollectionSources = snapshot.hadithCollections
            hadithRecords = []
            hadithError = nil
            hadithState = .notStarted
            pendingHadithBuilds = 0
        }
    }

    func search(query rawQuery: String) -> SearchResults {
        let query = SearchQuery(rawQuery)
        guard !query.isEmpty else { return .empty }

        if query.reference == nil, query.surahNumber == nil {
            startHadithIndexingIfNeeded()
        }

        return SearchResults(
            quranVerses: searchQuran(query: query),
            surahs: searchSurahs(query: query),
            hadiths: hadithState == .notStarted ? [] : searchHadiths(query: query),
            duas: searchDuas(query: query),
            isHadithIndexing: hadithState == .indexing,
            hadithError: hadithError
        )
    }

    func hadithIndexStateForTesting() -> String {
        hadithState.rawValue
    }

    private func startHadithIndexingIfNeeded() {
        guard hadithState == .notStarted, !hadithCollectionSources.isEmpty else { return }
        hadithState = .indexing
        pendingHadithBuilds = hadithCollectionSources.count
        let generation = hadithGeneration
        for (collectionIndex, collection) in hadithCollectionSources.enumerated() {
            Task.detached(priority: .utility) { [weak self] in
                let output = Self.buildHadithRecords(collection: collection, collectionIndex: collectionIndex)
                await self?.appendHadithIndex(records: output.records, error: output.error, generation: generation)
            }
        }
    }

    private func appendHadithIndex(records: [HadithRecord], error: String?, generation: Int) {
        guard generation == hadithGeneration else { return }

        hadithRecords.append(contentsOf: records)
        hadithRecords.sort { $0.ordinal < $1.ordinal }
        if let error {
            if let hadithError {
                self.hadithError = "\(hadithError), \(error)"
            } else {
                self.hadithError = error
            }
        }
        pendingHadithBuilds -= 1
        if pendingHadithBuilds <= 0 {
            pendingHadithBuilds = 0
            hadithState = .ready
        }
    }

    private func searchSurahs(query: SearchQuery) -> [Surah] {
        ranked(surahRecords.compactMap { record in
            if let number = query.surahNumber {
                return record.surah.id == number ? Scored(score: 5_000, ordinal: record.ordinal, value: record.surah) : nil
            }
            guard let score = SearchTextMatcher.score(query: query, fields: record.fields) else { return nil }
            return Scored(score: score, ordinal: record.ordinal, value: record.surah)
        }, limit: SearchResultLimits.surahs)
    }

    private func searchQuran(query: SearchQuery) -> [QuranVerseSearchResult] {
        ranked(quranRecords.compactMap { record in
            if let reference = query.reference {
                guard record.source.surah.id == reference.surahId, record.source.ayahId == reference.ayahId else { return nil }
                return Scored(score: 6_000, ordinal: record.ordinal, value: record.result)
            }
            guard let score = SearchTextMatcher.score(query: query, fields: record.fields) else { return nil }
            return Scored(score: score, ordinal: record.ordinal, value: record.result)
        }, limit: SearchResultLimits.quranVerses)
    }

    private func searchHadiths(query: SearchQuery) -> [HadithSearchResult] {
        ranked(hadithRecords.compactMap { record in
            guard let score = SearchTextMatcher.score(query: query, fields: record.fields) else { return nil }
            return Scored(score: score, ordinal: record.ordinal, value: record.result)
        }, limit: SearchResultLimits.hadiths)
    }

    private func searchDuas(query: SearchQuery) -> [DuaSearchResult] {
        ranked(duaRecords.compactMap { record in
            guard let score = SearchTextMatcher.score(query: query, fields: record.fields) else { return nil }
            return Scored(score: score, ordinal: record.ordinal, value: record.result)
        }, limit: SearchResultLimits.duas)
    }

    private func ranked<T>(_ scored: [Scored<T>], limit: Int) -> [T] {
        scored
            .sorted {
                if $0.score == $1.score { return $0.ordinal < $1.ordinal }
                return $0.score > $1.score
            }
            .prefix(limit)
            .map(\.value)
    }

    private static func buildHadithRecords(
        collection: HadithCollectionSearchSource,
        collectionIndex: Int
    ) -> HadithBuildOutput {
        do {
            let file = try CompressedJSON.decode(SearchRawHadithFile.self, resource: "hadith_\(collection.id)")
            let records = file.hadiths.enumerated().map { hadithIndex, hadith in
                HadithRecord(
                    collection: collection,
                    hadith: hadith,
                    ordinal: collectionIndex * 100_000 + hadithIndex
                )
            }
            return HadithBuildOutput(records: records, error: nil)
        } catch {
            return HadithBuildOutput(records: [], error: "\(collection.name) could not be indexed")
        }
    }
}

private enum HadithIndexState: String, Sendable {
    case notStarted
    case indexing
    case ready
}

private struct Scored<T>: Sendable where T: Sendable {
    let score: Int
    let ordinal: Int
    let value: T
}

private struct SurahRecord: Sendable {
    let surah: Surah
    let ordinal: Int
    let fields: [SearchField]

    init(surah: Surah, ordinal: Int) {
        self.surah = surah
        self.ordinal = ordinal
        fields = [
            SearchField(text: surah.transliteration, weight: 700),
            SearchField(text: surah.translation, weight: 650),
            SearchField(text: surah.name, weight: 650),
            SearchField(text: "\(surah.id)", weight: 800)
        ]
    }
}

private struct QuranRecord: Sendable {
    let source: QuranVerseSearchSource
    let ordinal: Int
    let fields: [SearchField]
    let result: QuranVerseSearchResult

    init(source: QuranVerseSearchSource, ordinal: Int) {
        self.source = source
        self.ordinal = ordinal
        let translationFields = source.translationTexts.map {
            SearchField(text: $0.text, weight: $0.isRTL ? 300 : 500)
        }
        let arabicFields = source.searchableArabic.map {
            SearchField(text: $0, weight: 450)
        }
        fields = translationFields + arabicFields + [
            SearchField(text: "\(source.surah.id):\(source.ayahId)", weight: 900)
        ]
        result = QuranVerseSearchResult(
            id: source.id,
            surahId: source.surah.id,
            ayahId: source.ayahId,
            surahName: source.surah.transliteration,
            arabic: source.displayArabic,
            translation: source.displayTranslation,
            translationName: source.translationTexts.first?.name ?? "Translation"
        )
    }
}

private struct HadithRecord: Sendable {
    let result: HadithSearchResult
    let ordinal: Int
    let fields: [SearchField]

    init(collection: HadithCollectionSearchSource, hadith: Hadith, ordinal: Int) {
        self.ordinal = ordinal
        result = HadithSearchResult(
            id: "\(collection.id):\(hadith.id)",
            collectionId: collection.id,
            collectionName: collection.name,
            hasGrades: collection.hasGrades,
            hadith: hadith
        )
        fields = [
            SearchField(text: collection.name, weight: 500),
            SearchField(text: hadith.narrator, weight: 250),
            SearchField(text: hadith.text, weight: 100),
            SearchField(text: hadith.arabic, weight: 150),
            SearchField(text: "\(hadith.id)", weight: 200)
        ]
    }
}

private struct HadithBuildOutput: Sendable {
    let records: [HadithRecord]
    let error: String?
}

private struct DuaRecord: Sendable {
    let result: DuaSearchResult
    let ordinal: Int
    let fields: [SearchField]

    init(source: DuaSearchSource, ordinal: Int) {
        self.ordinal = ordinal
        result = DuaSearchResult(
            id: "\(source.categoryId):\(source.dua.id)",
            categoryId: source.categoryId,
            categoryName: source.categoryName,
            dua: source.dua
        )
        fields = [
            SearchField(text: source.categoryName, weight: 500),
            SearchField(text: source.dua.context ?? "", weight: 350),
            SearchField(text: source.dua.reference ?? "", weight: 250),
            SearchField(text: source.dua.translation ?? "", weight: 180),
            SearchField(text: source.dua.transliteration ?? "", weight: 160),
            SearchField(text: source.dua.arabic, weight: 180),
            SearchField(text: source.dua.id, weight: 200)
        ]
    }
}

private struct SearchRawHadithFile: Decodable, Sendable {
    let hadiths: [Hadith]
}

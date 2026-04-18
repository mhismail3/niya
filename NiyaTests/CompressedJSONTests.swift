import Foundation
import Testing
@testable import Niya

@Suite("CompressedJSON")
struct CompressedJSONTests {

    @Test func loadSurahsFromCompressedBundle() throws {
        let data = try CompressedJSON.load(resource: "surahs")
        #expect(!data.isEmpty)
        let surahs = try JSONDecoder().decode([Surah].self, from: data)
        #expect(surahs.count == 114)
    }

    @Test func decodeSurahsFromCompressedBundle() throws {
        let surahs = try CompressedJSON.decode([Surah].self, resource: "surahs")
        #expect(surahs.count == 114)
        #expect(surahs.first?.id == 1)
    }

    @Test func loadDuaFromCompressedBundle() throws {
        let data = try CompressedJSON.load(resource: "dua_all")
        #expect(!data.isEmpty)
    }

    @Test func loadHadithCollectionsFromCompressedBundle() throws {
        let collections = try CompressedJSON.decode([HadithCollection].self, resource: "hadith_collections")
        #expect(!collections.isEmpty)
    }

    @Test func missingResourceThrows() {
        #expect(throws: CompressedJSONError.self) {
            try CompressedJSON.load(resource: "nonexistent_file_xyz")
        }
    }

    @Test func loadTafsirSubdirectory() throws {
        let dict = try CompressedJSON.decode(
            [String: String].self,
            resource: "1",
            subdirectory: "tafsir_ibn_kathir"
        )
        #expect(!dict.isEmpty)
    }

    @Test func bundleURLResolution() {
        let url = Bundle.main.url(forResource: "surahs.json", withExtension: "zlib")
        #expect(url != nil, "Bundle should find surahs.json.zlib via forResource:'surahs.json' withExtension:'zlib'")
    }
}

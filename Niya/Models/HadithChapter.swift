import Foundation

struct HadithChapter: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let titleArabic: String
    let hadithRange: [Int]

    var hadithCount: Int {
        guard hadithRange.count == 2 else { return 0 }
        return hadithRange[1] - hadithRange[0] + 1
    }
}

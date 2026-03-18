import Foundation

struct DuaCategory: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let sectionId: String
    let totalDuas: Int
}

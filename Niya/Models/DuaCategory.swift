import Foundation

struct DuaCategory: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let sectionId: String
    let totalDuas: Int
}

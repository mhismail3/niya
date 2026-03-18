import Foundation

struct DuaSection: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let categoryIds: [String]
}

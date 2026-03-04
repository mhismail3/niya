import Foundation

enum AppError: LocalizedError, Equatable {
    case network(String)
    case data(String)
    case audio(String)

    var errorDescription: String? {
        switch self {
        case .network(let msg): return msg
        case .data(let msg): return msg
        case .audio(let msg): return msg
        }
    }
}

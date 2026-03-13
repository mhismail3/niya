import Foundation

enum TafsirBlock: Identifiable {
    case heading(String)
    case arabicQuote(String)
    case translation(String)
    case commentary(String)
    case quoteGroup(arabic: String, translation: String)

    var id: String {
        switch self {
        case .heading(let t): return "h:\(t.hashValue)"
        case .arabicQuote(let t): return "a:\(t.hashValue)"
        case .translation(let t): return "t:\(t.hashValue)"
        case .commentary(let t): return "c:\(t.hashValue)"
        case .quoteGroup(let a, let t): return "q:\(a.hashValue):\(t.hashValue)"
        }
    }
}

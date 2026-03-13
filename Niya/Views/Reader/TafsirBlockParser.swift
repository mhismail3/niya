import Foundation

enum TafsirBlockParser {

    static func parse(_ text: String) -> [TafsirBlock] {
        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Pass 1: classify each line
        var classified: [(TafsirBlock, String)] = [] // (block, raw line)
        for (index, line) in lines.enumerated() {
            let block = classify(line, previousBlock: index > 0 ? classified[index - 1].0 : nil)
            classified.append((block, line))
        }

        // Pass 2: merge arabicQuote + translation into quoteGroup
        var result: [TafsirBlock] = []
        var i = 0
        while i < classified.count {
            if case .arabicQuote(let arabic) = classified[i].0,
               i + 1 < classified.count,
               case .translation(let trans) = classified[i + 1].0 {
                result.append(.quoteGroup(arabic: arabic, translation: trans))
                i += 2
            } else {
                result.append(classified[i].0)
                i += 1
            }
        }
        return result
    }

    private static func classify(_ line: String, previousBlock: TafsirBlock?) -> TafsirBlock {
        if isArabicLine(line) {
            return .arabicQuote(line)
        }

        if line.hasPrefix("("), isArabicBlock(previousBlock) {
            return .translation(line)
        }

        if isHeading(line) {
            return .heading(line)
        }

        return .commentary(line)
    }

    static func isArabicLine(_ line: String) -> Bool {
        let alphabeticScalars = line.unicodeScalars.filter(\.properties.isAlphabetic)
        guard !alphabeticScalars.isEmpty else { return false }
        return alphabeticScalars.allSatisfy { isArabicScalar($0) }
    }

    private static func isArabicBlock(_ block: TafsirBlock?) -> Bool {
        guard let block else { return false }
        switch block {
        case .arabicQuote: return true
        default: return false
        }
    }

    private static let narratorPatterns = ["said that", "narrated", "reported", "mentioned that",
                                           "related that", "told us", "informed us"]

    private static func isHeading(_ line: String) -> Bool {
        guard line.count < 100 else { return false }
        guard !line.hasPrefix("(") else { return false }

        let lastChar = line.last
        if lastChar == "," || lastChar == ";" || lastChar == ":" || lastChar == "." { return false }

        let alphabeticScalars = line.unicodeScalars.filter(\.properties.isAlphabetic)
        guard !alphabeticScalars.isEmpty else { return false }

        let hasArabic = alphabeticScalars.contains { isArabicScalar($0) }
        if hasArabic { return false }

        guard let firstAlpha = line.first(where: { $0.isLetter }) else { return false }
        if !firstAlpha.isUppercase { return false }

        let lower = line.lowercased()
        for pattern in narratorPatterns {
            if lower.contains(pattern) { return false }
        }

        return true
    }

    static func isArabicScalar(_ s: Unicode.Scalar) -> Bool {
        (0x0600...0x06FF).contains(s.value) ||
        (0x0750...0x077F).contains(s.value) ||
        (0x08A0...0x08FF).contains(s.value) ||
        (0xFB50...0xFDFF).contains(s.value) ||
        (0xFE70...0xFEFF).contains(s.value)
    }
}

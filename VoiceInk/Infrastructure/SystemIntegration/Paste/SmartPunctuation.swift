import Foundation

enum SmartPunctuation {
    private static let typography = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
    private static let nonTerminalAbbreviations: Set<String> = ["mr", "mrs", "ms", "dr", "prof", "st", "sr", "jr", "vs"]

    struct Context: Equatable, Sendable {
        let before: String
        let after: String

        init?(text: String, selection: NSRange) {
            let utf16Length = text.utf16.count
            guard selection.location >= 0, selection.length >= 0,
                selection.location <= utf16Length,
                selection.length <= utf16Length - selection.location,
                let range = Range(selection, in: text),
                NSRange(range, in: text) == selection,
                range.lowerBound == text.endIndex || text.indices.contains(range.lowerBound),
                range.upperBound == text.endIndex || text.indices.contains(range.upperBound)
            else { return nil }
            before = String(text[..<range.lowerBound].suffix(256))
            after = String(text[range.upperBound...].prefix(256))
        }
    }

    /// Changes only the insertion; surrounding text and the saved transcript stay intact.
    /// `protectedWords` are dictionary terms whose first token keeps its capital mid-sentence.
    static func adjusted(_ text: String, context: Context, protectedWords: [String]) -> String {
        let before = context.before
        let after = context.after
        let core = text.trimmingCharacters(in: .whitespaces)
        // A newline at the outer edge would be duplicated by the prefix and suffix below.
        guard let coreFirst = core.first, let coreLast = core.last,
            !coreFirst.isNewline, !coreLast.isNewline,
            [coreFirst, coreLast, before.last(where: { !$0.isWhitespace }), after.first(where: { !$0.isWhitespace })]
                .allSatisfy({ $0.map(isSupported) ?? true }),
            !text.contains("\t"),
            !core.contains(where: { "`{}\\".contains($0) })
        else { return text }
        let tokens = core.split(whereSeparator: \.isWhitespace)
        guard ![tokens.first, tokens.last].contains(where: { $0.map(isStructured) ?? false }) else { return text }
        if let left = before.last, let right = after.first,
            left.isLetterOrNumber, right.isLetterOrNumber {
            return " " + core + " "
        }

        var result = adjustedCapitalization(core, before: before, protectedWords: protectedWords)
        let following = after.drop(while: \.isWhitespace)
        let sameLine = !after.prefix(while: \.isWhitespace).contains(where: \.isNewline)
        if sameLine, let last = result.last, let next = following.first,
            ".,;:!?。！？".contains(last), last == next,
            !result.hasSuffix(String(repeating: String(last), count: 2)),
            !following.hasPrefix(String(repeating: String(last), count: 2)) {
            result.removeLast()
        } else if sameLine, following.first.map({ ($0.isLetter && !$0.isUppercase) || ",;:!?、，；：！？".contains($0) }) == true,
            canRemovePeriod(from: result) {
            result.removeLast()
        }
        guard !result.isEmpty else { return text }

        // Keep intentional whitespace unless the editor already supplies the boundary.
        var prefix = String(text.prefix(while: { $0.isWhitespace }))
        var suffix = String(text.reversed().prefix(while: { $0.isWhitespace }).reversed())
        if before.last?.isWhitespace == true { prefix = "" }
        if after.first?.isWhitespace == true || after.first.map(isClosingPunctuation) == true { suffix = "" }
        if let left = before.last, let first = result.first {
            if isOpeningPunctuation(left) { prefix = "" }
            else if prefix.isEmpty, needsSpace(between: left, and: first) { prefix = " " }
        }
        if let last = result.last, let right = after.first,
            suffix.isEmpty, needsSpace(between: last, and: right) {
            suffix = " "
        }
        return prefix + result + suffix
    }

    private static func adjustedCapitalization(_ text: String, before: String, protectedWords: [String]) -> String {
        guard let first = text.first, first.isLetter else { return text }
        let token = firstToken(of: text)
        guard token.dropFirst().allSatisfy({ !$0.isUppercase }),
            token != "I", !token.hasPrefix("I'"), !token.hasPrefix("I’") else { return text }
        let left = before.trimmingCharacters(in: .whitespaces)
        let startsSentence = left.isEmpty || left.last?.isNewline == true || endsSentence(left)
        if startsSentence, first.isLowercase {
            return first.uppercased() + text.dropFirst()
        }
        guard !startsSentence, first.isUppercase,
            let previous = left.last, previous.isLetterOrNumber,
            !protectedWords.contains(where: { firstToken(of: $0) == token })
        else { return text }

        return first.lowercased() + text.dropFirst()
    }

    private static func firstToken(of text: String) -> String {
        String(text.prefix(while: { $0.isLetter || $0 == "'" || $0 == "’" }))
    }

    private static func endsSentence(_ text: String) -> Bool {
        var end = text[...]
        while let last = end.last, "\"'”’)]}»」』】）".contains(last) { end.removeLast() }
        guard let last = end.last else { return false }
        if "!?。！？".contains(last) { return true }
        guard last == ".", !end.hasSuffix("..") else { return false }
        let token = end.dropLast().split(whereSeparator: \.isWhitespace).last.map(String.init) ?? ""
        return !isDottedAbbreviation(token)
            && !nonTerminalAbbreviations.contains(token.trimmingCharacters(in: .punctuationCharacters).lowercased())
    }

    private static func canRemovePeriod(from text: String) -> Bool {
        if text.hasSuffix("。") {
            return !text.hasSuffix("。。") && text.dropLast().last?.isLetter == true
        }
        guard text.hasSuffix("."), !text.hasSuffix("..") else { return false }
        let token = text.dropLast().split(whereSeparator: \.isWhitespace).last.map(String.init) ?? ""
        guard token.count > 1, token.first?.isLetter == true, token.last?.isLetter == true,
            token.allSatisfy({ $0.isLetter || "'’-".contains($0) }) else { return false }
        return !token.filter(\.isLetter).allSatisfy(\.isUppercase)
    }

    private static func needsSpace(between left: Character, and right: Character) -> Bool {
        guard !left.isWhitespace, !right.isWhitespace,
            !isOpeningPunctuation(left), !isClosingPunctuation(right) else { return false }
        return (left.isLetterOrNumber || isClosingPunctuation(left)) && right.isLetterOrNumber
    }

    private static func isOpeningPunctuation(_ character: Character) -> Bool {
        "([{“‘«「『（【".contains(character)
    }

    private static func isClosingPunctuation(_ character: Character) -> Bool {
        ".,;:!?)]}”’»、。，；：！？）」』】".contains(character)
    }

    private static func isSupported(_ character: Character) -> Bool {
        String(character).precomposedStringWithCanonicalMapping.unicodeScalars.allSatisfy {
            $0.isASCII || typography.contains($0) || (0xC0...0x24F).contains($0.value)
        }
    }

    private static func isStructured(_ token: Substring) -> Bool {
        if token.allSatisfy({ "0123456789.,/:-%$".contains($0) }) || isDottedAbbreviation(token) { return false }
        if token.contains("@") { return token.contains { $0 != "@" } }
        return token.contains("/") || token.trimmingCharacters(in: .punctuationCharacters).contains(".")
    }

    /// shortcut: treats short domains such as t.co as abbreviations; add a known-domain check if that shows up in use.
    private static func isDottedAbbreviation(_ token: some StringProtocol) -> Bool {
        let parts = token.trimmingCharacters(in: .punctuationCharacters).split(separator: ".", omittingEmptySubsequences: false)
        return parts.count > 1 && parts.allSatisfy { (1...2).contains($0.count) && $0.allSatisfy(\.isLetter) }
    }
}

private extension Character {
    var isLetterOrNumber: Bool { isLetter || isNumber }
}

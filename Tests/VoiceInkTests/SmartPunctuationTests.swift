import XCTest
@testable import VoiceInk

final class SmartPunctuationTests: XCTestCase {
    private func adjust(
        _ before: String, _ inserted: String, _ after: String, protectedWords: [String] = []
    ) throws -> String {
        let context = try XCTUnwrap(
            SmartPunctuation.Context(
                text: before + after,
                selection: NSRange(location: before.utf16.count, length: 0)
            )
        )
        return SmartPunctuation.adjusted(inserted, context: context, protectedWords: protectedWords)
    }

    func testProtectedWordKeepsItsCapitalMidSentence() throws {
        XCTAssertEqual(try adjust("I talked to ", "Valarie called me.", "", protectedWords: ["Valarie"]), "Valarie called me.")
        XCTAssertEqual(try adjust("I talked to ", "Mary called me.", "", protectedWords: ["Mary Ann"]), "Mary called me.")
    }

    func testProtectedWordMatchIsCaseSensitive() throws {
        XCTAssertEqual(try adjust("I talked to ", "Valarie called me.", "", protectedWords: ["valarie"]), "valarie called me.")
    }

    func testProtectedWordKeepsItsCapitalAfterCommaSemicolonOrColon() throws {
        for before in ["Hello there, ", "Note: ", "It is done; "] {
            XCTAssertEqual(try adjust(before, "Valarie called me.", "", protectedWords: ["Valarie"]), "Valarie called me.", before)
        }
    }

    func testAdjustedResults() throws {
        let cases: [(String, String, String, String)] = [
            ("I talked to ", "Valarie called me.", "", "valarie called me."),
            ("I went to the ", "Store and left.", "", "store and left."),
            ("I really don't. ", "the next one.", "", "The next one."),
            ("It cost 20. ", "the next one.", "", "The next one."),
            ("It is well-known. ", "the next one.", "", "The next one."),
            ("He said \"go.\" ", "the next one.", "", "The next one."),
            ("It is done.) ", "the next one.", "", "The next one."),
            ("1. ", "buy milk.", "", "Buy milk."),
            ("Renée is done. ", "the next one.", "", "The next one."),
            ("It is done. ", "the price was 3.5 dollars.", "", "The price was 3.5 dollars."),
            ("It is done. ", "use and/or here.", "", "Use and/or here."),
            ("It is done. ", "the U.S. team won.", "", "The U.S. team won."),
            ("It is done. ", "the first.\n\nThe second.", "", "The first.\n\nThe second."),
            ("I said ", "I don't.", " know", "I don't"),
            // Regressions
            ("It is done. ", "the next one.", "", "The next one."),
            ("I said ", "Hello there.", " world", "hello there"),
            ("It is done", "the next one.", "", " the next one."),
            ("foo", "Hello there.", "bar", " Hello there. "),
            // Capital after a comma, semicolon, or colon
            ("Hello there, ", "The next one.", "", "the next one."),
            ("Hello there,", "The next one.", "", " the next one."),
            ("Note: ", "The next one.", "", "the next one."),
            ("It is done; ", "The next one.", "", "the next one."),
            ("Hello there, ", "the next one.", "", "the next one."),
            ("Hello there, ", "I don't know.", "", "I don't know."),
            ("Hello there, ", "NASA called.", "", "NASA called."),
            ("Hello there. ", "The next one.", "", "The next one."),
            ("Hello there,\n", "The next one.", "", "The next one."),
        ]
        for (before, inserted, after, expected) in cases {
            XCTAssertEqual(try adjust(before, inserted, after), expected, "\(before) | \(inserted) | \(after)")
        }
    }

    func testCapitalizationStaysUnchanged() throws {
        let cases = [
            ("Talk to Dr. ", "smith"),
            ("In the U.S. ", "team"),
            ("Wait... ", "what"),
            ("Red vs. ", "blue"),
        ]
        for (before, inserted) in cases {
            XCTAssertEqual(try adjust(before, inserted, ""), inserted, before)
        }
    }

    func testInsertedTextIsReturnedUnchanged() throws {
        let cases = [
            "see https://example.com",
            "foo.swift",
            "the `code` here.",
            "привет мир",
            "\nthe next one.",
            "the next one.\n",
            "the\tnext one.",
            "me@example.com is mine.",
        ]
        for inserted in cases {
            XCTAssertEqual(try adjust("It is done. ", inserted, ""), inserted)
        }
    }

    func testBareAtSignIsNotStructured() throws {
        XCTAssertEqual(try adjust("It is done. ", "use @", ""), "Use @")
    }

    func testNonLatinCharacterBesideCursorLeavesTextUnchanged() throws {
        XCTAssertEqual(try adjust("готово ", "The next one.", ""), "The next one.")
        XCTAssertEqual(try adjust("It is done. ", "the next one.", " 世界"), "the next one.")
    }

    func testSavedModeWithoutKeyDecodesToOn() throws {
        let json = #"{"id":"6F1B7C1E-0D39-4C5B-9C55-0F2D8A5E1A01","name":"Old","isAIEnhancementEnabled":false}"#
        let mode = try JSONDecoder().decode(ModeConfig.self, from: Data(json.utf8))
        XCTAssertTrue(mode.isSmartPunctuationEnabled)
    }

    func testMemberwiseDefaultIsOn() {
        XCTAssertTrue(ModeConfig(name: "New", isAIEnhancementEnabled: false).isSmartPunctuationEnabled)
    }

    func testOffSurvivesEncodeAndDecode() throws {
        let mode = ModeConfig(name: "Off", isAIEnhancementEnabled: false, isSmartPunctuationEnabled: false)
        let decoded = try JSONDecoder().decode(ModeConfig.self, from: JSONEncoder().encode(mode))
        XCTAssertFalse(decoded.isSmartPunctuationEnabled)
    }

    func testOldBackupWithGlobalValueStillImports() throws {
        let json = """
            {
              "version": "2.24",
              "customPrompts": [],
              "modeConfigs": [
                {"id": "6F1B7C1E-0D39-4C5B-9C55-0F2D8A5E1A01", "name": "Old", "isAIEnhancementEnabled": false}
              ],
              "generalSettings": {"smartPunctuationEnabled": false, "pasteMethod": "standard"}
            }
            """
        let backup = try JSONDecoder().decode(BackupFile.self, from: Data(json.utf8))
        XCTAssertEqual(backup.generalSettings?.pasteMethod, "standard")
        // The global value is ignored; each mode carries its own.
        XCTAssertEqual(backup.modeConfigs.map(\.isSmartPunctuationEnabled), [true])

        let exported = String(decoding: try JSONEncoder().encode(backup), as: UTF8.self)
        XCTAssertFalse(exported.contains("smartPunctuationEnabled"))
    }
}

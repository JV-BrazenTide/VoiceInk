import SwiftUI
import XCTest
@testable import VoiceInk

final class PasteScriptTests: XCTestCase {
    private func runPreset(_ preset: PasteScriptPreset, _ input: String) async throws -> String {
        try await CustomCommandDeliveryRunner.run(
            command: preset.script,
            timeout: 10,
            context: CustomCommandDeliveryContext(transcript: input)
        ).stdout
    }

    func testPresetResults() async throws {
        let cases: [(input: String, add: String, remove: String)] = [
            ("Hello there", "Hello there. ", "Hello there"),
            ("Hello there.", "Hello there. ", "Hello there"),
            ("First one.\n\nSecond one.", "First one.\n\nSecond one. ", "First one.\n\nSecond one"),
            ("Wait… Next one", "Wait next one. ", "Wait next one"),
            ("Done...", "Done. ", "Done"),
            ("Go now — Then stop", "Go now then stop. ", "Go now then stop"),
            ("well-known fact -", "well-known fact. ", "well-known fact"),
            ("He said \"go.\"", "He said \"go.\" ", "He said \"go.\""),
            ("Is it?", "Is it? ", "Is it?"),
            ("Renée wrote café…", "Renée wrote café. ", "Renée wrote café"),
        ]
        for item in cases {
            let added = try await runPreset(.addTerminalPeriod, item.input)
            XCTAssertEqual(added, item.add, "add: \(item.input)")
            let removed = try await runPreset(.removeTerminalPeriod, item.input)
            XCTAssertEqual(removed, item.remove, "remove: \(item.input)")
        }
    }

    func testScriptOutputIsUsedExactly() async {
        let result = await PasteScriptStep.run(script: "printf 'a '", input: "input")
        XCTAssertEqual(result, PasteScriptStep.Result(text: "a ", failure: nil))
    }

    func testScriptReceivesTextOnStdinAndEnvironment() async {
        let stdin = await PasteScriptStep.run(script: "cat", input: "from input")
        XCTAssertEqual(stdin.text, "from input")
        XCTAssertNil(stdin.failure)
        let env = await PasteScriptStep.run(script: "printf %s \"$VOICEINK_TRANSCRIPT\"", input: "from input")
        XCTAssertEqual(env.text, "from input")
        XCTAssertNil(env.failure)
    }

    func testFailuresFallBackToInput() async {
        for script in ["exit 3", "printf ''", "printf '  '", "   "] {
            let result = await PasteScriptStep.run(script: script, input: "input")
            XCTAssertEqual(result.text, "input", script)
            XCTAssertNotNil(result.failure, script)
        }
    }

    func testFailureReasonNeverCarriesStderr() async {
        let result = await PasteScriptStep.run(script: "echo secret >&2; exit 1", input: "input")
        XCTAssertEqual(result.failure?.contains("secret"), false)
    }

    func testTimeoutFallsBackInAboutTwoSeconds() async {
        let start = Date()
        let result = await PasteScriptStep.run(script: "sleep 5", input: "input")
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertEqual(result.text, "input")
        XCTAssertNotNil(result.failure)
        XCTAssertGreaterThanOrEqual(elapsed, 1.9)
        XCTAssertLessThan(elapsed, 3.5)
    }

    func testSmartPunctuationAfterScript() throws {
        let cases: [(String, String, String, String)] = [
            ("It is done. ", "the next one. ", "", "The next one. "),
            ("I said ", "Hello there. ", " world", "hello there"),
            ("", "Hello there. ", "", "Hello there. "),
        ]
        for (before, inserted, after, expected) in cases {
            let context = try XCTUnwrap(
                SmartPunctuation.Context(
                    text: before + after,
                    selection: NSRange(location: before.utf16.count, length: 0)
                )
            )
            XCTAssertEqual(SmartPunctuation.adjusted(inserted, context: context, protectedWords: []), expected)
        }
    }

    @MainActor
    func testScriptEditorKeepsTypedCharactersVerbatim() throws {
        var text = ""
        let binding = Binding(get: { text }, set: { text = $0 })
        let host = NSHostingView(rootView: PlainScriptEditor(text: binding).frame(width: 300, height: 100))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 100), styleMask: .titled, backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()

        func findTextView(in view: NSView) -> NSTextView? {
            (view as? NSTextView) ?? view.subviews.lazy.compactMap(findTextView).first
        }
        let textView = try XCTUnwrap(findTextView(in: host))
        XCTAssertFalse(textView.isAutomaticQuoteSubstitutionEnabled)
        XCTAssertFalse(textView.isAutomaticDashSubstitutionEnabled)
        XCTAssertFalse(textView.isAutomaticTextReplacementEnabled)
        XCTAssertFalse(textView.isAutomaticSpellingCorrectionEnabled)

        let typed = "# test \"double\" 'single' -- ..."
        textView.insertText(typed, replacementRange: textView.selectedRange())
        XCTAssertEqual(text, typed)
    }

    func testSavedModeWithoutNewKeysDecodesToDefaults() throws {
        let json = #"{"id":"11111111-1111-1111-1111-111111111111","name":"Old","isAIEnhancementEnabled":false}"#
        let mode = try JSONDecoder().decode(ModeConfig.self, from: Data(json.utf8))
        XCTAssertFalse(mode.isPasteScriptEnabled)
        XCTAssertEqual(mode.pasteScript, "")
    }

    func testMemberwiseDefaults() {
        let mode = ModeConfig(name: "New", isAIEnhancementEnabled: false)
        XCTAssertFalse(mode.isPasteScriptEnabled)
        XCTAssertEqual(mode.pasteScript, "")
    }

    func testScriptSurvivesEncodeAndDecode() throws {
        let script = PasteScriptPreset.addTerminalPeriod.script
        let mode = ModeConfig(name: "On", isAIEnhancementEnabled: false, isPasteScriptEnabled: true, pasteScript: script)
        let decoded = try JSONDecoder().decode(ModeConfig.self, from: JSONEncoder().encode(mode))
        XCTAssertTrue(decoded.isPasteScriptEnabled)
        XCTAssertEqual(decoded.pasteScript, script)
    }

    func testValidatorRefusesBlankScriptOnlyWhenItWouldRun() {
        let validator = ModeValidator(modeManager: ModeManager.shared)
        func errors(_ enabled: Bool, _ script: String, _ output: ModeOutputMode = .paste) -> [String] {
            validator.validateForSave(
                config: ModeConfig(
                    name: "P1105-4 validator", isAIEnhancementEnabled: false, outputMode: output,
                    customCommand: ModeCustomCommand(command: "true"),
                    isPasteScriptEnabled: enabled, pasteScript: script
                ),
                mode: .add
            ).map(\.id)
        }
        XCTAssertTrue(errors(true, " \n ").contains("emptyPasteScript"))
        XCTAssertFalse(errors(true, "cat").contains("emptyPasteScript"))
        XCTAssertFalse(errors(false, "").contains("emptyPasteScript"))
        XCTAssertFalse(errors(true, "", .customCommand).contains("emptyPasteScript"))
    }
}

import Foundation

/// The optional "Script before paste" step of Paste output.
enum PasteScriptStep {
    struct Result: Equatable {
        /// The script's stdout, or the untouched input when it failed.
        let text: String
        /// A fixed reason that never carries script output, nil on success.
        let failure: String?
    }

    static func run(script: String, input: String, timeout: TimeInterval = 2) async -> Result {
        func fallback(_ reason: String) -> Result { Result(text: input, failure: reason) }

        do {
            let result = try await CustomCommandDeliveryRunner.run(
                command: script,
                timeout: timeout,
                context: CustomCommandDeliveryContext(transcript: input)
            )
            if result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return fallback(String(localized: "returned no text"))
            }
            return Result(text: result.stdout, failure: nil)
        } catch CustomCommandDeliveryError.timeout {
            return fallback(String(localized: "timed out"))
        } catch CustomCommandDeliveryError.nonZeroExit(let status, _) {
            return fallback(String(format: String(localized: "exited with status %d"), status))
        } catch {
            return fallback(String(localized: "could not start"))
        }
    }
}

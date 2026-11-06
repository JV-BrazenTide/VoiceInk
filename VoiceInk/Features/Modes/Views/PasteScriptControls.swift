import SwiftUI

struct PasteScriptControls: View {
    @Binding var isEnabled: Bool
    @Binding var script: String

    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack(spacing: 6) {
                Text("Script before paste")
                InfoTip(
                    "Runs after AI cleanup and before pasting. The text is sent on stdin and exposed as VOICEINK_TRANSCRIPT. The script's output is what gets pasted, so it must not copy or paste by itself."
                )
            }
        }

        if isEnabled {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Spacer()
                    Menu {
                        ForEach(PasteScriptPreset.allCases) { preset in
                            Button(preset.displayName) {
                                script = preset.script
                            }
                        }
                    } label: {
                        Label("Preset", systemImage: "doc.on.doc")
                    }
                    .menuStyle(.button)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                PlainScriptEditor(text: $script)
                    .frame(minHeight: 96)
                    .padding(8)
                    .background(AppTheme.Surface.control)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AppTheme.Border.control.opacity(0.4), lineWidth: 1)
                    )
            }
        }
    }
}

/// TextEditor leaves macOS smart quotes, dashes and text replacement on, and a replaced character can change what a script does.
struct PlainScriptEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .labelColor
        textView.textContainerInset = .zero
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.setAccessibilityLabel(String(localized: "Script before paste"))
        textView.string = text
        textView.delegate = context.coordinator
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        guard let textView = scrollView.documentView as? NSTextView, textView.string != text else { return }
        textView.string = text
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}

import Combine
import Foundation

/// The "VoiceInk Refine" provider: one download service per catalog model, one persisted selection,
/// and one XPC client, so only the selected model is ever resident.
final class VoiceInkRefineLibrary: ObservableObject {
    static let shared = VoiceInkRefineLibrary()
    static let selectionDefaultsKey = "VoiceInkRefineSelectedModelID"

    static func selectedModel(in defaults: UserDefaults = .standard) -> VoiceInkRefineCatalog.Model {
        let id = defaults.string(forKey: selectionDefaultsKey)
        return VoiceInkRefineCatalog.models.first { $0.id == id } ?? VoiceInkRefineCatalog.defaultModel
    }

    let services: [VoiceInkRefineService]

    @Published private(set) var selectedModelID: String
    /// True when any model is installed, so the provider stays configured in Modes
    /// and a missing selection surfaces as "not downloaded" rather than "not configured".
    @Published private(set) var isDownloaded = false

    var isAvailableInModes: Bool {
        services.contains(where: \.isAvailableInModes)
    }

    private let inferenceClient = VoiceInkRefineXPCClient()
    private var downloadStateObserver: AnyCancellable?

    private var selectedService: VoiceInkRefineService {
        services.first { $0.model.id == selectedModelID } ?? services[0]
    }

    private init() {
        let client = inferenceClient
        services = VoiceInkRefineCatalog.models.map {
            VoiceInkRefineService(model: $0, inferenceClient: client)
        }
        selectedModelID = Self.selectedModel().id
        isDownloaded = services.contains(where: \.isDownloaded)

        // @Published fires before the value changes, so read it on the next run loop pass.
        downloadStateObserver = Publishers.MergeMany(services.map { $0.$isDownloaded })
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.isDownloaded = self.services.contains(where: \.isDownloaded)
            }
    }

    @MainActor
    func select(_ model: VoiceInkRefineCatalog.Model) {
        guard model.id != selectedModelID else { return }

        UserDefaults.standard.set(model.id, forKey: Self.selectionDefaultsKey)
        selectedModelID = model.id
        NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)

        // Free the previous model now; the helper also unloads on any directory change.
        Task {
            await inferenceClient.shutdown()
        }
    }

    func enhance(transcript: String, vocabulary: RecordingVocabulary) async throws -> String {
        try await selectedService.enhance(transcript: transcript, vocabulary: vocabulary)
    }

    func prepareForRecording() async {
        await selectedService.prepareForRecording()
    }

    func unloadPreparedModelIfNeeded() async {
        await inferenceClient.shutdownPreparedModelIfNeeded()
    }

    func keepPreparedModelWarmForRecording() async {
        await inferenceClient.keepPreparedModelWarmForRecording()
    }
}

import SwiftUI

struct VoiceInkRefineModelPickerView: View {
    @ObservedObject var library: VoiceInkRefineLibrary

    var body: some View {
        ForEach(library.services, id: \.model.id) { service in
            VoiceInkRefineModelCardView(
                service: service,
                isSelected: library.selectedModelID == service.model.id,
                selectAction: { library.select(service.model) },
                deleteAction: {
                    Task {
                        await service.deleteModel()
                    }
                }
            )
        }
    }
}

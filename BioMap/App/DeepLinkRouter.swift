import SwiftUI

@MainActor
final class DeepLinkRouter: ObservableObject {
    @Published var observation: Observation?

    func handle(_ url: URL) {
        guard url.scheme == "biomap" else { return }
        if url.host == "add" {
            NotifRouter.shared.destination = .add
            return
        }
        guard url.host == "o" else { return }
        let id = url.lastPathComponent
        guard !id.isEmpty, id != "/", id != "o" else { return }
        Task {
            if let obs = await ObservationRepository.getById(id) {
                self.observation = obs
            }
        }
    }
}

import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published var payload: CompareFilesPayload?
    @Published var errorMessage: String?

    init() {
        do {
            payload = try InputLoader.load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

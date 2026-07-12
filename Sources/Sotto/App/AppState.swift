import Combine

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var monitoringEnabled = false

    private init() {}
}

import Combine

enum ModelLoadStatus {
    case notStarted
    case preparing
    case ready
    case failed(String)

    var label: String {
        switch self {
        case .notStarted:
            return "Not Started"
        case .preparing:
            return "Preparing"
        case .ready:
            return "Ready"
        case .failed:
            return "Failed"
        }
    }

    var detail: String {
        switch self {
        case .notStarted:
            return "Translation model not prepared"
        case .preparing:
            return "Preparing translation model"
        case .ready:
            return "Translation model ready"
        case let .failed(message):
            return "Model setup failed: \(message)"
        }
    }

    var systemImage: String {
        switch self {
        case .notStarted:
            return "square.and.arrow.down"
        case .preparing:
            return "arrow.down.circle"
        case .ready:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        }
    }

    var canPrepare: Bool {
        switch self {
        case .notStarted, .failed:
            return true
        case .preparing, .ready:
            return false
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var monitoringEnabled = false
    @Published var modelLoadStatus: ModelLoadStatus = .notStarted

    private init() {}
}

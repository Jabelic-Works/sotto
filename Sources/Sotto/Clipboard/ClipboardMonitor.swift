import AppKit

@MainActor
final class ClipboardMonitor {
    private let pasteboard: NSPasteboard
    private let onDoubleCopy: (String) -> Void
    private var detector = DoubleCopyDetector()
    private var lastChangeCount: Int
    private var timer: Timer?

    init(
        pasteboard: NSPasteboard = .general,
        onDoubleCopy: @escaping (String) -> Void
    ) {
        self.pasteboard = pasteboard
        self.onDoubleCopy = onDoubleCopy
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) {
            [weak self] _ in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    var isRunning: Bool {
        timer != nil
    }

    private func poll() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        guard let text = pasteboard.string(forType: .string) else { return }
        if detector.record(text: text) {
            onDoubleCopy(text)
        }
    }
}

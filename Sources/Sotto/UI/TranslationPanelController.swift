import AppKit
import SwiftUI

@MainActor
final class TranslationPanelController {
    private let panel: NSPanel

    init() {
        panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 420, height: 132),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
    }

    func show(source: String, translation: String, near anchor: CGPoint) {
        panel.contentView = NSHostingView(
            rootView: TranslationPanelView(
                source: source,
                translation: translation,
                onClose: { [weak panel] in panel?.orderOut(nil) }
            )
        )
        panel.setFrameOrigin(adjustedOrigin(near: anchor))
        panel.orderFrontRegardless()
    }

    private func adjustedOrigin(near anchor: CGPoint) -> CGPoint {
        let proposed = CGPoint(x: anchor.x, y: anchor.y - panel.frame.height)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor) }) ?? NSScreen.main else {
            return proposed
        }

        let frame = screen.visibleFrame
        return CGPoint(
            x: min(max(proposed.x, frame.minX + 12), frame.maxX - panel.frame.width - 12),
            y: min(max(proposed.y, frame.minY + 12), frame.maxY - panel.frame.height - 12)
        )
    }
}

private struct TranslationPanelView: View {
    let source: String
    let translation: String
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Sotto", systemImage: "character.bubble")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }

            Text(translation)
                .font(.body)
                .lineLimit(4)
                .textSelection(.enabled)

            Text("TranslateGemma integration coming next")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 420, height: 132, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.primary.opacity(0.08))
        }
    }
}

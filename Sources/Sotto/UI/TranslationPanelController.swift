import AppKit
import SwiftUI

@MainActor
final class TranslationPanelController {
    private let panelWidth: CGFloat = 440
    private let panel: NSPanel

    init() {
        panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 440, height: 156),
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
        panel.isReleasedWhenClosed = false
    }

    func show(source: String, translation: String, near anchor: CGPoint) {
        let size = panelSize(for: translation)
        panel.contentView = NSHostingView(
            rootView: TranslationPanelView(
                source: source,
                translation: translation,
                size: size,
                onClose: { [weak self] in self?.hide() }
            )
        )
        panel.setContentSize(size)
        panel.setFrameOrigin(adjustedOrigin(near: anchor))
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func panelSize(for translation: String) -> CGSize {
        let estimatedLines = max(1, ceil(CGFloat(translation.count) / 54))
        let contentHeight = 92 + estimatedLines * 22
        let height = min(max(contentHeight, 156), 320)
        return CGSize(width: panelWidth, height: height)
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
    let size: CGSize
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

            if source != translation {
                Text(source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            ScrollView {
                Text(translation)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("TranslateGemma integration coming next")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.primary.opacity(0.08))
        }
    }
}

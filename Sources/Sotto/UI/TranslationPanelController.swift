import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class TranslationPanelController {
    private let panelWidth: CGFloat = 440
    private let panel: NSPanel
    private var escHotKey: EscapeHotKey?

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

    func show(
        source: String,
        translation: String,
        footer: String = "TranslateGemma integration coming next",
        near anchor: CGPoint
    ) {
        let size = panelSize(source: source, translation: translation, footer: footer)
        panel.contentView = NSHostingView(
            rootView: TranslationPanelView(
                source: source,
                translation: translation,
                footer: footer,
                size: size,
                onClose: { [weak self] in self?.hide() }
            )
        )
        panel.setContentSize(size)
        panel.setFrameOrigin(adjustedOrigin(near: anchor))
        panel.orderFrontRegardless()
        startEscHotKey()
    }

    func hide() {
        stopEscHotKey()
        panel.orderOut(nil)
    }

    /// Closes the panel on Escape. The panel is non-activating so Sotto never
    /// steals focus, which means it does not receive normal keyboard events, and
    /// a global NSEvent monitor would need Accessibility/Input Monitoring
    /// permission. A Carbon global hot key catches Escape regardless of the
    /// active app and needs no permission. It is registered only while the panel
    /// is visible, so Escape behaves normally otherwise.
    private func startEscHotKey() {
        guard escHotKey == nil else { return }
        escHotKey = EscapeHotKey { [weak self] in self?.hide() }
    }

    private func stopEscHotKey() {
        escHotKey = nil
    }

    private func panelSize(source: String, translation: String, footer: String) -> CGSize {
        let translationLines = max(1, ceil(CGFloat(translation.count) / 54))
        let sourceLines: CGFloat = source == translation ? 0 : min(2, ceil(CGFloat(source.count) / 68))
        let footerLines = max(1, ceil(CGFloat(footer.count) / 70))
        let contentHeight = 92 + translationLines * 22 + sourceLines * 18 + footerLines * 16
        let height = min(max(contentHeight, 156), 320)
        return CGSize(width: panelWidth, height: height)
    }

    private func adjustedOrigin(near anchor: CGPoint) -> CGPoint {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor) }) ?? NSScreen.main else {
            return CGPoint(x: anchor.x - panel.frame.width / 2, y: anchor.y - panel.frame.height - 10)
        }

        let frame = screen.visibleFrame
        let horizontalOrigin = min(
            max(anchor.x - panel.frame.width / 2, frame.minX + 12),
            frame.maxX - panel.frame.width - 12
        )
        let belowOrigin = anchor.y - panel.frame.height - 10
        let aboveOrigin = anchor.y + 18
        let verticalOrigin = belowOrigin >= frame.minY + 12 ? belowOrigin : aboveOrigin

        return CGPoint(
            x: horizontalOrigin,
            y: min(max(verticalOrigin, frame.minY + 12), frame.maxY - panel.frame.height - 12)
        )
    }
}

private struct TranslationPanelView: View {
    let source: String
    let translation: String
    let footer: String
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

            Text(footer)
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

/// A Carbon global hot key bound to the Escape key. It fires regardless of the
/// active application and needs no Accessibility or Input Monitoring permission.
/// The hot key lives only for the lifetime of this object, so callers register
/// it while a panel is visible and release it to restore normal Escape behavior.
private final class EscapeHotKey: @unchecked Sendable {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let onPress: @MainActor () -> Void

    init(onPress: @escaping @MainActor () -> Void) {
        self.onPress = onPress
        install()
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    private func install() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let context = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let hotKey = Unmanaged<EscapeHotKey>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated { hotKey.onPress() }
                return noErr
            },
            1,
            &eventType,
            context,
            &handlerRef
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x53_54_54_4F), id: 1) // 'STTO'
        let status = RegisterEventHotKey(
            UInt32(kVK_Escape),
            0,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        assert(status == noErr, "Failed to register Escape hot key: \(status)")
    }
}

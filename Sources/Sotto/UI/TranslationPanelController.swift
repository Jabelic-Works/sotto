import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class TranslationPanelController {
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
        // Size and position against the same screen (the one holding the anchor)
        // so a panel shown on a smaller secondary display is clamped to fit it
        // rather than clamped to the main display and pushed offscreen.
        let screen = targetScreen(for: anchor)
        let size = panelSize(source: source, translation: translation, footer: footer, on: screen)
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
        panel.setFrameOrigin(adjustedOrigin(near: anchor, on: screen))
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

    /// Sizes the panel to its content: the width grows to fit the longest line
    /// and the height to fit all text, both clamped to the given screen's visible
    /// frame. Text beyond the clamp scrolls inside the panel.
    private func panelSize(
        source: String,
        translation: String,
        footer: String,
        on screen: NSScreen?
    ) -> CGSize {
        let horizontalPadding: CGFloat = 28 // 14pt on each side
        let verticalPadding: CGFloat = 28
        let spacing: CGFloat = 10
        let headerHeight: CGFloat = 26

        let visible = (screen ?? NSScreen.main ?? NSScreen.screens.first)?.visibleFrame.size
        let bounds = TranslationPanelLayout.Bounds(
            maxWidth: min(620, (visible?.width ?? 1200) - 24),
            maxHeight: min(560, (visible?.height ?? 800) - 24)
        )

        let bodyFont = NSFont.preferredFont(forTextStyle: .body)
        let captionFont = NSFont.preferredFont(forTextStyle: .caption1)
        let showsSource = source != translation

        let maxContentWidth = bounds.maxWidth - horizontalPadding

        // The longest natural (unwrapped) line drives the panel width.
        let translationNaturalWidth = Self.measuredSize(translation, font: bodyFont, maxWidth: .greatestFiniteMagnitude).width
        let sourceNaturalWidth = showsSource ? Self.measuredSize(source, font: captionFont, maxWidth: .greatestFiniteMagnitude).width : 0
        let footerNaturalWidth = Self.measuredSize(footer, font: captionFont, maxWidth: .greatestFiniteMagnitude).width
        let headerMinWidth: CGFloat = 150

        let widestContent = max(translationNaturalWidth, sourceNaturalWidth, footerNaturalWidth, headerMinWidth)
        let contentWidth = min(max(widestContent, TranslationPanelLayout.minSize.width - horizontalPadding), maxContentWidth)

        // Wrapped heights at the resolved content width.
        let translationHeight = Self.measuredSize(translation, font: bodyFont, maxWidth: contentWidth).height
        let sourceHeight = showsSource ? Self.measuredSize(source, font: captionFont, maxWidth: contentWidth).height + spacing : 0
        let footerHeight = Self.measuredSize(footer, font: captionFont, maxWidth: contentWidth).height

        let contentHeight = verticalPadding + headerHeight + spacing
            + sourceHeight + translationHeight + spacing + footerHeight

        return TranslationPanelLayout.clamp(
            width: contentWidth + horizontalPadding,
            height: contentHeight,
            in: bounds
        )
    }

    private static func measuredSize(_ text: String, font: NSFont, maxWidth: CGFloat) -> CGSize {
        guard !text.isEmpty else { return .zero }
        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        let rect = attributed.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return CGSize(width: ceil(rect.width), height: ceil(rect.height))
    }

    /// The screen that contains the anchor, falling back to the main screen.
    private func targetScreen(for anchor: CGPoint) -> NSScreen? {
        NSScreen.screens.first(where: { $0.frame.contains(anchor) }) ?? NSScreen.main
    }

    private func adjustedOrigin(near anchor: CGPoint, on screen: NSScreen?) -> CGPoint {
        guard let screen else {
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

/// Pure sizing math for the translation panel, kept separate from AppKit text
/// measurement so it can be unit tested.
enum TranslationPanelLayout {
    static let minSize = CGSize(width: 320, height: 140)

    struct Bounds {
        let maxWidth: CGFloat
        let maxHeight: CGFloat
    }

    static func clamp(width: CGFloat, height: CGFloat, in bounds: Bounds) -> CGSize {
        CGSize(
            width: min(max(width, minSize.width), max(bounds.maxWidth, minSize.width)),
            height: min(max(height, minSize.height), max(bounds.maxHeight, minSize.height))
        )
    }
}

private struct TranslationPanelView: View {
    let source: String
    let translation: String
    let footer: String
    let size: CGSize
    let onClose: () -> Void

    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Label("Sotto", systemImage: "character.bubble")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help("Close")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if source != translation {
                        Text(source)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(translation)
                        .font(.body)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: copyTranslation) {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(didCopy ? Color.green : Color.primary)
                }
                .buttonStyle(.plain)
                .help("Copy translation")
                .accessibilityLabel(didCopy ? "Copied" : "Copy translation")
            }
        }
        .padding(14)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.primary.opacity(0.08))
        }
        .task(id: didCopy) {
            guard didCopy else { return }
            try? await Task.sleep(for: .seconds(1.5))
            didCopy = false
        }
    }

    /// Copies the translation to the general pasteboard. A single write does not
    /// re-trigger the double-copy monitor, which requires the same text twice in
    /// quick succession.
    private func copyTranslation() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(translation, forType: .string)
        didCopy = true
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

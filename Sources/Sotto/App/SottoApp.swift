import AppKit
import SwiftUI

@main
struct SottoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var accessibilityTrusted = SelectionLocator.isTrusted

    var body: some Scene {
        MenuBarExtra("Sotto", systemImage: "character.bubble") {
            Label(
                accessibilityTrusted ? "Accessibility: Allowed" : "Accessibility: Not Allowed",
                systemImage: accessibilityTrusted ? "checkmark.circle" : "exclamationmark.triangle"
            )
            Divider()
            Button("Request Accessibility Permission") {
                appDelegate.requestAccessibilityPermission()
                refreshAccessibilityStatus(after: 0.5)
            }
            Button("Open Accessibility Settings") {
                appDelegate.openAccessibilitySettings()
            }
            Button("Refresh Permission Status") {
                refreshAccessibilityStatus()
            }
            Divider()
            Button("Quit Sotto") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    private func refreshAccessibilityStatus(after delay: TimeInterval = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            accessibilityTrusted = SelectionLocator.isTrusted
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let panelController = TranslationPanelController()
    private var clipboardMonitor: ClipboardMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        clipboardMonitor = ClipboardMonitor { [weak self] text in
            self?.translate(text)
        }
        clipboardMonitor?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stop()
    }

    func requestAccessibilityPermission() {
        SelectionLocator.requestPermission()
    }

    func openAccessibilitySettings() {
        SelectionLocator.openPermissionSettings()
    }

    private func translate(_ source: String) {
        let anchor = SelectionLocator.selectionAnchor() ?? NSEvent.mouseLocation
        panelController.show(source: source, translation: source, near: anchor)
    }
}

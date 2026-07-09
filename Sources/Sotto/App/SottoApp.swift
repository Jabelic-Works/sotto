import AppKit
import SwiftUI

@main
struct SottoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Sotto", systemImage: "character.bubble") {
            Button("Check Accessibility Permission") {
                appDelegate.requestAccessibilityPermission()
            }
            Divider()
            Button("Quit Sotto") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
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

    private func translate(_ source: String) {
        let anchor = SelectionLocator.selectionAnchor() ?? NSEvent.mouseLocation
        panelController.show(source: source, translation: source, near: anchor)
    }
}

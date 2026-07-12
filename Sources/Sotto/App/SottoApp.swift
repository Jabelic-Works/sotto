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
            Button("Show Test Popup") {
                appDelegate.showLaunchPanel()
            }
            Divider()
            Button("Hide Translation") {
                appDelegate.hideTranslation()
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
    private let translationEngine: TranslationEngine = EchoTranslationEngine()
    private var clipboardMonitor: ClipboardMonitor?
    private var translationTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        clipboardMonitor = ClipboardMonitor { [weak self] text in
            self?.translate(text)
        }
        clipboardMonitor?.start()

        showLaunchPanel()
    }

    func applicationWillTerminate(_ notification: Notification) {
        translationTask?.cancel()
        clipboardMonitor?.stop()
    }

    func requestAccessibilityPermission() {
        SelectionLocator.requestPermission()
    }

    func openAccessibilitySettings() {
        SelectionLocator.openPermissionSettings()
    }

    func hideTranslation() {
        translationTask?.cancel()
        panelController.hide()
    }

    func showLaunchPanel() {
        panelController.show(
            source: "Sotto",
            translation: "Sotto is running",
            footer: "Select text and press Command+C twice",
            near: NSEvent.mouseLocation
        )
    }

    private func translate(_ source: String) {
        let anchor = SelectionLocator.selectionAnchor() ?? NSEvent.mouseLocation
        translationTask?.cancel()
        panelController.show(
            source: source,
            translation: "Translating...",
            footer: "Preparing local translation",
            near: anchor
        )

        let engine = translationEngine
        translationTask = Task { [weak self] in
            do {
                let translation = try await engine.translate(source, targetLanguage: "Japanese")
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self?.panelController.show(
                        source: source,
                        translation: translation,
                        footer: "Echo engine placeholder",
                        near: anchor
                    )
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self?.panelController.show(
                        source: source,
                        translation: "Translation failed",
                        footer: error.localizedDescription,
                        near: anchor
                    )
                }
            }
        }
    }
}

import AppKit
import SwiftUI

@main
@MainActor
struct SottoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared
    @State private var accessibilityTrusted = SelectionLocator.isTrusted

    var body: some Scene {
        MenuBarExtra("Sotto", systemImage: "character.bubble") {
            Label(
                appState.monitoringEnabled ? "Double-Copy: On" : "Double-Copy: Off",
                systemImage: appState.monitoringEnabled ? "dot.radiowaves.left.and.right" : "pause.circle"
            )
            Label(
                accessibilityTrusted ? "Accessibility: Allowed" : "Accessibility: Not Allowed",
                systemImage: accessibilityTrusted ? "checkmark.circle" : "exclamationmark.triangle"
            )
            Divider()
            Button(appState.monitoringEnabled ? "Pause Double-Copy Trigger" : "Resume Double-Copy Trigger") {
                appDelegate.setMonitoringEnabled(!appState.monitoringEnabled)
            }
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
    private let appState = AppState.shared
    private let panelController = TranslationPanelController()
    private let translationEngine: TranslationEngine = LocalServerTranslationEngine()
    private var clipboardMonitor: ClipboardMonitor?
    private var translationTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        clipboardMonitor = ClipboardMonitor { [weak self] text in
            self?.translate(text)
        }
        setMonitoringEnabled(true)

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

    func setMonitoringEnabled(_ enabled: Bool) {
        if enabled {
            clipboardMonitor?.start()
        } else {
            clipboardMonitor?.stop()
        }

        appState.monitoringEnabled = clipboardMonitor?.isRunning ?? false
    }

    func showLaunchPanel() {
        panelController.show(
            source: "Sotto",
            translation: "Sotto is running",
            footer: appState.monitoringEnabled
                ? "Select text and press Command+C twice"
                : "Double-copy trigger is paused",
            near: NSEvent.mouseLocation
        )
    }

    private func translate(_ source: String) {
        let anchor = SelectionLocator.resolvedAnchor()
        translationTask?.cancel()
        panelController.show(
            source: source,
            translation: "Translating...",
            footer: footer(for: anchor.source, status: "Preparing local translation"),
            near: anchor.point
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
                        footer: self?.footer(for: anchor.source, status: "Translated locally")
                            ?? "Translated locally",
                        near: anchor.point
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
                        footer: self?.footer(for: anchor.source, status: error.localizedDescription)
                            ?? error.localizedDescription,
                        near: anchor.point
                    )
                }
            }
        }
    }

    private func footer(for source: SelectionAnchor.Source, status: String) -> String {
        switch source {
        case .selection:
            return status
        case let .mouseFallback(reason):
            return "\(status) · Mouse fallback: \(reason)"
        }
    }
}

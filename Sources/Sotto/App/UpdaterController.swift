import Combine
import Sparkle
import SwiftUI

/// Wraps Sparkle's standard updater so the menu bar can offer "Check for
/// Updates…". The updater is only started when the bundle is configured for it
/// (the packaged `.app`, which carries `SUFeedURL` in its Info.plist); under
/// `swift run` there is no feed, so it stays inert and the menu item is disabled.
@MainActor
final class UpdaterController: ObservableObject {
    static let shared = UpdaterController()

    private let controller: SPUStandardUpdaterController
    @Published private(set) var canCheckForUpdates = false

    private init() {
        let isConfigured = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil
        controller = SPUStandardUpdaterController(
            startingUpdater: isConfigured,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        guard isConfigured else { return }
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)
    }

    /// Shows Sparkle's update UI: checks the feed and, if a newer version is
    /// available, downloads and installs it, then relaunches.
    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}

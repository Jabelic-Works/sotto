import Foundation

/// The app's user-facing version string, e.g. "0.3.0 (3)".
enum AppVersion {
    /// Formats a short version and build number for display. Falls back to
    /// "dev" when neither is present (e.g. running the bare `swift run` binary,
    /// which has no bundle Info.plist).
    static func label(shortVersion: String?, build: String?) -> String {
        switch (shortVersion, build) {
        case let (short?, build?):
            return "\(short) (\(build))"
        case let (short?, nil):
            return short
        case (nil, _):
            return "dev"
        }
    }

    static var current: String {
        label(
            shortVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
    }
}

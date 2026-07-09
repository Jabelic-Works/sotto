import Foundation

struct DoubleCopyDetector {
    let maximumInterval: TimeInterval

    private var previousText: String?
    private var previousDate: Date?

    init(maximumInterval: TimeInterval = 0.8) {
        self.maximumInterval = maximumInterval
    }

    mutating func record(text: String, at date: Date = Date()) -> Bool {
        guard
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            text == previousText,
            let previousCopyDate = previousDate,
            date.timeIntervalSince(previousCopyDate) <= maximumInterval
        else {
            previousText = text
            previousDate = date
            return false
        }

        previousText = nil
        previousDate = nil
        return true
    }
}

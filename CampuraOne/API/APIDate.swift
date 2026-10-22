import Foundation

/// The server stores timezone-free MySQL dates in Asia/Shanghai.
/// ISO 8601 values with Z/an offset already describe an absolute instant.
nonisolated enum APIDate {
    static func parse(_ text: String?) -> Date? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: text) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: text) { return date }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.isLenient = false
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss",
                       "yyyy-MM-dd", "yyyy/MM/dd HH:mm:ss", "yyyy/MM/dd"] {
            formatter.dateFormat = format
            // Reject impossible dates instead of silently normalizing them.
            if let date = formatter.date(from: text), formatter.string(from: date) == text {
                return date
            }
        }
        return nil
    }
}

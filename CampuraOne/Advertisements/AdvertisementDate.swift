import Foundation

/// MySQL advertisement DATETIME values use the server's Asia/Shanghai time zone.
/// Offset-bearing ISO dates already represent an absolute instant.
nonisolated enum AdvertisementDate {
    static func parse(_ text: String?) -> Date? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let value = iso.date(from: text) { return value }
        iso.formatOptions = [.withInternetDateTime]
        if let value = iso.date(from: text) { return value }
        let sql = DateFormatter()
        sql.locale = Locale(identifier: "en_US_POSIX")
        sql.calendar = Calendar(identifier: .gregorian)
        sql.timeZone = TimeZone(identifier: "Asia/Shanghai")
        sql.dateFormat = "yyyy-MM-dd HH:mm:ss"
        sql.isLenient = false
        guard let value = sql.date(from: text), sql.string(from: value) == text else { return nil }
        return value
    }
}

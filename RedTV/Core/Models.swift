import Foundation

// Go encodes nil slices as null. Treat missing/null collections as empty,
// while still failing on malformed elements instead of losing their contents.
@propertyWrapper struct DefaultArray<Element: Codable>: Codable {
    var wrappedValue: [Element] = []
    init(wrappedValue: [Element] = []) { self.wrappedValue = wrappedValue }
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        wrappedValue = container.decodeNil() ? [] : try container.decode([Element].self)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

extension KeyedDecodingContainer {
    func decode<T>(_ type: DefaultArray<T>.Type, forKey key: Key) throws -> DefaultArray<T> {
        try decodeIfPresent(type, forKey: key) ?? DefaultArray()
    }
}

struct Article: Codable, Identifiable {
    let id: Int
    let source: String
    let sourceUrl: String
    let imageUrl: String
    let title: String
    let summary: String
    let titleZh: String
    let summaryZh: String
    let body: String
    let bodyZh: String
    let publishedAt: String
    var bodyFetchError: String?
    var bodyTranslationError: String?
    var category: String?
    var section: String?
    var sectionLabel: String?
    var heatScore: Double?
    var displayTitle: String { titleZh.isEmpty ? title : titleZh }
    var displaySummary: String { summaryZh.isEmpty ? summary : summaryZh }
    var path: String { "/article/\(id)" }
    var libraryItem: SavedItem { SavedItem(path: path, title: displayTitle, source: source, kind: "article") }
}

struct ContentSection: Codable, Identifiable {
    let id: String
    let label: String
    let category: String
}

struct Dashboard: Codable {
    @DefaultArray var worldArticles: [Article]
    @DefaultArray var newsFeed: [Article]
    init(bbcArticles: [Article]) { worldArticles = bbcArticles }
    var feed: [Article] { (newsFeed.isEmpty ? worldArticles : newsFeed).filter { $0.source.lowercased() == "bbc" } }
}

struct User: Codable, Identifiable {
    let id: Int
    let username: String
    let displayName: String
    let role: String
    let createdAt: String
}
struct UserResponse: Codable { let user: User? }
struct Acknowledgement: Codable { var ok: Bool?; var counted: Bool? }
enum RedDate {
    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }
    static func parse(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
    static func display(_ value: String?, time: Bool = false, utc: Bool = false) -> String {
        guard let value, let date = parse(value), !value.hasPrefix("0001-") else { return "待更新" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        if utc { formatter.timeZone = TimeZone(secondsFromGMT: 0) }
        formatter.dateFormat = time ? "M月d日 HH:mm" : "yyyy.MM.dd"
        return formatter.string(from: date)
    }
}

func sourceName(_ value: String) -> String {
    ["bbc": "BBC", "hltv": "HLTV", "steam": "Steam", "baidu": "百度", "weibo": "微博", "tieba": "贴吧", "hupu": "虎扑", "xiaohongshu": "小红书", "valve": "Valve VRS"][value] ?? value
}


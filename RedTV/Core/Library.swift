import Foundation

struct SavedItem: Codable, Identifiable {
    let path: String
    let title: String
    let source: String
    let kind: String
    var savedAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    var id: String { path }
}

enum LibraryKind: String, CaseIterable, Identifiable {
    case bookmarks, history, follows
    var id: Self { self }
    var label: String {
        switch self { case .bookmarks: "收藏"; case .history: "足迹"; case .follows: "关注" }
    }
    var icon: String {
        switch self { case .bookmarks: "bookmark"; case .history: "clock"; case .follows: "star" }
    }
}

struct ReadingLibrary: Codable {
    @DefaultArray var bookmarks: [SavedItem]
    @DefaultArray var history: [SavedItem]
    @DefaultArray var follows: [SavedItem]
    @DefaultArray var searches: [String]
    var removed: [String: Int64]?

    init() { removed = [:] }
    subscript(kind: LibraryKind) -> [SavedItem] {
        get {
            switch kind { case .bookmarks: bookmarks; case .history: history; case .follows: follows }
        }
        set {
            switch kind { case .bookmarks: bookmarks = newValue; case .history: history = newValue; case .follows: follows = newValue }
        }
    }
    func merging(_ other: ReadingLibrary) -> ReadingLibrary {
        var result = ReadingLibrary()
        var tombstones = removed ?? [:]
        for (key, stamp) in other.removed ?? [:] { tombstones[key] = max(tombstones[key] ?? 0, stamp) }
        result.removed = Dictionary(uniqueKeysWithValues: tombstones.sorted { $0.value > $1.value }.prefix(400).map { ($0.key, $0.value) })
        for kind in LibraryKind.allCases {
            var seen = Set<String>()
            result[kind] = (self[kind] + other[kind]).sorted { $0.savedAt > $1.savedAt }.filter { item in
                guard let route = Route(path: item.path), route.isSavable,
                      item.savedAt > (tombstones["\(kind.rawValue):\(item.path)"] ?? 0) else { return false }
                return seen.insert(item.path).inserted
            }.prefix(kind == .bookmarks ? 200 : 100).map {
                SavedItem(path: $0.path, title: String($0.title.prefix(500)), source: String($0.source.prefix(40)), kind: String($0.kind.prefix(30)), savedAt: $0.savedAt)
            }
        }
        var seen = Set<String>()
        result.searches = (searches + other.searches).map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)) }.filter { $0.count >= 2 && seen.insert($0).inserted }.prefix(8).map { $0 }
        return result
    }
}


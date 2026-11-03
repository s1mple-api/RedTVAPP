import Foundation

enum Route: Hashable {
    case article(Int), arenaMatch(Int), arenaEvent(Int), arenaTeam(Int), arenaPlayer(Int)
    case news, search, account, library, settings, about, follows
    case legacy(String)
    init?(path: String) {
        let parts = path.split(separator: "/").map(String.init)
        switch parts {
        case ["news"]: self = .news
        case ["search"]: self = .search
        case ["account"]: self = .account
        case ["library"]: self = .library
        case ["about"]: self = .about
        default:
            if parts.count == 2, parts[0] == "article", let id = Int(parts[1]), id > 0 { self = .article(id) }
            else if parts.count == 3, parts[0] == "wanmei", let id = Int(parts[2]), id > 0 {
                switch parts[1] {
                case "matches": self = .arenaMatch(id)
                case "events": self = .arenaEvent(id)
                case "teams": self = .arenaTeam(id)
                case "players": self = .arenaPlayer(id)
                default: return nil
                }
            } else if Self.validLegacy(parts) { self = .legacy("/" + parts.joined(separator: "/")) }
            else { return nil }
        }
    }
    private static func validLegacy(_ p: [String]) -> Bool {
        if p.count == 1 { return ["community", "cs2", "trending", "topics"].contains(p[0]) }
        if p.count == 2, p[0] == "player" { return (Int(p[1]) ?? 0) > 0 }
        if p.count == 3, p[0] == "cs2", ["events", "teams"].contains(p[1]) { return (Int(p[2]) ?? 0) > 0 }
        if p.count == 2, p[0] == "topics" { return p[1].range(of: "^[a-z0-9-]+$", options: .regularExpression) != nil }
        let key: (String) -> Bool = { $0.range(of: "^[a-f0-9]{24}$", options: .regularExpression) != nil }
        return (p.count == 2 && ["topic", "post"].contains(p[0]) && key(p[1])) || (p.count == 4 && p[0] == "topic" && key(p[1]) && p[2] == "post" && key(p[3]))
    }
    var isSavable: Bool {
        switch self { case .article, .arenaMatch, .arenaEvent, .arenaTeam, .arenaPlayer, .legacy, .news: true; default: false }
    }
}

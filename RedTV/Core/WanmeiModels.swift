import Foundation

// The public website mixes numeric IDs, numeric strings and nullable values.
// Decode their transport shape once, then expose stable native models.
enum ArenaJSON: Codable {
    case object([String: ArenaJSON]), array([ArenaJSON]), string(String), integer(Int64), number(Double), boolean(Bool), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .boolean(v) }
        else if let v = try? c.decode(Int64.self) { self = .integer(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([String: ArenaJSON].self) { self = .object(v) }
        else { self = .array(try c.decode([ArenaJSON].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .integer(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .boolean(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
    subscript(_ key: String) -> ArenaJSON { if case let .object(v) = self { return v[key] ?? .null }; return .null }
    var array: [ArenaJSON] { if case let .array(v) = self { return v }; return [] }
    var text: String {
        switch self { case .string(let v): v; case .integer(let v): String(v); case .number(let v): String(v); default: "" }
    }
    var number: Double? {
        switch self { case .integer(let v): Double(v); case .number(let v): v; case .string(let v): Double(v); default: nil }
    }
    var int: Int? { number.flatMap { $0.isFinite && $0 >= Double(Int.min) && $0 < Double(Int.max) ? Int($0) : nil } }
    var bool: Bool { if case let .boolean(v) = self { return v }; return int == 1 }
    var exists: Bool { if case .null = self { return false }; return true }
    func firstText(_ keys: String...) -> String { keys.lazy.map { self[$0].text }.first { !$0.isEmpty } ?? "" }
}

enum ArenaDate {
    static let timeZone = TimeZone(identifier: "Asia/Shanghai")!
    static var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = timeZone; c.firstWeekday = 2; return c }
    static func date(_ milliseconds: Double?) -> Date? { milliseconds.flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0 / 1000) : nil } }
    static func format(_ date: Date?, pattern: String = "MM.dd HH:mm") -> String {
        guard let date else { return "待定" }
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.timeZone = timeZone; f.dateFormat = pattern
        return f.string(from: date)
    }
    static func dayKey(_ date: Date) -> String { format(date, pattern: "yyyy-MM-dd") }
}

struct ArenaPlayer: Codable, Identifiable {
    let id: Int
    let name: String
    let image: String
    let teamID: Int?
    let teamName: String
    let country: String
    let rating: Double?
    let kd: Double?
    let maps: Int?
    let coach: Bool
    init(_ raw: ArenaJSON) {
        id = raw["playerId"].int ?? raw["hltvId"].int ?? raw["id"].int ?? 0
        name = raw.firstText("playerName", "name")
        image = raw.firstText("playerLogo", "playerImage", "image", "logo")
        teamID = raw["teamId"].int; teamName = raw["teamName"].text; country = raw["country"].text
        rating = raw["impactRating"].number ?? raw["rating"].number
        kd = raw["kdRatio"].number; maps = raw["mapsPlayed"].int ?? raw["maps"].int; coach = raw["coach"].bool
    }
}

struct ArenaTeam: Codable, Identifiable {
    let id: Int
    let name: String
    let logo: String
    let lightLogo: String
    let rank: Int?
    let points: Double?
    let change: Int?
    let hltvRank: Int?
    let hltvPoints: Double?
    let players: [ArenaPlayer]
    init(_ raw: ArenaJSON) {
        // newRankList's teamId is Nami; hltvId identifies the detail route.
        id = raw["hltvId"].int ?? raw["teamId"].int ?? 0
        name = raw.firstText("teamName", "name")
        logo = raw.firstText("teamLogo", "logoWhite", "whiteLogo", "logo", "teamLogoBlack", "logoBlack")
        lightLogo = raw.firstText("teamLogoBlack", "logoBlack", "logo", "teamLogo", "logoWhite", "whiteLogo")
        rank = raw["rank"].int
        points = raw["score"].number; change = raw["rankingChanges"].int
        hltvRank = raw["hltvRank"].int; hltvPoints = raw["hltvScore"].number
        let roster = raw["playerDTOList"].exists ? raw["playerDTOList"] : raw["playerList"].exists ? raw["playerList"] : raw["players"]
        players = roster.array.filter { !$0["status"].exists || $0["status"].int == 1 || $0["coach"].bool }.map(ArenaPlayer.init).filter { $0.id > 0 }
    }
}

struct ArenaEvent: Codable, Identifiable {
    let id: Int
    let type: Int
    let name: String
    let englishName: String
    let logo: String
    let banner: String
    let prize: String
    let location: String
    let tier: String
    let status: Int
    let start: Date?
    let end: Date?
    let teamCount: Int
    let teams: [ArenaTeam]
    init(_ raw: ArenaJSON) {
        id = raw["eventId"].int ?? raw["id"].int ?? 0; type = raw["eventType"].int ?? 1
        name = raw.firstText("nameZh", "name"); englishName = raw["name"].text
        logo = raw["logo"].text; banner = raw.firstText("thumbnail", "background")
        prize = raw["prize"].text; location = raw["regionDTO"].firstText("locationCn", "location")
        tier = raw["level"].text; status = raw["status"].int ?? 0
        start = ArenaDate.date(raw["startTime"].number); end = ArenaDate.date(raw["endTime"].number)
        teams = raw["teamDTOList"].array.map(ArenaTeam.init).filter { $0.id > 0 }
        teamCount = raw["teamNumber"].int ?? teams.count
    }
    var stateLabel: String { status == 1 ? "进行中" : status == 2 ? "即将开始" : status == 3 ? "已结束" : "赛程待定" }
    var dateRange: String { "\(ArenaDate.format(start, pattern: "MM.dd")) – \(ArenaDate.format(end, pattern: "MM.dd"))" }
    var sourceURL: URL { URL(string: "https://data.wanmei.com/csgo/events/overview/\(id)?type=\(type)")! }
}

struct ArenaMatch: Codable, Identifiable {
    let id: Int
    let namiID: Int?
    let eventID: Int
    let eventType: Int
    let eventName: String
    let eventLogo: String
    let team1: ArenaTeam
    let team2: ArenaTeam
    let score1: Int?
    let score2: Int?
    let status: Int
    let start: Date?
    let bestOf: String
    let stage: String
    let stars: Int
    init(_ raw: ArenaJSON) {
        id = raw["matchId"].int ?? raw["id"].int ?? 0; namiID = raw["namiMatchId"].int
        eventID = raw["eventId"].int ?? 0; eventType = raw["csgoEventDTO"]["eventType"].int ?? 1
        eventName = raw["csgoEventDTO"].firstText("nameZh", "name"); eventLogo = raw["csgoEventDTO"]["logo"].text
        team1 = ArenaTeam(raw["team1DTO"]); team2 = ArenaTeam(raw["team2DTO"])
        status = raw["status"].int ?? 0
        // A scheduled fixture's upstream zero scores do not indicate a result.
        score1 = status == 1 || status == 3 ? raw["score1"].int : nil
        score2 = status == 1 || status == 3 ? raw["score2"].int : nil
        start = ArenaDate.date(raw["startTime"].number); bestOf = raw["bo"].text.uppercased()
        stage = raw["stageName"].text; stars = raw["star"].int ?? 0
    }
    var stateLabel: String { status == 1 ? "进行中" : status == 2 ? "未开始" : status == 3 ? "已结束" : "赛程待定" }
    var title: String { "\(team1.name.isEmpty ? "待定" : team1.name) vs \(team2.name.isEmpty ? "待定" : team2.name)" }
    var sourceURL: URL { URL(string: "https://data.wanmei.com/csgo/match/\(id)")! }
}

struct ArenaPlayerLine: Codable, Identifiable {
    let player: ArenaPlayer
    let kills: Int?
    let deaths: Int?
    let adr: Double?
    let rating: Double?
    var id: Int { player.id }
    init(_ raw: ArenaJSON) {
        player = ArenaPlayer(raw["playerDTO"])
        kills = raw["kills"].int; deaths = raw["deaths"].int
        adr = raw["adr"].number; rating = raw["rating"].number
    }
}
struct ArenaMap: Codable, Identifiable {
    let id: String
    let name: String
    let image: String
    let score1: Int?
    let score2: Int?
    let left: [ArenaPlayerLine]
    let right: [ArenaPlayerLine]
    init(_ raw: ArenaJSON, index: Int) {
        id = "\(raw["statsId"].text)-\(index)"; name = raw["mapDTO"].firstText("nameZh", "nameEn")
        image = raw["mapDTO"]["image"].text
        score1 = raw["score1"].int; score2 = raw["score2"].int
        left = raw["team1PlayerStatsDTOList"].array.map(ArenaPlayerLine.init)
        right = raw["team2PlayerStatsDTOList"].array.map(ArenaPlayerLine.init)
    }
}
struct ArenaMatchDetail {
    let match: ArenaMatch
    let maps: [ArenaMap]
    init(_ raw: ArenaJSON) {
        let match = raw["match"].exists ? raw["match"] : raw
        self.match = ArenaMatch(match)
        maps = match["statsDTOList"].array.enumerated().map { ArenaMap($0.element, index: $0.offset) }
    }
}
struct ArenaPlayerProfile {
    let player: ArenaPlayer
    let realName: String
    let ratingLabel: String
    let rating: String
    let metrics: [(String, String)]
    let honors: [(String, String)]
    init(_ raw: ArenaJSON) {
        var info = raw["basicInfo"]
        if case var .object(fields) = info, fields["playerId"]?.int == nil {
            fields["playerId"] = raw["playerId"]; info = .object(fields)
        }
        let avg = raw["player_avg_data"]
        player = ArenaPlayer(info); realName = info["realName"].text
        ratingLabel = avg["Rating"]["desc"].text
        rating = avg["Rating"]["score"].text
        metrics = [("ADR", avg["ADR"]["score"].text), ("KAST", avg["KAST"]["score"].text), ("KPR", avg["KPR"]["score"].text), ("每回合影响", avg["Round_Swing"]["score"].text)]
        honors = info["honorList"].array.prefix(8).map { ($0["name"].text, ArenaDate.format(ArenaDate.date($0["timestamp"].number), pattern: "yyyy.MM")) }
    }
}
struct ArenaPage<Item> { let items: [Item]; let total: Int; let page: Int; let hasMore: Bool }
struct ArenaResult<Value> {
    let value: Value
    let fetchedAt: Date
    let cached: Bool
    func map<T>(_ transform: (Value) -> T) -> ArenaResult<T> { ArenaResult<T>(value: transform(value), fetchedAt: fetchedAt, cached: cached) }
}

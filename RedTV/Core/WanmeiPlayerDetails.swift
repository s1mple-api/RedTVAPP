import Foundation

struct ArenaPlayerDimension: Identifiable {
    let id: String
    let name: String
    let value: Double?
    let rawValue: String
}

struct ArenaTop20Entry: Identifiable {
    let year: Int
    let rank: Int
    var id: Int { year }
    init?(_ text: String) {
        let parts = text.replacingOccurrences(of: "#", with: "").split(whereSeparator: { $0.isWhitespace }).compactMap { Int($0) }
        guard parts.count >= 2, (1...20).contains(parts[0]) else { return nil }
        let year = parts[1] < 100 ? 2000 + parts[1] : parts[1]
        guard (2000...2100).contains(year) else { return nil }
        self.year = year; rank = parts[0]
    }
}

struct ArenaPlayerDetailData {
    let profile: ArenaPlayerProfile
    let prize: String
    let mapCount: Int?
    let majorMVP: String
    let majorWins: String
    let top20: [ArenaTop20Entry]
    let dimensions: [ArenaPlayerDimension]
    let sideRatings: [(String, String)]
    init(_ raw: ArenaJSON) {
        profile = ArenaPlayerProfile(raw)
        let info = raw["basicInfo"]
        prize = info["prize"].text; mapCount = raw["map_count"].int
        majorMVP = info["achievements"]["major_mvp"].text
        majorWins = info["achievements"]["major_winner"].text
        top20 = info["top20"].array.compactMap { ArenaTop20Entry($0.text) }.sorted { $0.year > $1.year }
        let role = raw["role_stats_data"]["both_sides"]
        let keys = [("firepower", "火力"), ("entrying", "进攻"), ("opening", "突破"), ("sniping", "狙击"), ("trading", "补枪"), ("clutching", "残局"), ("utility", "道具")]
        var values = keys.map { key, name in
            let item = role[key]
            return ArenaPlayerDimension(id: key, name: name, value: Self.position(item["score"].text), rawValue: item["score"].text)
        }
        let ratingPosition = raw["player_avg_data"]["Rating"]["left_percent"].text
        values.append(ArenaPlayerDimension(id: "rating-position", name: "Rating指标", value: Self.position(ratingPosition), rawValue: ratingPosition))
        dimensions = values
        sideRatings = [("T 方 Rating", raw["side_ratings"]["t_rating"].text), ("CT 方 Rating", raw["side_ratings"]["ct_rating"].text)]
    }
    private static func position(_ value: String) -> Double? {
        guard let number = Double(value.replacingOccurrences(of: "%", with: "")), number.isFinite else { return nil }
        return min(100, max(0, number))
    }
}

enum ArenaPlayerHonorKind: String, CaseIterable {
    case mvp = "MVP", top20 = "TOP20", champion = "冠军", evp = "EVP", placement = "赛事成绩"
    init(type: Int) {
        switch type { case 1: self = .mvp; case 2: self = .top20; case 3: self = .champion; case 5: self = .evp; default: self = .placement }
    }
}
struct ArenaPlayerHonor: Identifiable {
    let id: String
    let eventID: Int?
    let name: String
    let image: String
    let kind: ArenaPlayerHonorKind
    let rank: String
    let date: Date?
    let year: String
    init(_ raw: ArenaJSON, year: String, index: Int) {
        id = "\(year)-\(index)-\(raw["type"].text)-\(raw["id"].text)"
        eventID = raw["hasEvent"].bool ? raw["id"].int : nil
        name = raw["name"].text; image = raw["logo"].text
        kind = ArenaPlayerHonorKind(type: raw["type"].int ?? 0)
        rank = raw["rank"].text; date = ArenaDate.date(raw["timestamp"].number); self.year = year
    }
    var badge: String { kind == .top20 && !rank.isEmpty ? "TOP20 #\(rank)" : kind == .placement && !rank.isEmpty ? rank : kind.rawValue }
}
struct ArenaPlayerCareer {
    let honors: [ArenaPlayerHonor]
    init(_ raw: ArenaJSON) {
        honors = raw.array.flatMap { group in
            group["csHonorList"].array.enumerated().map { ArenaPlayerHonor($0.element, year: group["year"].text, index: $0.offset) }
        }
    }
}

struct ArenaPlayerMatchRecord: Identifiable {
    let match: ArenaMatch
    let rating: Double?
    var id: Int { match.id }
}
struct ArenaPlayerMatches {
    let records: [ArenaPlayerMatchRecord]
    let page: Int
    let hasMore: Bool
    init(_ raw: ArenaJSON, upcoming: Bool, page: Int, pageSize: Int) {
        let rows = raw.array.flatMap { group in
            group["matchListDTO"].array.map { match -> ArenaPlayerMatchRecord in
                let event = ArenaJSON.object([
                    "eventId": match["eventId"].exists ? match["eventId"] : group["eventId"],
                    "nameZh": .string(match.firstText("eventNameZh").isEmpty ? group["eventNameZh"].text : match["eventNameZh"].text),
                    "name": .string(match.firstText("eventNameEn").isEmpty ? group["eventNameEn"].text : match["eventNameEn"].text),
                    "logo": match["eventLogoUrl"].exists ? match["eventLogoUrl"] : group["eventLogoUrl"]
                ])
                func team(_ prefix: String, white: String) -> ArenaJSON {
                    .object(["teamId": match[prefix + "TeamId"], "name": match[prefix + "TeamName"], "logoBlack": match[prefix + "TeamLogo"], "logoWhite": match[white].exists ? match[white] : match[prefix + "TeamLogo"]])
                }
                // startTime can be the parent event's start. The site supplies
                // actual fixture time separately as matchTime (ISO-8601).
                let date = Self.matchDate(match["matchTime"].text)
                let canonical = ArenaJSON.object([
                    "matchId": match["matchId"], "eventId": event["eventId"], "csgoEventDTO": event,
                    "team1DTO": team("home", white: "whiteHomeTeamLogo"), "team2DTO": team("away", white: "whiteAwayTeamLogo"),
                    "score1": match["homeTeamScore"], "score2": match["awayTeamScore"],
                    "status": match["status"].exists ? match["status"] : .integer(upcoming ? 2 : 3),
                    "startTime": date.map { .number($0.timeIntervalSince1970 * 1000) } ?? match["startTime"],
                    "bo": match["bo"], "stageName": match["stageNameZh"]
                ])
                return ArenaPlayerMatchRecord(match: ArenaMatch(canonical), rating: match["rating"].number)
            }
        }.filter { $0.id > 0 }
        var seen = Set<Int>()
        records = rows.filter { seen.insert($0.id).inserted }
        self.page = page; hasMore = !upcoming && rows.count >= pageSize
    }
    static func matchDate(_ value: String) -> Date? {
        if let date = RedDate.parse(value) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter.date(from: value)
    }
}

extension WanmeiClient {
    func playerDetails(_ id: Int) async throws -> ArenaResult<ArenaPlayerDetailData> {
        try await read("/apg/eventcenter/csgo/player/stat/detail", query: ["playerId": "\(id)"]).map(ArenaPlayerDetailData.init)
    }
    func playerCareer(_ id: Int) async throws -> ArenaResult<ArenaPlayerCareer> {
        try await read("/apg/eventcenter/csgo/player/career", query: ["playerId": "\(id)"]).map(ArenaPlayerCareer.init)
    }
    func playerMatches(_ id: Int, upcoming: Bool, page: Int = 1) async throws -> ArenaResult<ArenaPlayerMatches> {
        let size = upcoming ? 50 : 20
        return try await read("/apg/eventcenter/csgo/player/recentEventMatches", query: ["hltvPlayerId": "\(id)", "pageNum": "\(page)", "pageSize": "\(size)", "type": upcoming ? "1" : "0"]).map { ArenaPlayerMatches($0, upcoming: upcoming, page: page, pageSize: size) }
    }
}

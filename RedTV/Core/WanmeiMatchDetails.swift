import Foundation
import Observation

struct ArenaMapVeto: Identifiable {
    let id: String
    let mapID: Int
    let name: String
    let teamName: String
    let teamLogo: String
    let type: Int
    var action: String { switch type { case 1: "禁用"; case 2: "选择"; case 3: "决胜图"; default: "待定" } }
    init(_ raw: ArenaJSON, index: Int) {
        mapID = raw["mapId"].int ?? 0
        id = "\(index)-\(mapID)"
        name = ArenaMapNames.display(raw["mapName"].text)
        teamName = raw["teamName"].text; teamLogo = raw["teamLogo"].text
        type = raw["type"].int ?? 0
    }
}

enum ArenaMapNames {
    static let names = ["cache": "死城之谜", "dust2": "炙热沙城 II", "mirage": "荒漠迷城", "inferno": "炼狱小镇", "nuke": "核子危机", "train": "列车停放站", "overpass": "死亡游乐园", "vertigo": "殒命大厦", "ancient": "远古遗迹", "anubis": "阿努比斯"]
    static let ids = [1: "cache", 2: "dust2", 3: "mirage", 4: "inferno", 5: "nuke", 6: "train", 7: "overpass", 13: "vertigo", 14: "ancient", 15: "anubis"]
    static func display(_ name: String) -> String { names[name.lowercased()] ?? (name.isEmpty ? "地图待定" : name.capitalized) }
}

struct ArenaFullMapStats: Identifiable {
    let id: String
    let name: String
    let score1: Int?
    let score2: Int?
    let completed: Bool
    let overview: Bool
    let left: [ArenaPlayerLine]
    let right: [ArenaPlayerLine]
    init(_ raw: ArenaJSON, index: Int, seriesEnded: Bool) {
        id = raw["statsId"].text.isEmpty ? "map-\(index)" : raw["statsId"].text
        overview = raw["mapDTO"]["nameEn"].text.lowercased() == "all" || raw["mapDTO"]["nameZh"].text == "总览"
        name = raw["mapDTO"].firstText("nameZh", "nameEn")
        score1 = raw["score1"].int; score2 = raw["score2"].int
        completed = (raw["winnerTeamId"].int ?? 0) > 0 || (seriesEnded && (raw["score1"].int ?? 0) + (raw["score2"].int ?? 0) > 0)
        // CSice/CTSice contain one side only. DTOList is the complete map.
        left = raw["team1PlayerStatsDTOList"].array.map(ArenaPlayerLine.init).filter { $0.id > 0 }
        right = raw["team2PlayerStatsDTOList"].array.map(ArenaPlayerLine.init).filter { $0.id > 0 }
    }
}

struct ArenaMatchCenterDetail {
    let match: ArenaMatch
    let vetoes: [ArenaMapVeto]
    let maps: [ArenaFullMapStats]
    let namiTeam1ID: Int?
    let namiTeam2ID: Int?
    private let duelsByStatsID: [String: ArenaPlayerDuels]
    init(_ raw: ArenaJSON) {
        let raw = raw["match"].exists ? raw["match"] : raw
        let parsed = ArenaMatch(raw)
        match = parsed
        namiTeam1ID = raw["namiTeam1Id"].int; namiTeam2ID = raw["namiTeam2Id"].int
        vetoes = raw["mapBPDTOS"].array.enumerated().map { ArenaMapVeto($0.element, index: $0.offset) }
        let parsedMaps = raw["statsDTOList"].array.enumerated().map { ArenaFullMapStats($0.element, index: $0.offset, seriesEnded: parsed.status == 3) }
        maps = parsedMaps
        var duels: [String: ArenaPlayerDuels] = [:]
        for item in raw["performanceStatsList"].array {
            let statsID = item["statsId"].text
            guard let map = parsedMaps.first(where: { $0.id == statsID && ($0.overview || $0.completed) }),
                  let matrix = ArenaPlayerDuels(item, map: map, team1: parsed.team1, team2: parsed.team2) else { continue }
            duels[statsID] = matrix
        }
        duelsByStatsID = duels
    }
    var completedMaps: [ArenaFullMapStats] { maps.filter { !$0.overview && $0.completed } }
    var overviewStats: ArenaFullMapStats? { maps.first(where: \.overview) }
    func duels(for statsID: String) -> ArenaPlayerDuels? { duelsByStatsID[statsID] }
}

struct ArenaMapComparison: Identifiable {
    let id: String
    let name: String
    let leftPlayed: String
    let rightPlayed: String
    let leftWin: String
    let rightWin: String
    let leftPick: String
    let rightPick: String
    let leftBan: String
    let rightBan: String
}

struct ArenaMatchMapAnalysis {
    let rows: [ArenaMapComparison]
    init(_ raw: ArenaJSON, team1ID: Int, team2ID: Int) {
        func team(_ id: Int) -> ArenaJSON {
            raw["teamlist"].array.first { $0["teamId"].int == id || $0["teamDetails"]["team_id"].int == id }?["teamDetails"] ?? .null
        }
        let left = team(team1ID), right = team(team2ID)
        func value(_ team: ArenaJSON, _ metric: String, _ name: String, percent: Bool = false) -> String {
            guard case let .object(fields) = team[metric], let field = fields.first(where: { $0.key.lowercased() == name.lowercased() })?.value, !field.text.isEmpty else { return "–" }
            let text = field.text
            return percent && !text.hasSuffix("%") ? text + "%" : text
        }
        rows = raw["sortMap"].array.map { map in
            let name = map["nameEn"].text
            return ArenaMapComparison(id: name, name: map.firstText("nameZh", "nameEn"), leftPlayed: value(left, "maps_played_dist", name), rightPlayed: value(right, "maps_played_dist", name), leftWin: value(left, "maps_win_prob", name, percent: true), rightWin: value(right, "maps_win_prob", name, percent: true), leftPick: value(left, "maps_played_pick", name, percent: true), rightPick: value(right, "maps_played_pick", name, percent: true), leftBan: value(left, "maps_played_ban", name, percent: true), rightBan: value(right, "maps_played_ban", name, percent: true))
        }.filter { $0.leftPlayed != "–" || $0.rightPlayed != "–" || $0.leftWin != "–" || $0.rightWin != "–" || $0.leftPick != "–" || $0.rightPick != "–" || $0.leftBan != "–" || $0.rightBan != "–" }
    }
}

extension WanmeiClient {
    func matchCenterDetail(_ id: Int) async throws -> ArenaResult<ArenaMatchCenterDetail> {
        let result = try await read("/apg/eventcenter/csgo/getMatchDetail", query: ["matchId": String(id)])
        let detail = ArenaMatchCenterDetail(result.value)
        guard detail.match.id == id else { throw APIError.decoding }
        return result.map { _ in detail }
    }
    func matchMapAnalysis(team1ID: Int, team2ID: Int) async throws -> ArenaResult<ArenaMatchMapAnalysis> {
        try await read("/apg/eventcenter/csgo/getTeamAnalysis", query: ["teamId": String(team1ID), "opponentTeamId": String(team2ID)]).map { ArenaMatchMapAnalysis($0, team1ID: team1ID, team2ID: team2ID) }
    }
}

struct ArenaLiveMapScore {
    let mapName: String
    let left: Int
    let right: Int
    let round: Int?
    let mapEnded: Bool
    let receivedAt: Date
    init?(_ raw: ArenaJSON, team1NamiID: Int?, team2NamiID: Int?) {
        let home = raw["home"], away = raw["away"]
        func sum(_ team: ArenaJSON) -> Int? {
            let components = [team["fh_score"].int, team["sh_score"].int, team["m_score"].int]
            guard components.contains(where: { $0 != nil }) else { return nil }
            return components.compactMap { $0 }.reduce(0, +)
        }
        guard let homeScore = sum(home), let awayScore = sum(away), homeScore >= 0, awayScore >= 0 else { return nil }
        let homeID = home["id"].int ?? home["team_id"].int ?? raw["home_id"].int
        if let homeID, let team1NamiID, let team2NamiID, homeID != team1NamiID && homeID != team2NamiID { return nil }
        let reversed = homeID != nil && homeID == team2NamiID && homeID != team1NamiID
        left = reversed ? awayScore : homeScore; right = reversed ? homeScore : awayScore
        let mapID = raw["map"]["id"].int ?? 0
        let mapName = raw["map"].firstText("name", "nameEn")
        self.mapName = ArenaMapNames.display(ArenaMapNames.ids[mapID] ?? mapName)
        round = raw["round_num"].int.flatMap { $0 > 0 ? $0 : nil }
        mapEnded = raw["single_status_id"].int == 3
        receivedAt = Date()
    }
}

@MainActor @Observable final class ArenaLiveRounds {
    private(set) var score: ArenaLiveMapScore?
    private(set) var connecting = false
    private(set) var error: String?
    private var socket: URLSessionWebSocketTask?
    func stop() {
        socket?.cancel(with: .goingAway, reason: nil); socket = nil
        connecting = false; score = nil
    }
    func connect(namiMatchID: Int, team1NamiID: Int?, team2NamiID: Int?) async {
        stop(); error = nil
        guard namiMatchID > 0 else { return }
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false; config.httpCookieStorage = nil
        let session = URLSession(configuration: config)
        var request = URLRequest(url: URL(string: "wss://wss-nami.wmpvp.com")!)
        request.setValue("https://data.wanmei.com", forHTTPHeaderField: "Origin")
        let connection = session.webSocketTask(with: request)
        socket = connection; connecting = true; connection.resume()
        let subscription = "{\"messageType\":10001,\"messageData\":{\"match_id\":\"\(namiMatchID)\"}}"
        let heartbeat = Task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(25)); try await connection.send(.string("ping")) }
                catch { return }
            }
        }
        defer { heartbeat.cancel(); connection.cancel(with: .goingAway, reason: nil); session.invalidateAndCancel(); if socket === connection { socket = nil; connecting = false } }
        do {
            try await connection.send(.string("ping")); try await connection.send(.string(subscription))
            try await withTaskCancellationHandler {
                while !Task.isCancelled {
                    let message = try await connection.receive()
                    guard !Task.isCancelled, socket === connection else { return }
                    let data: Data
                    switch message { case .data(let bytes): data = bytes; case .string(let text): data = Data(text.utf8); @unknown default: continue }
                    if String(data: data, encoding: .utf8) == "pong" { try await connection.send(.string(subscription)); continue }
                    guard let raw = try? JSONDecoder().decode(ArenaJSON.self, from: data) else { continue }
                    if raw["type"].text == "connected" || raw["type"].text == "ping" { try await connection.send(.string(subscription)) }
                    let payload = raw["messageData"]
                    let payloadMatch = payload["match_id"].int ?? raw["match_id"].int
                    if let payloadMatch, payloadMatch != namiMatchID { continue }
                    if raw["messageType"].int == 10002, let current = ArenaLiveMapScore(payload, team1NamiID: team1NamiID, team2NamiID: team2NamiID) {
                        score = current; connecting = false; error = nil
                    }
                }
            } onCancel: { connection.cancel(with: .goingAway, reason: nil) }
        } catch {
            if !Task.isCancelled, socket === connection { score = nil; self.error = "实时小局比分暂不可用，下拉刷新可重连。" }
        }
    }
}

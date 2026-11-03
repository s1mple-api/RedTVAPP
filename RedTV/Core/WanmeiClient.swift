import Foundation
import CryptoKit
import Security

struct WanmeiSigner {
    // Public web-client configuration, not a user credential. Verified against
    // https://data.wanmei.com/asset/csgo/js/csgo-e8e3d15b.js on 2026-11-02.
    static let publicWebKey = "828a59393861babc4a27e23f87fc77ab8dc9347dc6550c5e7e51e9b1af2de812"
    static func formEncode(_ text: String) -> String {
        text.utf8.map { byte in
            switch byte {
            case 65...90, 97...122, 48...57, 45, 46, 95, 126: return String(UnicodeScalar(byte))
            case 32: return "+"
            default: return String(format: "%%%02X", byte)
            }
        }.joined()
    }
    static func canonical(_ parameters: [String: [String]], timestamp: String, nonce: String) -> String {
        var parameters = parameters
        parameters["timestamp"] = [timestamp]; parameters["nonce"] = [nonce]
        let sort: (String, String) -> Bool = { $0.utf16.lexicographicallyPrecedes($1.utf16) }
        return parameters.keys.sorted(by: sort).flatMap { key in
            parameters[key]!.sorted(by: sort).map { "\(formEncode(key))=\(formEncode($0))" }
        }.joined(separator: "&")
    }
    static func signature(_ parameters: [String: [String]], timestamp: String, nonce: String, key: String = publicWebKey) -> String {
        let message = canonical(parameters, timestamp: timestamp, nonce: nonce)
        return HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: SymmetricKey(data: Data(key.utf8))).map { String(format: "%02x", $0) }.joined()
    }
    static func nonce() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw APIError.response }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}

final class WanmeiClient {
    private let session: URLSession
    private let origin: URL
    private let cacheDirectory: URL?
    init(session: URLSession? = nil, origin: URL = URL(string: "https://esports.wanmei.com")!, cacheDirectory: URL? = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("wanmei-public", isDirectory: true)) {
        self.origin = origin; self.cacheDirectory = cacheDirectory
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = session ?? URLSession(configuration: config)
    }
    func makeRequest(_ path: String, query: [String: [String]], timestamp: String = String(Int(Date().timeIntervalSince1970)), nonce: String? = nil) throws -> URLRequest {
        guard path.hasPrefix("/apg/eventcenter/csgo/") else { throw APIError.configuration }
        let nonce = try nonce ?? WanmeiSigner.nonce()
        var components = URLComponents(url: origin.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        // Match the site's form encoding; headers are never part of the URL.
        components.percentEncodedQuery = query.keys.sorted().flatMap { key in query[key]!.map { "\(WanmeiSigner.formEncode(key))=\(WanmeiSigner.formEncode($0))" } }.joined(separator: "&")
        guard let url = components.url else { throw APIError.configuration }
        var request = URLRequest(url: url)
        request.timeoutInterval = 22
        request.setValue(timestamp, forHTTPHeaderField: "X-Timestamp")
        request.setValue(nonce, forHTTPHeaderField: "X-Nonce")
        request.setValue(WanmeiSigner.signature(query, timestamp: timestamp, nonce: nonce), forHTTPHeaderField: "X-Signature")
        request.setValue("https://data.wanmei.com", forHTTPHeaderField: "Origin")
        request.setValue("https://data.wanmei.com/csgo", forHTTPHeaderField: "Referer")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("LifeTV-iOS/2.0", forHTTPHeaderField: "User-Agent")
        return request
    }
    private struct Cache: Codable { let date: Date; let body: ArenaJSON }
    func read(_ path: String, query: [String: String] = [:]) async throws -> ArenaResult<ArenaJSON> {
        let parameters = query.mapValues { [$0] }
        let cacheKey = path + "?" + WanmeiSigner.canonical(parameters, timestamp: "", nonce: "")
        let filename = SHA256.hash(data: Data(cacheKey.utf8)).map { String(format: "%02x", $0) }.joined() + ".json"
        let url = cacheDirectory?.appendingPathComponent(filename)
        do {
            let (data, response) = try await session.data(for: makeRequest(path, query: parameters))
            try Task.checkCancellation()
            guard let response = response as? HTTPURLResponse else { throw APIError.response }
            guard (200..<300).contains(response.statusCode) else { throw APIError.http(response.statusCode, "完美世界赛事数据暂时无法更新（\(response.statusCode)），请稍后重试。") }
            let raw = try JSONDecoder().decode(ArenaJSON.self, from: data)
            guard raw["code"].int == 0 || raw["code"].int == 1 else {
                throw APIError.http(raw["code"].int ?? -1, raw.firstText("message", "errorMessage").isEmpty ? "赛事来源返回异常，请稍后重试。" : "完美世界：" + raw.firstText("message", "errorMessage"))
            }
            let body = raw["result"].exists ? raw["result"] : raw["data"]
            guard body.exists else { throw APIError.decoding }
            let date = Date()
            if let cacheDirectory, let url, let data = try? JSONEncoder().encode(Cache(date: date, body: body)) {
                try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
                try? data.write(to: url, options: .atomic)
            }
            return ArenaResult(value: body, fetchedAt: date, cached: false)
        } catch is CancellationError { throw CancellationError() }
        catch let error as URLError where error.code == .cancelled { throw CancellationError() }
        catch {
            if let url, let data = try? Data(contentsOf: url), let cache = try? JSONDecoder().decode(Cache.self, from: data), (0..<86400).contains(Date().timeIntervalSince(cache.date)) {
                return ArenaResult(value: cache.body, fetchedAt: cache.date, cached: true)
            }
            if error is URLError { throw APIError.http(0, "暂时无法连接完美世界电竞，请检查网络后重试。") }
            throw error
        }
    }
    func events(page: Int = 1, ended: Bool = false) async throws -> ArenaResult<ArenaPage<ArenaEvent>> {
        try await read("/apg/eventcenter/csgo/event/getEventList", query: ["pageNum": "\(page)", "pageSize": "30", "darkType": "1", "type": ended ? "2" : "1"]).map { raw in
            let response = raw["eventResponse"], items = response["dtoList"].array.map(ArenaEvent.init).filter { $0.id > 0 }
            let total = response["itemCount"].int ?? items.count
            return ArenaPage(items: items, total: total, page: page, hasMore: page * 30 < total && !items.isEmpty)
        }
    }
    func matches(on date: Date) async throws -> ArenaResult<[ArenaMatch]> {
        try await read("/apg/eventcenter/csgo/getMatchList", query: ["matchTime": ArenaDate.dayKey(date) + " 00:00:00"]).map { $0["matchResponse"]["dtoList"].array.map(ArenaMatch.init).filter { $0.id > 0 } }
    }
    func event(_ id: Int) async throws -> ArenaResult<ArenaEvent> {
        try await read("/apg/eventcenter/csgo/event/getEventDetail", query: ["eventId": "\(id)", "darkType": "1"]).map { ArenaEvent($0["eventDetail"]) }
    }
    func eventMatches(_ id: Int) async throws -> ArenaResult<[ArenaMatch]> {
        try await read("/apg/eventcenter/csgo/event/getMatchList", query: ["eventId": "\(id)", "pageNum": "1", "pageSize": "100"]).map { $0["matchResponse"]["dtoList"].array.map(ArenaMatch.init).filter { $0.id > 0 } }
    }
    func match(_ id: Int) async throws -> ArenaResult<ArenaMatchDetail> {
        try await read("/apg/eventcenter/csgo/getMatchDetail", query: ["matchId": "\(id)"]).map(ArenaMatchDetail.init)
    }
    func teams(ranking: ArenaRanking = .hltv, region: Int? = nil, page: Int = 1) async throws -> ArenaResult<[ArenaTeam]> {
        let region = region ?? ranking.defaultRegion
        let path = ranking == .hltv ? "team/newRankList" : "team/rank"
        let query = ranking == .hltv ? ["searchType": "0", "id": "\(region)"] : ["page": "\(page)", "pageSize": "30", "type": "\(region)"]
        return try await read("/apg/eventcenter/csgo/" + path, query: query).map { $0.array.map(ArenaTeam.init).filter { $0.id > 0 } }
    }
    func team(_ id: Int) async throws -> ArenaResult<ArenaTeam> {
        try await read("/apg/eventcenter/csgo/team/detail", query: ["teamId": "\(id)"]).map(ArenaTeam.init)
    }
    func players(page: Int = 1) async throws -> ArenaResult<[ArenaPlayer]> {
        try await read("/apg/eventcenter/csgo/player/stats", query: ["pageNum": "\(page)", "pageSize": "30", "darkType": "1"]).map { $0.array.map(ArenaPlayer.init).filter { $0.id > 0 } }
    }
    func player(_ id: Int) async throws -> ArenaResult<ArenaPlayerProfile> {
        try await read("/apg/eventcenter/csgo/player/stat/detail", query: ["playerId": "\(id)"]).map(ArenaPlayerProfile.init)
    }
}

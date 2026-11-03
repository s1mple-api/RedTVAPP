import XCTest
@testable import LifeTV

final class WanmeiTests: XCTestCase {
    private func fixture(_ name: String) throws -> ArenaJSON {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") ?? bundle.url(forResource: name, withExtension: "json"))
        return try JSONDecoder().decode(ArenaJSON.self, from: Data(contentsOf: url))["result"]
    }
    func testSignatureMatchesIndependentPythonReference() {
        let params = ["q": ["CS2 & 新闻?!'()*"], "tags": ["z", "a"]]
        XCTAssertEqual(WanmeiSigner.canonical(params, timestamp: "1700000000", nonce: "00112233"), "nonce=00112233&q=CS2+%26+%E6%96%B0%E9%97%BB%3F%21%27%28%29%2A&tags=a&tags=z&timestamp=1700000000")
        XCTAssertEqual(WanmeiSigner.signature(params, timestamp: "1700000000", nonce: "00112233"), "d4c9a6110ed44e4bfd0d4371bebaa4351fbd4ec63bda68f065a1d796331b7d69")
    }
    func testSignatureHeadersAndMidnightDateQuery() throws {
        let client = WanmeiClient(cacheDirectory: nil)
        let query = ["matchTime": ["2026-11-02 00:00:00"]]
        let req = try client.makeRequest("/apg/eventcenter/csgo/getMatchList", query: query, timestamp: "1700000000", nonce: "00112233")
        XCTAssertEqual(req.url?.host, "esports.wanmei.com")
        XCTAssertEqual(req.url?.path, "/apg/eventcenter/csgo/getMatchList")
        XCTAssertEqual(req.url?.query, "matchTime=2026-11-02+00%3A00%3A00")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Signature"), WanmeiSigner.signature(query, timestamp: "1700000000", nonce: "00112233"))
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Timestamp"), "1700000000")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Nonce"), "00112233")
        XCTAssertNil(req.value(forHTTPHeaderField: "Cookie"))
        let nonce = try WanmeiSigner.nonce()
        XCTAssertNotNil(nonce.range(of: "^[0-9a-f]{32}$", options: .regularExpression))
        XCTAssertNotEqual(nonce, try WanmeiSigner.nonce())
    }
    func testRealFixturesKeepUpstreamIdentitiesAndScores() throws {
        let event = ArenaEvent(try fixture("events")["eventResponse"]["dtoList"].array[0])
        XCTAssertEqual(event.id, 8245)
        let match = ArenaMatchDetail(try fixture("match-detail"))
        XCTAssertEqual(match.match.id, 2399855)
        XCTAssertEqual(match.match.score1, 1)
        XCTAssertEqual(match.match.score2, 2)
        XCTAssertFalse(match.maps.isEmpty)
        XCTAssertFalse(match.maps[0].left.isEmpty)
        let team = ArenaTeam(try fixture("teams").array[0])
        XCTAssertEqual(team.id, 7020) // Not Nami's 3430.
        XCTAssertEqual(team.name, "Spirit")
        XCTAssertEqual(ArenaTeam(try fixture("team-detail")).id, team.id)
        let player = ArenaPlayer(try fixture("players").array[0])
        XCTAssertEqual(player.rating, 1.44)
        let profile = ArenaPlayerProfile(try fixture("player-detail"))
        XCTAssertEqual(profile.player.id, 21167)
        XCTAssertEqual(profile.ratingLabel, "Rating 3.0")
        XCTAssertEqual(profile.rating, "1.33")
    }
    func testUpcomingZeroScoresDoNotBecomeFinalResults() throws {
        let raw = try JSONDecoder().decode(ArenaJSON.self, from: Data(#"{"matchId":42,"status":2,"score1":0,"score2":0}"#.utf8))
        XCTAssertNil(ArenaMatch(raw).score1)
        XCTAssertNil(ArenaMatch(raw).score2)
        XCTAssertEqual(ArenaDate.dayKey(Date(timeIntervalSince1970: 1793548800)), "2026-11-02")
        XCTAssertEqual(Route(path: "/wanmei/teams/7020"), .arenaTeam(7020))
        XCTAssertNotEqual(Route(path: "/cs2/teams/7020"), .arenaTeam(7020))
    }
    @MainActor func testImageRequestsMatchPublicCDNReferer() throws {
        let url = try XCTUnwrap(URL(string: "https://cdn.wmpvp.com/appengine/example.png"))
        let request = ArenaImages.request(for: url)
        XCTAssertEqual(request.url, url)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Referer"), "https://data.wanmei.com/")
        XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
    }
    func testValveFixtureIsIndependentFromHLTVAndKeepsPortraits() throws {
        let valve = ArenaTeam(try fixture("valve-teams").array[0])
        let hltv = ArenaTeam(try fixture("teams").array[0])
        XCTAssertEqual(valve.name, "MOUZ")
        XCTAssertEqual(valve.points, 1963)
        XCTAssertEqual(hltv.name, "Spirit")
        XCTAssertEqual(hltv.points, 904)
        XCTAssertEqual(valve.players.first?.id, 18072)
        XCTAssertTrue(valve.players.first?.image.hasPrefix("https://") == true)
        XCTAssertNotEqual(valve.logo, valve.lightLogo)
        XCTAssertEqual(ArenaRanking.hltv.defaultRegion, -1)
        XCTAssertEqual(ArenaRanking.valve.defaultRegion, 0)
        XCTAssertEqual(AppAppearance.light.scheme, .light)
        XCTAssertEqual(AppAppearance.dark.scheme, .dark)
        XCTAssertNil(AppAppearance.system.scheme)
    }
    func testRankingClientsUseSeparateEndpointsAndRegionContracts() async throws {
        let client = makeClient(FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let hltv = try await client.teams(ranking: .hltv)
        let valve = try await client.teams(ranking: .valve)
        XCTAssertEqual(hltv.value.first?.name, "Spirit")
        XCTAssertEqual(valve.value.first?.name, "MOUZ")
    }
    func testSuccessCodesCacheActualDataAndRejectExpiredCache() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = makeClient(directory)
        let one = try await client.read("/apg/eventcenter/csgo/code-one")
        XCTAssertFalse(one.cached)
        XCTAssertEqual(one.value["value"].text, "actual-public-data")
        let fallback = try await client.read("/apg/eventcenter/csgo/code-one")
        XCTAssertTrue(fallback.cached)
        XCTAssertEqual(fallback.value["value"].text, "actual-public-data")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for url in files {
            var raw = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            raw["date"] = Date().addingTimeInterval(-90000).timeIntervalSinceReferenceDate
            try JSONSerialization.data(withJSONObject: raw).write(to: url)
        }
        do { _ = try await client.read("/apg/eventcenter/csgo/code-one"); XCTFail("Expired cache must not be shown") } catch { }
        let zero = try await client.read("/apg/eventcenter/csgo/code-zero")
        XCTAssertEqual(zero.value["value"].text, "actual-public-data")
        do { _ = try await client.read("/apg/eventcenter/csgo/rejected"); XCTFail("Upstream rejection must not be empty success") } catch { }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).count, 2)
    }
    private func makeClient(_ directory: URL) -> WanmeiClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [WanmeiFixtureProtocol.self]
        return WanmeiClient(session: URLSession(configuration: config), cacheDirectory: directory)
    }
}

private final class WanmeiFixtureProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var counts: [String: Int] = [:]
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.lastPathComponent
        if path == "newRankList" || path == "rank" {
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            if path == "newRankList" { XCTAssertEqual(query["searchType"], "0"); XCTAssertEqual(query["id"], "-1"); XCTAssertNil(query["type"]) }
            else { XCTAssertEqual(query["type"], "0"); XCTAssertEqual(query["page"], "1"); XCTAssertEqual(query["pageSize"], "30"); XCTAssertNil(query["searchType"]) }
            let name = path == "rank" ? "valve-teams" : "teams"
            let bundle = Bundle(for: WanmeiTests.self)
            let file = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") ?? bundle.url(forResource: name, withExtension: "json")!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: try! Data(contentsOf: file))
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        Self.lock.lock(); let count = Self.counts[path, default: 0]; Self.counts[path] = count + 1; Self.lock.unlock()
        if path == "code-one", count > 0 { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)); return }
        let body = path == "rejected" ? #"{"code":10001,"errorMessage":"参数错误","result":null}"# : "{\"code\":\(path == "code-one" ? 1 : 0),\"result\":{\"value\":\"actual-public-data\"}}"
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}

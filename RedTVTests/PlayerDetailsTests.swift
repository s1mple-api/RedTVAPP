import XCTest
@testable import RedTV

final class PlayerDetailsTests: XCTestCase {
    private func decode(_ string: String) throws -> ArenaJSON { try JSONDecoder().decode(ArenaJSON.self, from: Data(string.utf8)) }
    func testEightAxesUseOnlySuppliedRoleScoresAndRatingPosition() throws {
        let raw = try decode(##"{"playerId":21167,"basicInfo":{"playerName":"donk","top20":["#2  25","#1  24"]},"role_stats_data":{"both_sides":{"firepower":{"score":"98"},"entrying":{"score":"57"},"opening":{"score":"88"},"sniping":{"score":"3"},"trading":{"score":"76"},"clutching":{"score":"24"},"utility":{"score":"36"}}},"player_avg_data":{"Rating":{"score":"1.33","desc":"Rating 3.0","left_percent":"100.0%"}}}"##)
        let details = ArenaPlayerDetailData(raw)
        XCTAssertEqual(details.profile.player.id, 21167)
        XCTAssertEqual(details.dimensions.count, 8)
        XCTAssertEqual(details.dimensions.map(\.value), [98,57,88,3,76,24,36,100])
        XCTAssertEqual(details.profile.rating, "1.33")
        XCTAssertEqual(details.top20.map(\.year), [2025,2024])
        XCTAssertEqual(details.top20.map(\.rank), [2,1])
        XCTAssertNil(ArenaPlayerDetailData(try decode("{}")).dimensions.first?.value)
    }
    func testHonorTypesDoNotTurnChampionshipsOrEVPsIntoMVP() throws {
        let raw = try decode(#"[{"year":2025,"csHonorList":[{"id":1,"type":1,"name":"MVP"},{"id":2,"type":2,"name":"HLTV","rank":"2"},{"id":3,"type":3,"name":"Champion"},{"id":4,"type":5,"name":"EVP"}]}]"#)
        let honors = ArenaPlayerCareer(raw).honors
        XCTAssertEqual(honors.map(\.kind), [.mvp,.top20,.champion,.evp])
        XCTAssertEqual(honors[1].badge, "TOP20 #2")
    }
    func testFixtureTimeWinsOverRepeatedEventStartAndUpcomingScoresStayEmpty() throws {
        let raw = try decode(#"[{"eventId":8251,"eventNameZh":"BLAST","matchListDTO":[{"matchId":2399853,"homeTeamId":7020,"homeTeamName":"Spirit","awayTeamId":13286,"awayTeamName":"FUT","homeTeamScore":0,"awayTeamScore":0,"startTime":1792836000000,"matchTime":"2026-11-11T07:00:00.000+0000"}]}]"#)
        let page = ArenaPlayerMatches(raw, upcoming: true, page: 1, pageSize: 50)
        let match = try XCTUnwrap(page.records.first?.match)
        XCTAssertEqual(match.id, 2399853)
        XCTAssertEqual(match.team1.id, 7020)
        XCTAssertEqual(ArenaDate.format(match.start, pattern: "yyyy-MM-dd HH:mm"), "2026-11-11 15:00")
        XCTAssertNil(match.score1)
        XCTAssertFalse(page.hasMore)
    }
}

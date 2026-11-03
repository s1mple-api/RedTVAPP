import XCTest
import UIKit
@testable import RedTV

final class WanmeiMatchDetailTests: XCTestCase {
    private func json(_ text: String) throws -> ArenaJSON { try JSONDecoder().decode(ArenaJSON.self, from: Data(text.utf8)) }
    func testMapBadgesResolveSourceNamesAndAreBundled() {
        XCTAssertEqual(ArenaMapIdentity(name: "de_mirage"), .mirage)
        XCTAssertEqual(ArenaMapIdentity(name: "荒漠迷城"), .mirage)
        XCTAssertEqual(ArenaMapIdentity(name: "炙热沙城Ⅱ"), .dust2)
        XCTAssertEqual(ArenaMapIdentity(name: "Dust II"), .dust2)
        XCTAssertNil(ArenaMapIdentity(name: "unknown-map"))
        for map in ArenaMapIdentity.allCases { XCTAssertNotNil(UIImage(named: map.assetName), map.rawValue) }
    }
    func testCompleteMapUsesWholeMapNotSideOnlyStats() throws {
        let raw = try json(#"{"match":{"matchId":42,"status":3,"score1":2,"score2":1,"statsDTOList":[{"statsId":7,"mapDTO":{"nameEn":"mirage","nameZh":"荒漠迷城"},"score1":16,"score2":13,"team1PlayerStatsDTOList":[{"playerDTO":{"playerId":19869,"name":"try"},"kills":29,"deaths":14,"adr":89.3,"rating":1.42}],"team1PlayerStatsCSiceDTOList":[{"playerDTO":{"playerId":19869,"name":"try"},"kills":16,"deaths":10}]}]}}"#)
        let detail = ArenaMatchCenterDetail(raw)
        XCTAssertEqual(detail.completedMaps.count, 1)
        XCTAssertEqual(detail.completedMaps[0].left[0].kills, 29)
        XCTAssertEqual(detail.completedMaps[0].left[0].deaths, 14)
        XCTAssertEqual(detail.match.score1, 2)
        XCTAssertEqual(detail.completedMaps[0].score1, 16)
    }
    func testMapVetoKeepsSourceOrderAndNeverCallsUnfinishedMapPostMatch() throws {
        let raw = try json(#"{"matchId":42,"status":1,"mapBPDTOS":[{"mapId":3,"mapName":"mirage","type":1,"teamName":"A"},{"mapId":5,"mapName":"nuke","type":2,"teamName":"B"},{"mapId":14,"mapName":"ancient","type":3}],"statsDTOList":[{"statsId":1,"mapDTO":{"nameEn":"all"},"winnerTeamId":1},{"statsId":2,"mapDTO":{"nameEn":"nuke"},"winnerTeamId":1},{"statsId":3,"mapDTO":{"nameEn":"mirage"},"score1":14,"score2":12}]}"#)
        let detail = ArenaMatchCenterDetail(raw)
        XCTAssertEqual(detail.vetoes.map(\.mapID), [3, 5, 14])
        XCTAssertEqual(detail.vetoes.map(\.action), ["禁用", "选择", "决胜图"])
        XCTAssertEqual(detail.completedMaps.map(\.id), ["2"])
    }
    func testLiveRoundScoresIncludeOvertimeAndRespectNamiOrientation() throws {
        let raw = try json(#"{"map":{"id":3},"round_num":29,"single_status_id":2,"home":{"id":22,"fh_score":8,"sh_score":4,"m_score":3},"away":{"id":11,"fh_score":6,"sh_score":6,"m_score":1}}"#)
        let score = try XCTUnwrap(ArenaLiveMapScore(raw, team1NamiID: 11, team2NamiID: 22))
        XCTAssertEqual(score.left, 13)
        XCTAssertEqual(score.right, 15)
        XCTAssertEqual(score.mapName, "荒漠迷城")
        XCTAssertFalse(score.mapEnded)
        XCTAssertNil(ArenaLiveMapScore(try json(#"{"home":{},"away":{}}"#), team1NamiID: nil, team2NamiID: nil))
    }
    func testMapAnalysisIsJoinedByHLTVIDAndMissingValuesStayMissing() throws {
        let raw = try json(#"{"sortMap":[{"nameEn":"mirage","nameZh":"荒漠迷城"}],"teamlist":[{"teamId":22,"teamDetails":{"maps_win_prob":{"Mirage":"50.0%"}}},{"teamId":11,"teamDetails":{"maps_win_prob":{"Mirage":"81.3%"},"maps_played_dist":{"Mirage":16},"maps_played_pick":{"Mirage":"40.7"}}}]}"#)
        let analysis = ArenaMatchMapAnalysis(raw, team1ID: 11, team2ID: 22)
        let row = try XCTUnwrap(analysis.rows.first)
        XCTAssertEqual(row.leftWin, "81.3%")
        XCTAssertEqual(row.rightWin, "50.0%")
        XCTAssertEqual(row.leftPlayed, "16")
        XCTAssertEqual(row.leftPick, "40.7%")
        XCTAssertEqual(row.rightPlayed, "–")
        XCTAssertEqual(row.leftBan, "–")
    }
    func testUnplayedDeciderAndUnexpectedLiveTeamAreNotPresentedAsResults() throws {
        let raw = try json(#"{"matchId":42,"status":3,"statsDTOList":[{"statsId":1,"mapDTO":{"nameEn":"ancient"},"score1":0,"score2":0}]}"#)
        XCTAssertTrue(ArenaMatchCenterDetail(raw).completedMaps.isEmpty)
        let unrelated = try json(#"{"home":{"id":999,"fh_score":8},"away":{"id":998,"fh_score":7}}"#)
        XCTAssertNil(ArenaLiveMapScore(unrelated, team1NamiID: 11, team2NamiID: 22))
        XCTAssertNil(ArenaLiveMapScore(.string("ok"), team1NamiID: 11, team2NamiID: 22))
    }
}

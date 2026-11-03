import XCTest
@testable import RedTV

final class PlayerDuelsTests: XCTestCase {
    func testRecordedMatchKeepsSourcePairsAndReversedMapScores() throws {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: "match-detail", withExtension: "json", subdirectory: "Fixtures") ?? bundle.url(forResource: "match-detail", withExtension: "json"))
        let raw = try JSONDecoder().decode(ArenaJSON.self, from: Data(contentsOf: url))["result"]
        let value = ArenaMatchCenterDetail(raw)
        XCTAssertEqual(value.overviewStats?.id, "132694")
        for map in value.maps {
            let matrix = try XCTUnwrap(value.duels(for: map.id), map.name)
            XCTAssertEqual(matrix.left.count, 5)
            XCTAssertEqual(matrix.right.count, 5)
            XCTAssertEqual(Set(matrix.left.map(\.id)), Set(map.left.map(\.id)))
            XCTAssertEqual(Set(matrix.right.map(\.id)), Set(map.right.map(\.id)))
            // This recorded fixture trims each scoreList to three pairs.
            // Preserve its 15 supplied cells and keep the other 10 missing.
            let available = matrix.left.flatMap { left in
                matrix.right.compactMap { right in matrix.score(leftID: left.id, rightID: right.id) }
            }
            XCTAssertEqual(available.count, 15)
        }
        // dumau vs nin9: the source column/row groups reverse on Mirage.
        let all = try XCTUnwrap(value.duels(for: "132694")?.score(leftID: 15698, rightID: 15072))
        XCTAssertEqual(all.leftKills, 8)
        XCTAssertEqual(all.rightKills, 7)
        let mirage = try XCTUnwrap(value.duels(for: "243488")?.score(leftID: 15698, rightID: 15072))
        XCTAssertEqual(mirage.leftKills, 7)
        XCTAssertEqual(mirage.rightKills, 4)
    }

    private func detail(_ performance: String, extraMaps: String = "") throws -> ArenaMatchCenterDetail {
        let source = """
        {"matchId":42,"status":3,
         "statsDTOList":[
          {"statsId":10,"mapDTO":{"nameEn":"all"},
           "team1PlayerStatsDTOList":[{"playerDTO":{"playerId":11,"name":"A"},"kills":20,"rating":1.21}],
           "team2PlayerStatsDTOList":[{"playerDTO":{"playerId":21,"name":"B"},"kills":18,"rating":0.98}]}
          \(extraMaps)],
         "performanceStatsList":\(performance)}
        """
        return ArenaMatchCenterDetail(try JSONDecoder().decode(ArenaJSON.self, from: Data(source.utf8)))
    }

    func testOverviewUsesSourceAggregateAndDuelPairsKeepTheirOrientation() throws {
        let value = try detail(#"[{"statsId":10,"team1List":[{"playerId":11,"name":"A","img":"https://example.com/a.png"}],"team2List":[{"playerId":21,"name":"B","scoreList":[7,9]}]}]"#)
        XCTAssertEqual(value.overviewStats?.id, "10")
        XCTAssertEqual(value.overviewStats?.left.first?.rating, 1.21)
        XCTAssertTrue(value.completedMaps.isEmpty)
        let matrix = try XCTUnwrap(value.duels(for: "10"))
        XCTAssertEqual(matrix.left.map(\.id), [11])
        XCTAssertEqual(matrix.right.map(\.id), [21])
        XCTAssertEqual(matrix.left.first?.image, "https://example.com/a.png")
        XCTAssertEqual(matrix.score(leftID: 11, rightID: 21)?.leftKills, 9)
        XCTAssertEqual(matrix.score(leftID: 11, rightID: 21)?.rightKills, 7)
        XCTAssertNil(value.duels(for: "unknown"))
    }

    func testSingleMapCanReverseSourceGroupsWithoutReversingDisplayedTeams() throws {
        let map = #",{"statsId":20,"mapDTO":{"nameEn":"mirage"},"winnerTeamId":100,"team1PlayerStatsDTOList":[{"playerDTO":{"playerId":11,"name":"A"}}],"team2PlayerStatsDTOList":[{"playerDTO":{"playerId":21,"name":"B"}}]}"#
        let value = try detail(#"[{"statsId":20,"team1List":[{"playerId":21,"name":"B"}],"team2List":[{"playerId":11,"name":"A","scoreList":[9,7]}]}]"#, extraMaps: map)
        let matrix = try XCTUnwrap(value.duels(for: "20"))
        XCTAssertEqual(matrix.left.map(\.id), [11])
        XCTAssertEqual(matrix.right.map(\.id), [21])
        XCTAssertEqual(matrix.score(leftID: 11, rightID: 21)?.leftKills, 9)
        XCTAssertEqual(matrix.score(leftID: 11, rightID: 21)?.rightKills, 7)
        XCTAssertNil(value.duels(for: "10"), "A missing overview matrix must not borrow a single map")
    }

    func testMissingOrInvalidPairsRemainMissingWhileActualZerosArePreserved() throws {
        let value = try detail(#"[{"statsId":10,"team1List":[{"playerId":11,"name":"A"},{"playerId":12,"name":"C"},{"playerId":13,"name":"D"}],"team2List":[{"playerId":21,"name":"B","scoreList":[0,0,-1,2,1.5,3]},{"playerId":22,"name":"E","scoreList":[4]}]}]"#)
        let matrix = try XCTUnwrap(value.duels(for: "10"))
        XCTAssertEqual(matrix.score(leftID: 11, rightID: 21)?.leftKills, 0)
        XCTAssertEqual(matrix.score(leftID: 11, rightID: 21)?.rightKills, 0)
        XCTAssertNil(matrix.score(leftID: 12, rightID: 21))
        XCTAssertNil(matrix.score(leftID: 13, rightID: 21))
        XCTAssertNil(matrix.score(leftID: 11, rightID: 22))
    }

    func testUnknownRostersAndMissingOverviewAreNotGuessed() throws {
        let unknown = try detail(#"[{"statsId":10,"team1List":[{"playerId":999,"name":"X"}],"team2List":[{"playerId":998,"name":"Y","scoreList":[3,4]}]}]"#)
        XCTAssertNil(unknown.duels(for: "10"))
        let raw = try JSONDecoder().decode(ArenaJSON.self, from: Data(#"{"matchId":42,"statsDTOList":[]}"#.utf8))
        XCTAssertNil(ArenaMatchCenterDetail(raw).overviewStats)
    }
}

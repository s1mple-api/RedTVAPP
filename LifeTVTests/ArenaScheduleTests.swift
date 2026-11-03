import XCTest
@testable import LifeTV

final class ArenaScheduleTests: XCTestCase {
    private func match(_ id: Int, stars: Int, status: Int, start: Int = 1793600000000) throws -> ArenaMatch {
        let data = try JSONSerialization.data(withJSONObject: ["matchId": id, "star": stars, "status": status, "startTime": start])
        return ArenaMatch(try JSONDecoder().decode(ArenaJSON.self, from: data))
    }
    func testHighAttentionIsSortedFirstAndUnratedMatchesStayInSchedule() throws {
        let normal = try match(1, stars: 0, status: 1)
        let next = try match(2, stars: 5, status: 2)
        let live = try match(3, stars: 3, status: 1)
        let lowerLive = try match(4, stars: 1, status: 1)
        let rows = [normal, next, lowerLive, live]
        XCTAssertEqual(ArenaSchedule.prioritized(rows).map(\.id), [2, 3, 4, 1])
        XCTAssertEqual(ArenaSchedule.highlights(rows).map(\.id), [2, 3, 4])
    }
    func testUpcomingFocusAndUnratedFallback() throws {
        let done = try match(1, stars: 5, status: 3)
        let next = try match(2, stars: 3, status: 2)
        let later = try match(3, stars: 3, status: 2, start: 1793603600000)
        XCTAssertEqual(ArenaSchedule.highlights([done, later, next]).first?.id, 2)
        XCTAssertEqual(ArenaSchedule.highlights([try match(4, stars: 0, status: 1), done]).first?.id, 4)
        XCTAssertTrue(ArenaSchedule.highlights([]).isEmpty)
    }
    func testHighlightsCapAtThreeAndUseAttentionOrder() throws {
        let rows = try [match(1, stars: 1, status: 1), match(2, stars: 5, status: 2), match(3, stars: 3, status: 1), match(4, stars: 4, status: 2), match(5, stars: 5, status: 3)]
        XCTAssertEqual(ArenaSchedule.highlights(rows).map(\.id), [2, 4, 3])
        XCTAssertEqual(ArenaSchedule.highlights(rows + rows).count, 3)
        XCTAssertEqual(ArenaSchedule.highlights([rows[0]]).count, 1)
        XCTAssertTrue(ArenaSchedule.highlights([]).isEmpty)
    }
}

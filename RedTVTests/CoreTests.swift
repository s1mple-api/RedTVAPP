import XCTest
@testable import RedTV

final class CoreTests: XCTestCase {
    func testGoNullSlicesDoNotBreakDashboard() throws {
        let data = Data(#"{"articles":null,"worldArticles":[],"newsFeed":null,"communityTopics":{"tieba":null,"hupu":[]},"sourceStatus":{},"issues":{"events":"受限"}}"#.utf8)
        let value = try JSONDecoder().decode(Dashboard.self, from: data)
        XCTAssertTrue(value.feed.isEmpty)
    }

    func testMalformedArraysStillFailDecoding() {
        XCTAssertThrowsError(try JSONDecoder().decode(Dashboard.self, from: Data(#"{"worldArticles":[{"id":"invalid"}]}"#.utf8)))
    }

    func testRemovedBookmarkDoesNotReappearFromAnotherDevice() {
        var first = ReadingLibrary(), second = ReadingLibrary()
        first.bookmarks = [SavedItem(path: "/article/42", title: "旧收藏", source: "bbc", kind: "article", savedAt: 100)]
        second.removed = ["bookmarks:/article/42": 200]
        XCTAssertTrue(first.merging(second).bookmarks.isEmpty)
        XCTAssertTrue(second.merging(first).bookmarks.isEmpty)
        first.bookmarks[0].savedAt = 300
        XCTAssertEqual(first.merging(second).bookmarks.count, 1)
    }

    func testMergeDeduplicatesCapsAndRejectsInvalidRoutes() {
        var first = ReadingLibrary(), second = ReadingLibrary()
        first.bookmarks = (1...220).map { SavedItem(path: "/article/\($0)", title: "新闻", source: "bbc", kind: "article", savedAt: Int64($0)) }
        second.bookmarks = [SavedItem(path: "/article/220", title: "新标题", source: "bbc", kind: "article", savedAt: 900), SavedItem(path: "https://example.com", title: "外部", source: "", kind: "article", savedAt: 999)]
        let merged = first.merging(second)
        XCTAssertEqual(merged.bookmarks.count, 200)
        XCTAssertEqual(merged.bookmarks.first?.title, "新标题")
        XCTAssertEqual(Set(merged.bookmarks.map(\.path)).count, 200)
        XCTAssertFalse(merged.bookmarks.contains { $0.path.hasPrefix("https:") })
    }

    func testRequestsEncodeQueriesAndMatchBackendCSRFContract() throws {
        let client = APIClient(configuration: ServerConfiguration(apiURL: "https://api.example.com/", websiteURL: "https://www.example.com"))
        let request = try client.makeRequest("search/advanced", query: ["q": "CS2 & 新闻?", "source": "bbc"])
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.path, "/api/v1/search/advanced")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "q" })?.value, "CS2 & 新闻?")
        let write = try client.makeRequest("auth/login", body: Data("{}".utf8), post: true)
        XCTAssertEqual(write.httpMethod, "POST")
        XCTAssertEqual(write.value(forHTTPHeaderField: "Origin"), "https://www.example.com")
        XCTAssertEqual(write.value(forHTTPHeaderField: "X-Red-Request"), "1")
        XCTAssertEqual(write.httpBody, Data("{}".utf8))
    }

    func testConfigurationRejectsCredentialsQueriesAndUnsupportedSchemes() {
        for url in ["file:///etc/passwd", "https://name:secret@example.com", "https://example.com?token=secret", "https://example.com/#part", "invalid"] {
            XCTAssertNil(ServerConfiguration.validURL(url), url)
        }
        XCTAssertNotNil(ServerConfiguration.validURL("https://redtv.icu"))
    }

    func testRoutesPreserveWebResourceIdentity() {
        let key = String(repeating: "a", count: 24)
        XCTAssertEqual(Route(path: "/topic/\(key)/post/\(key)"), .legacy("/topic/\(key)/post/\(key)"))
        XCTAssertEqual(Route(path: "/cs2/teams/43"), .legacy("/cs2/teams/43"))
        XCTAssertEqual(Route(path: "/topics/cs2-events"), .legacy("/topics/cs2-events"))
        XCTAssertNil(Route(path: "/article/-1"))
        XCTAssertNil(Route(path: "/post/not-a-key"))
        XCTAssertNil(Route(path: "/topics/../../account"))
    }

    func testNewsDateAcceptsFractionalSeconds() {
        XCTAssertNotNil(RedDate.parse("2026-11-01T00:00:00.123456789Z"))
    }
}

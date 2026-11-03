import XCTest
@testable import RedTV

final class APIResponseTests: XCTestCase {
    private func client() -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FixtureProtocol.self]
        return APIClient(configuration: ServerConfiguration(apiURL: "https://fixture.redtv.test", websiteURL: "https://fixture.redtv.test"), session: URLSession(configuration: config))
    }

    func testTopLevelGoNullSliceBecomesEmptyList() async throws {
        let events: [Article] = try await client().get("null-list")
        XCTAssertTrue(events.isEmpty)
    }

    func testNullObjectIsNotAcceptedAsAnEmptySession() async {
        do {
            let _: UserResponse = try await client().get("null-list")
            XCTFail("A null object must fail decoding")
        } catch { XCTAssertTrue(error is APIError) }
    }

    func testBackendChineseErrorIsPreserved() async {
        do {
            let _: UserResponse = try await client().get("unauthorized")
            XCTFail("Expected authentication error")
        } catch {
            guard case let APIError.http(code, message) = error else { return XCTFail("Unexpected error: \(error)") }
            XCTAssertEqual(code, 401)
            XCTAssertEqual(message, "请先登录后操作")
        }
    }

    @MainActor func testResourceIgnoresSupersededResponse() async {
        let resource = Resource<String>()
        let old = Task { await resource.load { try await Task.sleep(for: .milliseconds(60)); return "old" } }
        await Task.yield()
        await resource.load { "new" }
        await old.value
        XCTAssertEqual(resource.value, "new")
        XCTAssertFalse(resource.isLoading)
    }

    @MainActor func testChangingSourceClearsPriorSourceWhileLoading() async {
        let resource = Resource<String>()
        await resource.load(key: "hltv") { "HLTV ranking" }
        let updated = Task { await resource.load(key: "valve") { try await Task.sleep(for: .milliseconds(50)); return "Valve snapshot" } }
        await Task.yield()
        XCTAssertNil(resource.value)
        await updated.value
        XCTAssertEqual(resource.value, "Valve snapshot")
    }
}

private final class FixtureProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let unauthorized = request.url?.lastPathComponent == "unauthorized"
        let body = unauthorized ? #"{"error":"请先登录后操作"}"# : "null"
        let response = HTTPURLResponse(url: request.url!, statusCode: unauthorized ? 401 : 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}

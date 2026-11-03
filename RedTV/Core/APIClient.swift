import Foundation
import Observation

struct ServerConfiguration: Codable, Equatable {
    var apiURL = "https://redtv.icu"
    var websiteURL = "https://redtv.icu"

    var namespace: String { apiURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }
    static func validURL(_ raw: String) -> URL? {
        guard let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme, ["https", "http"].contains(scheme),
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil else { return nil }
        #if !DEBUG
        guard scheme == "https" else { return nil }
        #endif
        return url
    }
    var isValid: Bool { Self.validURL(apiURL) != nil && Self.validURL(websiteURL) != nil }
    var origin: String {
        guard let url = Self.validURL(websiteURL), let host = url.host else { return "" }
        return "\(url.scheme!)://\(host)" + (url.port.map { ":\($0)" } ?? "")
    }
    func shareURL(path: String) -> URL? {
        guard let url = Self.validURL(websiteURL) else { return nil }
        return url.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }
}

enum APIError: LocalizedError {
    case configuration, response, http(Int, String), decoding, offline
    var errorDescription: String? {
        switch self {
        case .configuration: "服务地址无效，请在连接设置中检查。"
        case .response: "服务器未返回有效响应，请重试。"
        case let .http(_, message): message
        case .decoding: "服务器数据格式与当前版本不兼容，请稍后重试。"
        case .offline: "暂时无法连接 Red TV，请检查网络或服务地址。"
        }
    }
}

final class APIClient {
    let configuration: ServerConfiguration
    private let session: URLSession
    init(configuration: ServerConfiguration, session: URLSession? = nil) {
        self.configuration = configuration
        if let session { self.session = session } else {
            let config = URLSessionConfiguration.default
            config.httpShouldSetCookies = true
            config.httpCookieStorage = .shared
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: config)
        }
    }

    func makeRequest(_ path: String, query: [String: String] = [:], body: Data? = nil, post: Bool = false) throws -> URLRequest {
        guard let base = ServerConfiguration.validURL(configuration.apiURL),
              var components = URLComponents(url: base.appendingPathComponent("api/v1").appendingPathComponent(path), resolvingAgainstBaseURL: false) else { throw APIError.configuration }
        if !query.isEmpty { components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        guard let url = components.url else { throw APIError.configuration }
        var request = URLRequest(url: url)
        request.timeoutInterval = path.hasPrefix("articles/") ? 45 : 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if post {
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("1", forHTTPHeaderField: "X-Red-Request")
            request.setValue(configuration.origin, forHTTPHeaderField: "Origin")
            request.httpBody = body
        }
        return request
    }

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        try await send(makeRequest(path, query: query))
    }
    func post<T: Decodable, Body: Encodable>(_ path: String, body: Body) async throws -> T {
        try await send(makeRequest(path, body: JSONEncoder().encode(body), post: true))
    }
    func post(_ path: String) async throws {
        let _: Acknowledgement = try await send(makeRequest(path, post: true))
    }
    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let response = response as? HTTPURLResponse else { throw APIError.response }
            guard (200..<300).contains(response.statusCode) else {
                let message = (try? JSONDecoder().decode(ServerError.self, from: data))?.error
                let readable = message?.range(of: "[\\p{Han}]", options: .regularExpression) != nil
                throw APIError.http(response.statusCode, readable ? message! : response.statusCode == 401 ? "请先登录后操作。" : "服务暂时不可用（\(response.statusCode)），请重试。")
            }
            do {
                if let value = try JSONDecoder().decode(T?.self, from: data) { return value }
                if let collection = T.self as? EmptyAPICollection.Type, let value = collection.init() as? T { return value }
                throw APIError.decoding
            }
            catch { throw APIError.decoding }
        } catch is CancellationError { throw CancellationError() }
        catch let error as URLError where error.code == .cancelled { throw CancellationError() }
        catch let error as URLError {
            if error.code == .timedOut { throw APIError.http(408, "读取超时，已保留现有内容，请重试。") }
            throw APIError.offline
        }
    }
    private struct ServerError: Decodable { let error: String }
}

private protocol EmptyAPICollection { init() }
extension Array: EmptyAPICollection { }

@MainActor @Observable final class Resource<Value> {
    var value: Value?
    var isLoading = false
    var error: String?
    private var requestID = UUID()
    private var contentKey: String?

    func load(key: String? = nil, _ operation: () async throws -> Value) async {
        if let key, key != contentKey { value = nil; contentKey = key }
        let id = UUID()
        requestID = id
        isLoading = true
        error = nil
        defer { if requestID == id { isLoading = false } }
        do {
            let result = try await operation()
            guard requestID == id, !Task.isCancelled else { return }
            value = result
        } catch is CancellationError { }
        catch { if requestID == id { self.error = error.localizedDescription } }
    }
}

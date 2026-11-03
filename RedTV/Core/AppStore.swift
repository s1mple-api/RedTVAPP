import Foundation
import Observation
import CryptoKit

@MainActor @Observable final class AppStore {
    let arena = ArenaStore()
    private(set) var configuration: ServerConfiguration
    private(set) var api: APIClient
    private(set) var configurationID = UUID()
    private(set) var dashboard: Dashboard?
    private(set) var dashboardLoading = false
    private(set) var dashboardError: String?
    private(set) var cachedAt: Date?
    private(set) var user: User?
    private(set) var sessionLoading = false
    private(set) var library = ReadingLibrary()
    private(set) var syncState = "保存在此 iPhone"
    private(set) var syncError: String?
    var showSettings = false

    private let defaults: UserDefaults
    private var contextID = UUID()
    private var syncTask: Task<Void, Never>?
    private var dashboardRequest = UUID()
    private let readerID = UUID().uuidString
    private var recordedReads = Set<Int>()
    private var dashboardUpdatedAt: Date?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.data(forKey: "life.server").flatMap { try? JSONDecoder().decode(ServerConfiguration.self, from: $0) }
        let resolved = saved?.isValid == true ? saved! : ServerConfiguration()
        configuration = resolved
        api = APIClient(configuration: resolved)
        library = readLibrary()
        loadDashboardCache()
    }

    private var namespace: String {
        SHA256.hash(data: Data(configuration.namespace.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    private var libraryKey: String { "life.library.\(namespace).\(user.map { String($0.id) } ?? "guest")" }
    private func readLibrary() -> ReadingLibrary {
        guard let data = defaults.data(forKey: libraryKey), let library = try? JSONDecoder().decode(ReadingLibrary.self, from: data) else { return ReadingLibrary() }
        return library.merging(ReadingLibrary())
    }
    private func persistLibrary() {
        if let data = try? JSONEncoder().encode(library) { defaults.set(data, forKey: libraryKey) }
    }
    func apply(_ configuration: ServerConfiguration) async {
        guard configuration.isValid, self.configuration != configuration else { return }
        syncTask?.cancel()
        contextID = UUID()
        dashboardRequest = UUID()
        self.configuration = configuration
        defaults.set(try? JSONEncoder().encode(configuration), forKey: "life.server")
        api = APIClient(configuration: configuration)
        user = nil
        sessionLoading = false
        dashboardLoading = false
        library = readLibrary()
        dashboard = nil
        cachedAt = nil
        dashboardUpdatedAt = nil
        dashboardError = nil
        syncError = nil
        syncState = "保存在此 iPhone"
        recordedReads = []
        loadDashboardCache()
        configurationID = UUID()
        // RootView starts fresh dashboard/session tasks for this configuration.
    }
    func bootstrap() async {
        async let sports: () = arena.bootstrap()
        async let content: () = refreshDashboard()
        async let session: () = loadSession()
        _ = await (sports, content, session)
    }
    func refreshDashboard() async {
        let request = UUID(), client = api, context = configurationID
        dashboardRequest = request
        dashboardLoading = true
        defer { if dashboardRequest == request { dashboardLoading = false } }
        do {
            let articles: [Article] = try await client.get("world-news", query: ["limit": "100"])
            let value = Dashboard(bbcArticles: articles.filter { $0.source.lowercased() == "bbc" })
            guard request == dashboardRequest, context == configurationID else { return }
            dashboard = value
            dashboardError = nil
            cachedAt = nil
            dashboardUpdatedAt = Date()
            saveDashboardCache(value)
        } catch is CancellationError { }
        catch {
            guard request == dashboardRequest, context == configurationID else { return }
            dashboardError = error.localizedDescription
            if let date = dashboardUpdatedAt, Date().timeIntervalSince(date) < 86400 { cachedAt = date }
            else { dashboard = nil; cachedAt = nil }
        }
    }
    func loadSession() async {
        let context = contextID, client = api
        sessionLoading = true
        defer { if context == contextID { sessionLoading = false } }
        do {
            let response: UserResponse = try await client.get("auth/me")
            guard context == contextID else { return }
            await adopt(response.user, importGuest: false)
        } catch is CancellationError { }
        catch { if context == contextID { syncError = error.localizedDescription } }
    }
    func authenticate(register: Bool, username: String, password: String, displayName: String) async throws {
        syncTask?.cancel()
        let context = contextID
        struct Credentials: Encodable { let username: String; let password: String; let displayName: String }
        let response: UserResponse = try await api.post("auth/\(register ? "register" : "login")", body: Credentials(username: username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), password: password, displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines)))
        guard context == contextID, let user = response.user else { throw APIError.response }
        await adopt(user, importGuest: true)
    }
    func logout() async throws {
        syncTask?.cancel()
        contextID = UUID()
        try await api.post("auth/logout")
        await adopt(nil, importGuest: false)
    }
    private func adopt(_ user: User?, importGuest: Bool) async {
        let guest = importGuest && self.user == nil ? library : nil
        contextID = UUID()
        let context = contextID
        syncTask?.cancel()
        self.user = user
        sessionLoading = false
        library = readLibrary()
        if let guest { library = library.merging(guest); persistLibrary() }
        syncError = nil
        syncState = user == nil ? "保存在此 iPhone" : "等待同步"
        guard user != nil else { return }
        do {
            let remote: ReadingLibrary = try await api.get("me/library")
            guard context == contextID else { return }
            library = library.merging(remote)
            persistLibrary()
            await syncLibrary()
        } catch is CancellationError { }
        catch { if context == contextID { syncError = error.localizedDescription; syncState = "同步未完成" } }
    }
    func syncLibrary() async {
        guard user != nil else { return }
        let context = contextID, client = api
        syncState = "正在同步…"
        syncError = nil
        do {
            let remote: ReadingLibrary = try await client.post("me/library", body: library)
            guard context == contextID, !Task.isCancelled else { return }
            library = library.merging(remote)
            persistLibrary()
            syncState = "已同步至账号"
        } catch is CancellationError { }
        catch { if context == contextID { syncError = error.localizedDescription; syncState = "同步未完成" } }
    }
    private func changedLibrary() {
        library = library.merging(ReadingLibrary())
        persistLibrary()
        guard user != nil else { return }
        syncTask?.cancel()
        syncState = "等待同步"
        syncTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(500)); await self?.syncLibrary() } catch { }
        }
    }
    func contains(_ path: String, in kind: LibraryKind) -> Bool { library[kind].contains { $0.path == path } }
    func toggle(_ item: SavedItem, kind: LibraryKind) {
        guard let route = Route(path: item.path), route.isSavable else { return }
        if contains(item.path, in: kind) { remove(item.path, kind: kind); return }
        var item = item
        item.savedAt = max(Int64(Date().timeIntervalSince1970 * 1000), (library.removed?["\(kind.rawValue):\(item.path)"] ?? 0) + 1)
        library[kind].insert(item, at: 0)
        changedLibrary()
    }
    func remove(_ path: String, kind: LibraryKind) {
        library[kind].removeAll { $0.path == path }
        if library.removed == nil { library.removed = [:] }
        library.removed?["\(kind.rawValue):\(path)"] = Int64(Date().timeIntervalSince1970 * 1000)
        changedLibrary()
    }
    func record(_ item: SavedItem) {
        guard let route = Route(path: item.path), route.isSavable else { return }
        var item = item
        item.savedAt = Int64(Date().timeIntervalSince1970 * 1000)
        library.history.removeAll { $0.path == item.path }
        library.history.insert(item, at: 0)
        changedLibrary()
    }
    func recordRead(_ article: Article) async {
        record(article.libraryItem)
        guard recordedReads.insert(article.id).inserted else { return }
        struct Read: Encodable { let readerId: String }
        do {
            let _: Acknowledgement = try await api.post("articles/\(article.id)/read", body: Read(readerId: readerID))
        } catch { recordedReads.remove(article.id) }
    }
    func rememberSearch(_ query: String) {
        library.searches.removeAll { $0 == query }
        library.searches.insert(query, at: 0)
        changedLibrary()
    }

    private struct CachedDashboard: Codable { let date: Date; let value: Dashboard }
    private var cacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("life-dashboard-\(namespace).json")
    }
    private func loadDashboardCache() {
        guard let url = cacheURL, let data = try? Data(contentsOf: url),
              let saved = try? JSONDecoder().decode(CachedDashboard.self, from: data),
              Date().timeIntervalSince(saved.date) >= 0, Date().timeIntervalSince(saved.date) < 86400 else { return }
        dashboard = saved.value
        cachedAt = saved.date
        dashboardUpdatedAt = saved.date
    }
    private func saveDashboardCache(_ value: Dashboard) {
        guard let url = cacheURL, let data = try? JSONEncoder().encode(CachedDashboard(date: Date(), value: value)) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

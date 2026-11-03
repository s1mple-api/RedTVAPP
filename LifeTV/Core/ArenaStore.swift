import Foundation
import Observation

struct ArenaFollow: Codable, Identifiable {
    let kind: String
    let resourceID: Int
    let title: String
    let subtitle: String
    let image: String
    let date: Date
    var id: String { "\(kind):\(resourceID)" }
    var route: Route? {
        switch kind { case "match": .arenaMatch(resourceID); case "event": .arenaEvent(resourceID); case "team": .arenaTeam(resourceID); case "player": .arenaPlayer(resourceID); default: nil }
    }
}

@MainActor @Observable final class ArenaStore {
    let api: WanmeiClient
    let matches = Resource<ArenaResult<[ArenaMatch]>>()
    let todayMatches = Resource<ArenaResult<[ArenaMatch]>>()
    let events = Resource<ArenaResult<ArenaPage<ArenaEvent>>>()
    let teams = Resource<ArenaResult<[ArenaTeam]>>()
    let players = Resource<ArenaResult<[ArenaPlayer]>>()
    var selectedDate = ArenaDate.calendar.startOfDay(for: Date())
    private(set) var follows: [ArenaFollow]
    private let defaults: UserDefaults
    @ObservationIgnored private var portraits: [Int: String] = [:]
    @ObservationIgnored private var portraitTasks: [Int: Task<String?, Never>] = [:]
    init(api: WanmeiClient = WanmeiClient(), defaults: UserDefaults = .standard) {
        self.api = api; self.defaults = defaults
        follows = defaults.data(forKey: "life.arena.follows").flatMap { try? JSONDecoder().decode([ArenaFollow].self, from: $0) } ?? []
    }
    func bootstrap() async {
        async let b: () = events.load { try await api.events() }
        async let c: () = teams.load { try await api.teams() }
        async let d: () = players.load { try await api.players() }
        _ = await (b, c, d)
    }
    func loadMatches() async {
        let date = selectedDate
        await matches.load(key: ArenaDate.dayKey(date)) { try await api.matches(on: date) }
        if matches.error != nil, let previous = matches.value {
            matches.value = Date().timeIntervalSince(previous.fetchedAt) < 86400 ? ArenaResult(value: previous.value, fetchedAt: previous.fetchedAt, cached: true) : nil
        }
        if ArenaDate.dayKey(date) == ArenaDate.dayKey(Date()), ArenaDate.dayKey(selectedDate) == ArenaDate.dayKey(date), let value = matches.value {
            todayMatches.value = value
        }
    }
    func loadMatchCenter() async {
        async let schedule: () = loadMatches()
        if ArenaDate.dayKey(selectedDate) != ArenaDate.dayKey(Date()) {
            let today = Date()
            await todayMatches.load(key: ArenaDate.dayKey(today)) { try await api.matches(on: today) }
        }
        await schedule
    }
    func portrait(for player: ArenaPlayer) async -> String? {
        if let url = URL(string: player.image), url.scheme == "https", url.pathExtension != "svg" { return player.image }
        if let image = portraits[player.id] { return image }
        if let known = teams.value?.value.flatMap(\.players).first(where: { $0.id == player.id }), known.image.hasPrefix("https://") { return known.image }
        if let task = portraitTasks[player.id] { return await task.value }
        let task = Task<String?, Never> { [api] in
            guard let result = try? await api.player(player.id), result.value.player.image.hasPrefix("https://") else { return nil }
            return result.value.player.image
        }
        portraitTasks[player.id] = task
        let image = await task.value
        portraits[player.id] = image
        portraitTasks[player.id] = nil
        return image
    }
    func isFollowed(_ kind: String, _ id: Int) -> Bool { follows.contains { $0.kind == kind && $0.resourceID == id } }
    func toggle(kind: String, id: Int, title: String, subtitle: String, image: String = "") {
        guard id > 0 else { return }
        if isFollowed(kind, id) { follows.removeAll { $0.kind == kind && $0.resourceID == id } }
        else { follows.insert(ArenaFollow(kind: kind, resourceID: id, title: title, subtitle: subtitle, image: image, date: Date()), at: 0) }
        follows = Array(follows.prefix(300))
        defaults.set(try? JSONEncoder().encode(follows), forKey: "life.arena.follows")
    }
    func remove(_ item: ArenaFollow) {
        follows.removeAll { $0.id == item.id }
        defaults.set(try? JSONEncoder().encode(follows), forKey: "life.arena.follows")
    }
}

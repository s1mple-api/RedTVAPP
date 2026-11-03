import SwiftUI

struct ArenaEventView: View {
    @Environment(ArenaStore.self) private var arena
    let id: Int
    var seed: ArenaEvent? = nil
    @State private var resource = Resource<ArenaResult<ArenaEvent>>()
    @State private var matches = Resource<ArenaResult<[ArenaMatch]>>()
    @State private var section = 0
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if seed?.type != nil && seed?.type != 1, let event = seed {
                    eventHeader(event)
                    Notice(text: "此赛事使用独立赛事系统，完整赛程请前往来源查看。")
                    SourceLink(raw: event.sourceURL.absoluteString)
                } else {
                    ResourceContent(resource: resource, retry: { Task { await load() } }) { result in
                        let event = result.value
                        eventHeader(event)
                        Picker("赛事内容", selection: $section) { Text("赛程").tag(0); Text("参赛战队").tag(1) }.pickerStyle(.segmented)
                        if section == 0 {
                            ResourceContent(resource: matches, retry: { Task { await loadMatches() } }) { result in
                                if result.value.isEmpty { EmptyState(title: "赛程尚未公布", message: "来源发布比赛后会显示在这里。", icon: "calendar") }
                                ForEach(result.value.sorted { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }) { match in
                                    Text(ArenaDate.format(match.start, pattern: "M 月 d 日 EEE")).font(.caption2).foregroundStyle(.secondary)
                                    ArenaMatchCard(match: match)
                                }
                                if result.value.count >= 100 { Notice(text: "当前展示来源前 100 场比赛，完整赛程可在来源查看。") }
                                ArenaStamp(date: result.fetchedAt, cached: result.cached)
                            }
                        } else {
                            if event.teams.isEmpty { EmptyState(title: "参赛阵容待公布", icon: "shield") }
                            ForEach(event.teams) { team in NavigationLink(value: Route.arenaTeam(team.id)) { HStack { ArenaTeamAvatar(team: team); Text(team.name).font(.headline); Spacer(); Image(systemName: "chevron.right").font(.caption) }.padding(14).background(RedTheme.card, in: RoundedRectangle(cornerRadius: 12)) }.buttonStyle(.plain) }
                        }
                        ArenaStamp(date: result.fetchedAt, cached: result.cached)
                        SourceLink(raw: event.sourceURL.absoluteString, title: "在完美世界电竞查看赛事")
                    }
                }
            }.padding(18).redPage()
        }.background(RedTheme.paper).navigationTitle("赛事详情").navigationBarTitleDisplayMode(.inline).redDetailNavigation()
            .task(id: id) { if seed?.type == nil || seed?.type == 1 { await load() } }.refreshable { await load() }
    }
    private func eventHeader(_ event: ArenaEvent) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { ArenaAvatar(url: event.logo, size: 70); Spacer(); ArenaBadge(text: event.stateLabel, live: event.status == 1) }
            Text(event.name).font(.title.bold())
            if event.englishName != event.name { Text(event.englishName).font(.caption).foregroundStyle(.secondary) }
            DetailFacts(values: [("赛期", event.dateRange), ("地点", event.location), ("总奖金", event.prize), ("参赛战队", "\(event.teamCount)"), ("赛事级别", event.tier)])
            ArenaFollowButton(kind: "event", id: id, title: event.name, subtitle: event.dateRange, image: event.logo)
        }
    }
    private func load() async {
        guard seed?.type == nil || seed?.type == 1 else { return }
        async let a: () = resource.load(key: "\(id)") { try await arena.api.event(id) }
        async let b: () = loadMatches()
        _ = await (a, b)
    }
    private func loadMatches() async { await matches.load(key: "\(id)") { try await arena.api.eventMatches(id) } }
}

struct ArenaTeamView: View {
    @Environment(ArenaStore.self) private var arena
    let id: Int
    @State private var resource = Resource<ArenaResult<ArenaTeam>>()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ResourceContent(resource: resource, retry: { Task { await load() } }) { result in
                    let team = result.value
                    Eyebrow(text: "TEAM PROFILE")
                    HStack(spacing: 18) { ArenaTeamAvatar(team: team, size: 84); VStack(alignment: .leading, spacing: 8) { Text(team.name).font(.largeTitle.bold()); Text("CS2 战队").font(.subheadline).foregroundStyle(.secondary) } }
                    ArenaFollowButton(kind: "team", id: id, title: team.name, subtitle: "CS2 战队", image: team.logo)
                    DetailFacts(values: [("HLTV 排名", team.hltvRank.map { "#\($0)" } ?? "暂无排名"), ("HLTV 积分", team.hltvPoints.map { String(format: "%.0f", $0) } ?? "–"), ("Valve 排名", team.rank.map { "#\($0)" } ?? "暂无排名"), ("Valve 积分", team.points.map { String(format: "%.0f", $0) } ?? "–")])
                    SectionHeading(title: "当前阵容")
                    if team.players.isEmpty { EmptyState(title: "阵容暂未同步", icon: "person.3") }
                    VStack(spacing: 0) { ForEach(team.players) { player in NavigationLink(value: Route.arenaPlayer(player.id)) { ArenaPlayerRow(player: player) }.buttonStyle(.plain); Divider() } }.padding(.horizontal, 14).background(RedTheme.card, in: RoundedRectangle(cornerRadius: 14))
                    Text("阵容内评分采用来源返回的生涯 Rating；与列表 Impact 指标口径不同。").font(.caption2).foregroundStyle(.secondary)
                    ArenaStamp(date: result.fetchedAt, cached: result.cached)
                    SourceLink(raw: "https://data.wanmei.com/csgo/teams/detail/\(id)", title: "查看战队完整数据")
                }
            }.padding(18).redPage()
        }.background(RedTheme.paper).navigationTitle("战队").navigationBarTitleDisplayMode(.inline).redDetailNavigation().task(id: id) { await load() }.refreshable { await load() }
    }
    private func load() async { await resource.load(key: "\(id)") { try await arena.api.team(id) } }
}


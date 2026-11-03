import SwiftUI

struct ArenaHomeView: View {
    @Environment(ArenaStore.self) private var arena
    @State private var filter = "all"
    @State private var calendar = false
    @State private var dateAnchor = ArenaDate.calendar.startOfDay(for: Date())
    private var matches: [ArenaMatch] {
        ArenaSchedule.prioritized((arena.matches.value?.value ?? []).filter { match in
            filter == "all" || (filter == "live" && match.status == 1) || (filter == "next" && match.status == 2) || (filter == "done" && match.status == 3) || (filter == "follow" && (arena.isFollowed("match", match.id) || arena.isFollowed("event", match.eventID) || arena.isFollowed("team", match.team1.id) || arena.isFollowed("team", match.team2.id)))
        })
    }
    var body: some View {
        @Bindable var arena = arena
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if let result = arena.todayMatches.value, !ArenaSchedule.highlights(result.value).isEmpty {
                    HStack { Text("今日焦点").font(.headline); Spacer(); Text("按关注度排序").font(.caption).foregroundStyle(.secondary) }
                    ArenaFeaturedMatchDeck(matches: ArenaSchedule.highlights(result.value))
                    if result.cached { Notice(text: "焦点比分来自缓存 · \(ArenaDate.format(result.fetchedAt))，下拉刷新检查最新赛况。", icon: "clock.arrow.circlepath") }
                } else if arena.matches.isLoading || arena.todayMatches.isLoading {
                    HStack { ProgressView(); Text("正在寻找今日焦点…").font(.subheadline).foregroundStyle(.secondary) }.frame(maxWidth: .infinity).padding(26).background(LifeTheme.card, in: RoundedRectangle(cornerRadius: 16))
                }
                HStack {
                    Button { calendar = true } label: { Label(ArenaDate.format(arena.selectedDate, pattern: "yyyy 年 M 月"), systemImage: "calendar").font(.headline) }
                    Spacer()
                    Button("回到今天") { arena.selectedDate = ArenaDate.calendar.startOfDay(for: Date()); dateAnchor = arena.selectedDate }.font(.caption.bold())
                }
                FilterChips(values: [("all", "全部"), ("live", "进行中"), ("next", "未开始"), ("done", "已结束"), ("follow", "关注")], selection: $filter)
                HStack(alignment: .top, spacing: 12) {
                    dateRail.frame(width: 64)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack { Text(ArenaDate.format(arena.selectedDate, pattern: "M 月 d 日")).font(.subheadline.bold()); Spacer(); Text("\(matches.count) 场").font(.caption).foregroundStyle(.secondary) }
                        ResourceContent(resource: arena.matches, retry: { Task { await arena.loadMatchCenter() } }) { result in
                            if matches.isEmpty { EmptyState(title: "暂无比赛", message: "试试其他日期或筛选。", icon: "scope") }
                            scheduleGroup("焦点对局", subtitle: "有星级热度", rows: matches.filter { $0.stars > 0 }, accent: true)
                            scheduleGroup("更多比赛", subtitle: "暂无星级热度", rows: matches.filter { $0.stars == 0 }, accent: false)
                            ArenaStamp(date: result.fetchedAt, cached: result.cached)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("星级由完美世界电竞提供，用于比赛关注度排序，不代表观看人数。时间均为北京时间，比分下拉更新。").font(.caption2).foregroundStyle(.secondary).lineSpacing(4)
            }.padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 24).lifePage()
        }.lifeTabPage("赛场", subtitle: "每一局，都值得关注。", key: "arena")
            .refreshable { await arena.loadMatchCenter() }
            .task(id: ArenaDate.dayKey(arena.selectedDate)) { await arena.loadMatchCenter() }
            .onChange(of: arena.selectedDate) { _, day in
                let offset = ArenaDate.calendar.dateComponents([.day], from: dateAnchor, to: day).day ?? 0
                if offset < 0 || offset > 6 { dateAnchor = ArenaDate.calendar.startOfDay(for: day) }
            }
            .sheet(isPresented: $calendar) {
                NavigationStack {
                    DatePicker("比赛日期", selection: $arena.selectedDate, displayedComponents: .date).datePickerStyle(.graphical).environment(\.timeZone, ArenaDate.timeZone).padding()
                        .navigationTitle("选择比赛日期").navigationBarTitleDisplayMode(.inline).lifeDetailNavigation()
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { calendar = false } } }
                }.presentationDetents([.medium, .large])
            }
    }
    @ViewBuilder private func scheduleGroup(_ title: String, subtitle: String, rows: [ArenaMatch], accent: Bool) -> some View {
        if !rows.isEmpty {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(accent ? LifeTheme.red : Color.secondary).frame(width: 3, height: 14)
                Text(title).font(.subheadline.bold())
                Spacer(minLength: 0)
                Text("\(rows.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary).padding(.top, -8)
            ForEach(rows) { ArenaCompactMatchCard(match: $0) }
        }
    }
    private var dateRail: some View {
        VStack(spacing: 7) {
            Button { shift(-7) } label: { Image(systemName: "chevron.up").frame(width: 60, height: 32) }.accessibilityLabel("前一周")
            ForEach(0...6, id: \.self) { offset in
                let day = ArenaDate.calendar.date(byAdding: .day, value: offset, to: dateAnchor)!
                let selected = ArenaDate.dayKey(day) == ArenaDate.dayKey(arena.selectedDate)
                Button { arena.selectedDate = day } label: {
                    VStack(spacing: 5) {
                        Text(ArenaDate.calendar.isDate(day, inSameDayAs: Date()) ? "今天" : ArenaDate.format(day, pattern: "EEE")).font(.system(size: 10))
                        Text(ArenaDate.format(day, pattern: "dd")).font(.system(size: 22, weight: .bold, design: .rounded))
                        Text(ArenaDate.format(day, pattern: "M月")).font(.system(size: 9))
                    }.frame(width: 60).padding(.vertical, 11).foregroundStyle(selected ? Color.white : Color.secondary)
                        .background(selected ? LifeTheme.red : LifeTheme.card, in: RoundedRectangle(cornerRadius: 13))
                }.buttonStyle(.plain).accessibilityLabel(ArenaDate.format(day, pattern: "M月d日"))
            }
            Button { shift(7) } label: { Image(systemName: "chevron.down").frame(width: 60, height: 32) }.accessibilityLabel("后一周")
        }
    }
    private func shift(_ days: Int) {
        dateAnchor = ArenaDate.calendar.date(byAdding: .day, value: days, to: dateAnchor)!
        arena.selectedDate = dateAnchor
    }
}

struct ArenaEventsView: View {
    @Environment(ArenaStore.self) private var arena
    @State private var ended = false
    @State private var page = 1
    @State private var resource = Resource<ArenaResult<ArenaPage<ArenaEvent>>>()
    private var key: String { "\(ended)-\(page)" }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Picker("赛事状态", selection: $ended) { Text("正在进行 / 即将开始").tag(false); Text("已结束").tag(true) }.pickerStyle(.segmented)
                ResourceContent(resource: resource, retry: { Task { await load() } }) { result in
                    Text("共 \(result.value.total) 项赛事").font(.caption).foregroundStyle(.secondary)
                    if result.value.items.isEmpty { EmptyState(icon: "trophy") }
                    ForEach(result.value.items.sorted {
                        if !ended, ($0.status == 1) != ($1.status == 1) { return $0.status == 1 }
                        return ended ? ($0.start ?? .distantPast) > ($1.start ?? .distantPast) : ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture)
                    }) { event in
                        NavigationLink { ArenaEventView(id: event.id, seed: event) } label: { ArenaEventCard(event: event) }.buttonStyle(.plain)
                    }
                    PageControls(page: page, pages: max(1, Int(ceil(Double(result.value.total) / 30)))) { page = $0 }
                    ArenaStamp(date: result.fetchedAt, cached: result.cached)
                }
            }.padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 24).lifePage()
        }.lifeTabPage("赛事", subtitle: "追踪赛程，见证每一段冠军征途。", key: "events")
            .task(id: key) { await load() }.refreshable { await load() }.onChange(of: ended) { _, _ in page = 1 }
    }
    private func load() async { await resource.load(key: key) { try await arena.api.events(page: page, ended: ended) } }
}

struct ArenaDataView: View {
    @Environment(ArenaStore.self) private var arena
    @State private var mode = 0
    @State private var region = -1
    @State private var ranking = ArenaRanking.hltv
    @State private var teamPage = 1
    @State private var playerPage = 1
    @State private var teams = Resource<ArenaResult<[ArenaTeam]>>()
    @State private var players = Resource<ArenaResult<[ArenaPlayer]>>()
    private var key: String { "\(mode)-\(ranking.rawValue)-\(region)-\(teamPage)-\(playerPage)" }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Picker("数据类型", selection: $mode) { Text("战队排名").tag(0); Text("选手数据").tag(1) }.pickerStyle(.segmented)
                if mode == 0 {
                    Picker("战队榜单", selection: $ranking) { ForEach(ArenaRanking.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented).accessibilityIdentifier("team-ranking-picker")
                    HStack {
                        Text(ranking == .hltv ? "HLTV 战队排名" : "Valve VRS 战队排名").font(.subheadline.bold())
                        Spacer()
                        Picker("战队地区", selection: $region) { ForEach(ranking.regions, id: \.0) { Text($0.1).tag($0.0) } }.font(.caption).tint(.secondary)
                    }
                    ResourceContent(resource: teams, retry: { Task { await load() } }) { result in
                        if result.value.isEmpty { EmptyState(icon: "shield") }
                        VStack(spacing: 0) {
                            ForEach(result.value) { team in
                                NavigationLink(value: Route.arenaTeam(team.id)) { ArenaTeamRow(team: team) }.buttonStyle(.plain)
                                if team.id == result.value.first?.id { ArenaRosterStrip(team: team) }
                                Divider()
                            }
                        }.padding(.horizontal, 12).background(LifeTheme.card, in: RoundedRectangle(cornerRadius: 16))
                        if ranking == .valve { pagination(page: $teamPage, count: result.value.count) }
                        ArenaStamp(date: result.fetchedAt, cached: result.cached)
                        Text(ranking == .hltv ? "完美世界同步的 HLTV 排名与积分。" : "完美世界同步的 Valve VRS 排名与积分，与 HLTV 独立统计。").font(.caption2).foregroundStyle(.secondary)
                    }
                } else {
                    HStack { Text("选手表现"); Spacer(); Text("Impact") }.font(.caption2).foregroundStyle(.secondary)
                    ResourceContent(resource: players, retry: { Task { await load() } }) { result in
                        if result.value.isEmpty { EmptyState(icon: "person.crop.square") }
                        LazyVStack(spacing: 0) { ForEach(Array(result.value.enumerated()), id: \.element.id) { index, player in NavigationLink(value: Route.arenaPlayer(player.id)) { ArenaPlayerRow(player: player, index: (playerPage - 1) * 30 + index + 1) }.buttonStyle(.plain); Divider() } }.padding(.horizontal, 12).background(LifeTheme.card, in: RoundedRectangle(cornerRadius: 16))
                        pagination(page: $playerPage, count: result.value.count)
                        ArenaStamp(date: result.fetchedAt, cached: result.cached)
                        Text("列表指标为来源 Impact；选手详情保留来源提供的 Rating 版本与生涯统计。").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }.padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 24).lifePage()
        }.lifeTabPage("数据", subtitle: "战队排名与选手表现，一目了然。", key: "data")
            .task(id: key) { await load() }.refreshable { await load() }.onChange(of: region) { _, _ in teamPage = 1 }
            .onChange(of: ranking) { _, value in region = value.defaultRegion; teamPage = 1 }
    }
    private func pagination(page: Binding<Int>, count: Int) -> some View {
        HStack { Button("上一页") { page.wrappedValue -= 1 }.disabled(page.wrappedValue <= 1); Spacer(); Text("第 \(page.wrappedValue) 页").font(.caption.monospacedDigit()); Spacer(); Button("下一页") { page.wrappedValue += 1 }.disabled(count < 30) }.font(.subheadline).buttonStyle(.bordered)
    }
    private func load() async {
        if mode == 0 { await teams.load(key: "\(ranking.rawValue)-\(region)-\(teamPage)") { try await arena.api.teams(ranking: ranking, region: region, page: teamPage) } }
        else { await players.load(key: "\(playerPage)") { try await arena.api.players(page: playerPage) } }
    }
}

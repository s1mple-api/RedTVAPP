import SwiftUI

struct ArenaPlayerProfileView: View {
    @Environment(ArenaStore.self) private var arena
    let id: Int
    @State private var profile = Resource<ArenaResult<ArenaPlayerDetailData>>()
    @State private var upcoming = Resource<ArenaResult<ArenaPlayerMatches>>()
    @State private var recent = Resource<ArenaResult<ArenaPlayerMatches>>()
    @State private var career = Resource<ArenaResult<ArenaPlayerCareer>>()
    @State private var section = 0
    @State private var honorFilter = "全部"
    @State private var recentPage = 1

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ResourceContent(resource: profile, retry: { Task { await loadProfile() } }) { result in
                    profileHeader(result.value)
                    Picker("选手内容", selection: $section) { Text("基础信息").tag(0); Text("比赛赛程").tag(1); Text("历史荣誉").tag(2) }.pickerStyle(.segmented)
                    if section == 0 { overview(result.value) }
                    else if section == 1 { matchSections }
                    else { honorSection(result.value) }
                    ArenaStamp(date: result.fetchedAt, cached: result.cached)
                    SourceLink(raw: "https://data.wanmei.com/csgo/players/\(id)", title: "在完美世界电竞查看选手")
                }
            }.padding(20).redPage()
        }.background(RedTheme.paper).navigationTitle("选手").navigationBarTitleDisplayMode(.inline).redDetailNavigation()
            .task(id: id) { await load() }.refreshable { await load() }
            .onChange(of: recentPage) { _, _ in Task { await loadRecent() } }
    }

    private func profileHeader(_ details: ArenaPlayerDetailData) -> some View {
        let player = details.profile.player
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 18) {
                ArenaAvatar(url: player.image, size: 108, player: true)
                VStack(alignment: .leading, spacing: 7) {
                    Text(player.name).font(.largeTitle.bold()).lineLimit(1).minimumScaleFactor(0.7)
                    Text(details.profile.realName).font(.subheadline).foregroundStyle(.secondary)
                    Text(player.country).font(.caption).foregroundStyle(.secondary)
                    if let teamID = player.teamID, teamID > 0 { NavigationLink(value: Route.arenaTeam(teamID)) { Label(player.teamName, systemImage: "shield").font(.subheadline.bold()) } }
                }
                Spacer(minLength: 0)
            }
            ArenaFollowButton(kind: "player", id: id, title: player.name, subtitle: player.teamName, image: player.image)
        }
    }

    @ViewBuilder private func overview(_ details: ArenaPlayerDetailData) -> some View {
        SectionHeading(title: "八维概览", subtitle: "7 项角色能力 + Rating 指标")
        VStack(spacing: 10) {
            ArenaPlayerRadar(dimensions: details.dimensions).frame(height: 310)
            Text("能力以 0–100 刻度展示。Rating 轴采用来源位置值，原始 Rating 另列于下方。").font(.caption2).foregroundStyle(.secondary).lineSpacing(4)
        }.padding(14).background(RedTheme.card, in: RoundedRectangle(cornerRadius: 18))
        if details.dimensions.contains(where: { $0.value == nil }) { Notice(text: "部分能力数据暂未公布。") }
        if !details.profile.rating.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text(details.profile.rating).font(.system(size: 48, weight: .black, design: .rounded)).foregroundStyle(RedTheme.positive)
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text(details.profile.ratingLabel.isEmpty ? "来源 Rating" : details.profile.ratingLabel).font(.headline)
                    if let maps = details.mapCount { Text("当前统计 \(maps) 张地图").font(.caption).foregroundStyle(.secondary) }
                }
            }.padding(18).background(RedTheme.card, in: RoundedRectangle(cornerRadius: 16))
        }
        DetailFacts(values: details.sideRatings + details.profile.metrics)
        SectionHeading(title: "基础资料")
        DetailFacts(values: [("姓名", details.profile.realName), ("国籍", details.profile.player.country), ("战队", details.profile.player.teamName), ("累计奖金", details.prize)] + (!details.majorMVP.isEmpty ? [("Major MVP", details.majorMVP)] : []) + (!details.majorWins.isEmpty ? [("Major 冠军", details.majorWins)] : []))
        top20Summary(details)
    }

    @ViewBuilder private func top20Summary(_ details: ArenaPlayerDetailData) -> some View {
        if !details.top20.isEmpty {
            SectionHeading(title: "HLTV TOP20")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(details.top20) { entry in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(String(entry.year)).font(.caption).foregroundStyle(.secondary)
                            Text("#\(entry.rank)").font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(RedTheme.red)
                        }.padding(16).frame(width: 110, alignment: .leading).background(RedTheme.card, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
    }

    private var matchSections: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeading(title: "即将开始", subtitle: "来源已公布的选手所在战队赛程")
            ResourceContent(resource: upcoming, retry: { Task { await loadUpcoming() } }) { result in
                if result.value.records.isEmpty { EmptyState(title: "暂无即将开始的比赛", message: "来源公布赛程后会显示在这里。", icon: "calendar") }
                ForEach(result.value.records) { record in matchRecord(record) }
                ArenaStamp(date: result.fetchedAt, cached: result.cached)
            }
            SectionHeading(title: "近期比赛")
            ResourceContent(resource: recent, retry: { Task { await loadRecent() } }) { result in
                if result.value.records.isEmpty { EmptyState(title: "暂无近期比赛", icon: "scope") }
                ForEach(result.value.records) { record in matchRecord(record) }
                HStack { Button("上一页") { recentPage -= 1 }.disabled(recentPage <= 1); Spacer(); Text("第 \(recentPage) 页").font(.caption.monospacedDigit()); Spacer(); Button("下一页") { recentPage += 1 }.disabled(!result.value.hasMore) }.buttonStyle(.bordered).font(.subheadline)
                ArenaStamp(date: result.fetchedAt, cached: result.cached)
            }
        }
    }
    private func matchRecord(_ record: ArenaPlayerMatchRecord) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text(ArenaDate.format(record.match.start, pattern: "yyyy.MM.dd HH:mm")).font(.caption2).foregroundStyle(.secondary); Spacer(); if let rating = record.rating { Text("Rating \(String(format: "%.2f", rating))").font(.caption2.bold()).foregroundStyle(RedTheme.positive) } }
            ArenaCompactMatchCard(match: record.match)
        }
    }

    @ViewBuilder private func honorSection(_ details: ArenaPlayerDetailData) -> some View {
        top20Summary(details)
        SectionHeading(title: "历史荣誉", subtitle: "MVP、EVP、TOP20 与赛事成绩分别标识")
        FilterChips(values: ["全部", "MVP", "TOP20", "冠军", "EVP"].map { ($0, $0) }, selection: $honorFilter)
        ResourceContent(resource: career, retry: { Task { await loadCareer() } }) { result in
            let rows = result.value.honors.filter { honorFilter == "全部" || $0.kind.rawValue == honorFilter }
            if rows.isEmpty { EmptyState(title: "暂无此类荣誉", message: "当前来源未提供该分类记录。", icon: "trophy") }
            ForEach(rows) { honor in
                HStack(alignment: .top, spacing: 12) {
                    ArenaAvatar(url: honor.image, size: 48)
                    VStack(alignment: .leading, spacing: 7) {
                        HStack { ArenaBadge(text: honor.badge); Spacer(); Text(honor.year).font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                        Text(honor.name).font(.subheadline.bold())
                        if let date = honor.date { Text(ArenaDate.format(date, pattern: "yyyy.MM.dd")).font(.caption2).foregroundStyle(.secondary) }
                        if let event = honor.eventID, event > 0 { NavigationLink("赛事详情", value: Route.arenaEvent(event)).font(.caption) }
                    }
                }.padding(14).background(RedTheme.card, in: RoundedRectangle(cornerRadius: 14))
            }
            ArenaStamp(date: result.fetchedAt, cached: result.cached)
        }
    }

    private func load() async {
        async let a: () = loadProfile()
        async let b: () = loadUpcoming()
        async let c: () = loadRecent()
        async let d: () = loadCareer()
        _ = await (a, b, c, d)
    }
    private func loadProfile() async { await profile.load(key: "\(id)") { try await arena.api.playerDetails(id) } }
    private func loadUpcoming() async { await upcoming.load(key: "\(id)") { try await arena.api.playerMatches(id, upcoming: true) } }
    private func loadRecent() async { await recent.load(key: "\(id)-\(recentPage)") { try await arena.api.playerMatches(id, upcoming: false, page: recentPage) } }
    private func loadCareer() async { await career.load(key: "\(id)") { try await arena.api.playerCareer(id) } }
}

private struct ArenaPlayerRadar: View {
    let dimensions: [ArenaPlayerDimension]
    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = min(proxy.size.width, proxy.size.height) * 0.30
            ZStack {
                ForEach(1...4, id: \.self) { level in polygon(center: center, radius: radius, values: Array(repeating: Double(level) / 4, count: dimensions.count)).stroke(.primary.opacity(0.08), lineWidth: 1) }
                ForEach(Array(dimensions.enumerated()), id: \.element.id) { index, dimension in
                    Path { path in path.move(to: center); path.addLine(to: point(index, center: center, radius: radius)) }.stroke(.primary.opacity(0.10), lineWidth: 1)
                    VStack(spacing: 3) {
                        Text(dimension.name).font(.system(size: 10)).foregroundStyle(.secondary)
                        Text(dimension.value.map { String(format: "%.0f", $0) } ?? "–").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(RedTheme.red)
                    }.frame(width: 68).position(point(index, center: center, radius: radius + 31))
                }
                if dimensions.allSatisfy({ $0.value != nil }) {
                    let shape = polygon(center: center, radius: radius, values: dimensions.map { ($0.value ?? 0) / 100 })
                    shape.fill(RedTheme.red.opacity(0.15))
                    shape.stroke(RedTheme.red, lineWidth: 2)
                }
            }
        }.accessibilityElement(children: .ignore).accessibilityLabel("八维概览，7 项角色能力和 Rating 指标。" + dimensions.map { "\($0.name) \($0.value.map { String(format: "%.0f", $0) } ?? "暂无数据")" }.joined(separator: "，"))
    }
    private func point(_ index: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = Double(index) / Double(max(1, dimensions.count)) * .pi * 2 - .pi / 2
        return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }
    private func polygon(center: CGPoint, radius: CGFloat, values: [Double]) -> Path {
        Path { path in
            for index in values.indices {
                let point = point(index, center: center, radius: radius * values[index])
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
        }
    }
}

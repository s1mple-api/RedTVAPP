import SwiftUI

struct ArenaMatchCenterDetailView: View {
    @Environment(ArenaStore.self) private var arena
    @Environment(\.scenePhase) private var scenePhase
    let id: Int
    @State private var resource = Resource<ArenaResult<ArenaMatchCenterDetail>>()
    @State private var analysis = Resource<ArenaResult<ArenaMatchMapAnalysis>>()
    @State private var live = ArenaLiveRounds()
    @State private var connectionGeneration = 0
    @State private var selectedStatsID: String?
    @State private var statsMode = MatchStatsMode.players
    private var liveKey: String {
        let match = resource.value?.value.match
        return "\(match?.namiID ?? 0)-\(match?.status ?? 0)-\(scenePhase == .active)-\(connectionGeneration)"
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ResourceContent(resource: resource, retry: { Task { await load() } }) { result in
                    header(result.value)
                    overview(result.value)
                    sectionDivider
                    postMatch(result.value)
                    sectionDivider
                    mapAnalysis(result.value)
                    ArenaStamp(date: result.fetchedAt, cached: result.cached)
                    SourceLink(raw: result.value.match.sourceURL.absoluteString, title: "在完美世界电竞查看比赛")
                }
            }.padding(20).lifePage()
        }.background(LifeTheme.paper).navigationTitle("比赛详情").navigationBarTitleDisplayMode(.inline).lifeDetailNavigation()
            .task(id: id) { await load() }
            .task(id: liveKey) {
                guard scenePhase == .active, let detail = resource.value?.value, detail.match.status == 1, let namiID = detail.match.namiID, namiID > 0 else { live.stop(); return }
                await live.connect(namiMatchID: namiID, team1NamiID: detail.namiTeam1ID, team2NamiID: detail.namiTeam2ID)
            }
            .task(id: live.score?.mapEnded) {
                guard live.score?.mapEnded == true else { return }
                do { try await Task.sleep(for: .seconds(2)); try Task.checkCancellation() } catch { return }
                await resource.load(key: String(id)) { try await arena.api.matchCenterDetail(id) }
            }
            .onChange(of: scenePhase) { _, phase in if phase != .active { live.stop() } }
            .onDisappear { live.stop() }
            .refreshable { connectionGeneration += 1; await load() }
    }

    private func header(_ detail: ArenaMatchCenterDetail) -> some View {
        let match = detail.match
        return VStack(alignment: .leading, spacing: 17) {
            HStack { ArenaBadge(text: match.stateLabel, live: match.status == 1); Spacer(); Text(match.bestOf).font(.caption.monospaced()).foregroundStyle(.secondary) }
            if match.eventID > 0 {
                NavigationLink(value: Route.arenaEvent(match.eventID)) { Label(match.eventName.isEmpty ? "所属赛事" : match.eventName, systemImage: "trophy").font(.subheadline.bold()) }
            }
            VStack(spacing: 14) {
                HStack(alignment: .center, spacing: 8) {
                    teamLink(match.team1)
                    score(match)
                    teamLink(match.team2)
                }
                Text(ArenaDate.format(match.start) + " · 北京时间").font(.caption2).foregroundStyle(.secondary)
            }.padding(.vertical, 20).padding(.horizontal, 10).frame(maxWidth: .infinity).background(LifeTheme.card, in: RoundedRectangle(cornerRadius: 18))
            if match.status == 1, live.score == nil {
                Notice(text: live.connecting ? "正在读取当前地图的小局比分，当前显示的数值为系列赛大局比分。" : (live.error ?? "来源暂未提供实时小局比分，当前显示系列赛大局比分。"))
            }
            HStack { ArenaFollowButton(kind: "match", id: id, title: match.title, subtitle: match.eventName); Spacer(); ShareLink(item: match.sourceURL) { Image(systemName: "square.and.arrow.up") }.buttonStyle(.bordered) }
            if !match.stage.isEmpty { Text(match.stage).font(.caption).foregroundStyle(.secondary) }
        }
    }
    @ViewBuilder private func score(_ match: ArenaMatch) -> some View {
        if match.status == 1, let score = live.score {
            VStack(spacing: 7) {
                Text("\(score.left) : \(score.right)").font(.system(size: 36, weight: .black, design: .rounded)).monospacedDigit()
                ArenaMapLabel(name: score.mapName, size: 18).font(.caption.bold()).foregroundStyle(LifeTheme.red)
                Text(score.mapEnded ? "该地图已结束" : score.round.map { "第 \($0) 回合" } ?? "当前地图小局比分").font(.system(size: 10)).foregroundStyle(.secondary)
                Text("大局 \(match.score1.map(String.init) ?? "–") : \(match.score2.map(String.init) ?? "–")").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }.frame(minWidth: 96).accessibilityIdentifier("match-live-score")
        } else {
            VStack(spacing: 8) {
                Text("\(match.score1.map(String.init) ?? "–") : \(match.score2.map(String.init) ?? "–")").font(.system(size: 36, weight: .black, design: .rounded)).monospacedDigit()
                Text(match.status == 2 ? "尚未开赛" : "系列赛大局比分").font(.system(size: 10)).foregroundStyle(.secondary)
            }.frame(minWidth: 96).accessibilityIdentifier("match-series-score")
        }
    }
    private func teamLink(_ team: ArenaTeam) -> some View {
        NavigationLink(value: Route.arenaTeam(team.id)) {
            VStack(spacing: 10) { ArenaTeamAvatar(team: team, size: 52); Text(team.name.isEmpty ? "待定" : team.name).font(.subheadline.bold()).multilineTextAlignment(.center).lineLimit(2) }.frame(maxWidth: .infinity)
        }.buttonStyle(.plain).disabled(team.id <= 0)
    }
    private var sectionDivider: some View {
        Rectangle().fill(.primary.opacity(0.07)).frame(height: 1).padding(.vertical, 8)
    }

    @ViewBuilder private func overview(_ detail: ArenaMatchCenterDetail) -> some View {
        MatchDetailSectionHeading(title: "地图 BP", subtitle: "按双方选禁顺序，还原本场地图流程", icon: "arrow.triangle.branch", identifier: "match-veto-section")
        if detail.vetoes.isEmpty {
            Notice(text: "地图选禁尚未公布，发布后会按顺序展示。")
        } else {
            VStack(spacing: 0) {
                ForEach(Array(detail.vetoes.enumerated()), id: \.element.id) { index, veto in
                    MatchVetoFlowStep(veto: veto, number: index + 1, isLast: index == detail.vetoes.count - 1)
                }
            }.accessibilityElement(children: .contain).accessibilityIdentifier("match-map-bp")
        }
    }

    @ViewBuilder private func postMatch(_ detail: ArenaMatchCenterDetail) -> some View {
        let maps = detail.completedMaps
        let selectedID = maps.contains(where: { $0.id == selectedStatsID }) ? selectedStatsID : nil
        let selectedMap = maps.first(where: { $0.id == selectedID })
        let stats = selectedMap ?? detail.overviewStats
        let selectionKey = selectedID ?? "all"
        MatchDetailSectionHeading(title: "赛后数据", subtitle: "查看全部地图或单图表现，也可切换选手对位", icon: "chart.bar.xaxis", identifier: "match-results-section")
        if maps.isEmpty {
            Notice(text: "尚无已结束地图数据，单图结束后会在这里展示。", icon: "clock")
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    statsMapButton(id: nil, name: "全部地图", selectedID: selectedID)
                    ForEach(maps) { map in statsMapButton(id: map.id, name: map.name, selectedID: selectedID) }
                }.padding(.vertical, 2)
            }.accessibilityIdentifier("match-stats-maps")
            Picker("数据展示方式", selection: $statsMode) {
                ForEach(MatchStatsMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
            }.pickerStyle(.segmented).accessibilityIdentifier("match-stats-mode")
            if statsMode == .players {
                VStack(alignment: .leading, spacing: 0) {
                    if let stats {
                        MatchPlayerStatsCard(map: stats, number: maps.firstIndex(where: { $0.id == selectedID }).map { $0 + 1 }, match: detail.match)
                    } else {
                        Notice(text: "来源尚未提供全部地图的选手总览，可选择单张地图查看。")
                    }
                }.accessibilityElement(children: .contain).accessibilityIdentifier("match-stats-players").accessibilityValue(selectionKey)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    if let stats, let duels = detail.duels(for: stats.id) {
                        MatchPlayerDuelsCard(map: stats, duels: duels, match: detail.match)
                    } else {
                        Notice(text: selectedID == nil ? "来源尚未提供全部地图的选手对位数据，可尝试选择单张地图。" : "来源尚未提供该地图的选手对位数据。")
                    }
                }.accessibilityElement(children: .contain).accessibilityIdentifier("match-stats-duels").accessibilityValue(selectionKey)
            }
        }
    }

    private func statsMapButton(id: String?, name: String, selectedID: String?) -> some View {
        let selected = id == selectedID
        return Button { selectedStatsID = id } label: {
            HStack(spacing: 6) {
                if id == nil { Image(systemName: "square.stack.3d.up").font(.subheadline) }
                else { ArenaMapIcon(name: name, size: 24) }
                Text(name).font(.caption.bold())
            }.padding(.horizontal, 12).frame(minHeight: 42)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(selected ? LifeTheme.red : LifeTheme.card, in: Capsule())
        }.buttonStyle(.plain).accessibilityIdentifier("match-stats-map-\(id ?? "all")")
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private func mapAnalysis(_ detail: ArenaMatchCenterDetail) -> some View {
        MatchDetailSectionHeading(title: "地图分析", subtitle: "两队的地图样本、胜率与选禁倾向", icon: "map", identifier: "match-analysis-section")
        HStack(spacing: 12) {
            analysisTeam(detail.match.team1)
            Text("对比").font(.caption2).foregroundStyle(.secondary)
            analysisTeam(detail.match.team2)
        }.padding(14).background(LifeTheme.card, in: RoundedRectangle(cornerRadius: 14))
        ResourceContent(resource: analysis, retry: { Task { await loadAnalysis(detail) } }) { result in
            if result.value.rows.isEmpty { Notice(text: "暂无这两支战队的地图分析数据。") }
            ForEach(result.value.rows) { row in MatchMapAnalysisCard(row: row) }
            ArenaStamp(date: result.fetchedAt, cached: result.cached)
        }
    }

    private func analysisTeam(_ team: ArenaTeam) -> some View {
        HStack(spacing: 8) { ArenaTeamAvatar(team: team, size: 26); Text(team.name.isEmpty ? "待定战队" : team.name).font(.subheadline.bold()).lineLimit(1) }.frame(maxWidth: .infinity)
    }
    private func load() async {
        await resource.load(key: String(id)) { try await arena.api.matchCenterDetail(id) }
        if let detail = resource.value?.value { await loadAnalysis(detail) }
    }
    private func loadAnalysis(_ detail: ArenaMatchCenterDetail) async {
        guard detail.match.team1.id > 0, detail.match.team2.id > 0 else { analysis.error = "战队信息尚未确认，暂无法分析地图。"; return }
        await analysis.load(key: "\(detail.match.team1.id)-\(detail.match.team2.id)") { try await arena.api.matchMapAnalysis(team1ID: detail.match.team1.id, team2ID: detail.match.team2.id) }
    }
}


private struct MatchDetailSectionHeading: View {
    let title: String
    let subtitle: String
    let icon: String
    let identifier: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: icon).font(.title3.bold()).foregroundStyle(.primary)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine).accessibilityIdentifier(identifier)
    }
}

private struct MatchVetoFlowStep: View {
    let veto: ArenaMapVeto
    let number: Int
    let isLast: Bool
    private var accent: Color { veto.type == 1 ? .secondary : LifeTheme.red }
    private var actionIcon: String { veto.type == 1 ? "minus.circle.fill" : veto.type == 2 ? "checkmark.circle.fill" : "flag.checkered" }
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%02d", number)).font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(accent).frame(width: 28, height: 28)
                .background(LifeTheme.paper, in: Circle())
                .overlay { Circle().strokeBorder(accent.opacity(0.35), lineWidth: 1.5) }
                .padding(.top, 18)
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 8) {
                    ArenaMapLabel(name: veto.name, size: 34).font(.subheadline.bold())
                        .opacity(veto.type == 1 ? 0.65 : 1)
                    Spacer(minLength: 4)
                    Label(veto.action, systemImage: actionIcon).font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accent).padding(.horizontal, 8).padding(.vertical, 6)
                        .background(accent.opacity(0.08), in: Capsule())
                }
                HStack(spacing: 7) {
                    if !veto.teamLogo.isEmpty { ArenaAvatar(url: veto.teamLogo, size: 18, contrastBackground: true) }
                    Text(veto.teamName.isEmpty ? (veto.type == 3 ? "双方剩余地图" : "队伍待定") : veto.teamName)
                        .font(.caption).foregroundStyle(.secondary)
                    if veto.type == 3 { Text("· 决胜地图").font(.caption).foregroundStyle(.secondary) }
                }
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(LifeTheme.card, in: RoundedRectangle(cornerRadius: 15))
        }.padding(.bottom, isLast ? 0 : 10)
            .background(alignment: .topLeading) {
                if !isLast {
                    GeometryReader { geometry in
                        Rectangle().fill(LifeTheme.red.opacity(0.16)).frame(width: 1.5, height: max(0, geometry.size.height - 14)).offset(x: 13.25, y: 45)
                    }.accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("第 \(number) 步，\(veto.teamName.isEmpty ? "双方" : veto.teamName)，\(veto.action)，\(veto.name)")
    }
}

private enum MatchStatsMode: String, CaseIterable, Identifiable {
    case players = "选手数据", duels = "对位数据"
    var id: Self { self }
}

private struct MatchPlayerStatsCard: View {
    let map: ArenaFullMapStats
    let number: Int?
    let match: ArenaMatch
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            MatchStatsMapHeading(map: map, number: number, match: match)
            Divider()
            if map.left.isEmpty && map.right.isEmpty { Notice(text: "来源尚未提供该地图的完整选手数据。") }
            playerTable(match.team1, rows: map.left)
            if !map.left.isEmpty && !map.right.isEmpty { Divider() }
            playerTable(match.team2, rows: map.right)
        }.padding(16).background(LifeTheme.card, in: RoundedRectangle(cornerRadius: 18))
            .accessibilityElement(children: .contain).accessibilityIdentifier("match-result-map-\(map.id)")
    }
    @ViewBuilder private func playerTable(_ team: ArenaTeam, rows: [ArenaPlayerLine]) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) { ArenaTeamAvatar(team: team, size: 23); Text(team.name).font(.subheadline.bold()) }.padding(.bottom, 12)
                HStack {
                    Text("选手").frame(maxWidth: .infinity, alignment: .leading)
                    Text("K–D").frame(width: 52)
                    Text("ADR").frame(width: 40)
                    Text("Rating").frame(width: 47)
                }.font(.system(size: 10)).foregroundStyle(.secondary)
                ForEach(rows) { line in
                    NavigationLink(value: Route.arenaPlayer(line.player.id)) {
                        HStack(spacing: 4) {
                            Text(line.player.name).font(.subheadline.weight(.medium)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(line.kills.map(String.init) ?? "–")–\(line.deaths.map(String.init) ?? "–")").frame(width: 52)
                            Text(line.adr.map { String(format: "%.0f", $0) } ?? "–").frame(width: 40)
                            Text(line.rating.map { String(format: "%.2f", $0) } ?? "–").frame(width: 47).foregroundStyle(LifeTheme.positive)
                        }.font(.caption.monospacedDigit()).padding(.vertical, 12)
                    }.buttonStyle(.plain)
                    if line.id != rows.last?.id { Divider().opacity(0.6) }
                }
            }
        }
    }
}

private struct MatchStatsMapHeading: View {
    let map: ArenaFullMapStats
    var number: Int? = nil
    let match: ArenaMatch
    var body: some View {
        HStack(spacing: 10) {
            if map.overview { Label("全部地图", systemImage: "square.stack.3d.up").font(.headline) }
            else { ArenaMapLabel(name: map.name, size: 38).font(.headline) }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                Text("\((map.overview ? match.score1 : map.score1).map(String.init) ?? "–") : \((map.overview ? match.score2 : map.score2).map(String.init) ?? "–")")
                    .font(.title2.monospacedDigit().bold())
                Text(map.overview ? "系列赛大局比分" : number.map { "第 \($0) 图 · 已结束" } ?? "已结束地图")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
    }
}

private struct MatchPlayerDuelsCard: View {
    let map: ArenaFullMapStats
    let duels: ArenaPlayerDuels
    let match: ArenaMatch
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MatchStatsMapHeading(map: map, match: match)
            HStack(spacing: 8) {
                ArenaTeamAvatar(team: match.team1, size: 22)
                Text(match.team1.name).lineLimit(1)
                Image(systemName: "arrow.left.arrow.right").foregroundStyle(.secondary)
                ArenaTeamAvatar(team: match.team2, size: 22)
                Text(match.team2.name).lineLimit(1)
            }.font(.caption.bold())
            Text("行选手击杀 : 被列选手击杀").font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                VStack(spacing: 5) {
                    HStack(alignment: .bottom, spacing: 4) {
                        Text("\(match.team1.name) ↓\n\(match.team2.name) →")
                            .font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(2)
                            .frame(width: 80, height: 58, alignment: .bottomLeading)
                        ForEach(duels.right) { player in
                            duelPlayer(player, vertical: true).frame(width: 52, height: 58)
                        }
                    }
                    ForEach(duels.left) { left in
                        HStack(spacing: 4) {
                            duelPlayer(left, vertical: false).frame(width: 80, height: 48, alignment: .leading)
                            ForEach(duels.right) { right in duelCell(left, right) }
                        }
                    }
                }.padding(.bottom, 7)
            }.accessibilityIdentifier("match-duel-matrix")
            Label("横向滑动查看完整对位", systemImage: "hand.draw")
                .font(.caption2).foregroundStyle(.secondary)
        }.padding(16).background(LifeTheme.card, in: RoundedRectangle(cornerRadius: 18))
    }
    @ViewBuilder private func duelPlayer(_ player: ArenaPlayer, vertical: Bool) -> some View {
        NavigationLink(value: Route.arenaPlayer(player.id)) {
            if vertical {
                VStack(spacing: 4) {
                    ArenaAvatar(url: player.image, size: 28, player: true)
                    Text(player.name).font(.system(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.75)
                }
            } else {
                HStack(spacing: 5) {
                    ArenaAvatar(url: player.image, size: 24, player: true)
                    Text(player.name).font(.system(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.75)
                }
            }
        }.buttonStyle(.plain)
    }
    private func duelCell(_ left: ArenaPlayer, _ right: ArenaPlayer) -> some View {
        let score = duels.score(leftID: left.id, rightID: right.id)
        let color: Color = score.map { $0.leftKills > $0.rightKills ? LifeTheme.positive : $0.leftKills < $0.rightKills ? LifeTheme.red : Color.secondary } ?? .secondary
        return Text(score.map { "\($0.leftKills) : \($0.rightKills)" } ?? "–")
            .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(color)
            .lineLimit(1).minimumScaleFactor(0.75)
            .frame(width: 52, height: 48).background(color.opacity(score == nil ? 0.03 : 0.08), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("\(left.name) 对位 \(right.name)")
            .accessibilityValue(score.map { "击杀 \($0.leftKills)，被击杀 \($0.rightKills)" } ?? "暂无数据")
    }
}

private struct MatchMapAnalysisCard: View {
    let row: ArenaMapComparison
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ArenaMapLabel(name: row.name, size: 34).font(.headline)
                Spacer(minLength: 4)
                Text("\(row.leftPlayed) / \(row.rightPlayed) 场").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            metric(row.leftWin, title: "地图胜率", right: row.rightWin, emphasized: true)
            HStack(spacing: 18) { winBar(row.leftWin, trailing: false); winBar(row.rightWin, trailing: true) }
            if row.leftPick != "–" || row.rightPick != "–" { metric(row.leftPick, title: "选择率", right: row.rightPick) }
            if row.leftBan != "–" || row.rightBan != "–" { metric(row.leftBan, title: "禁用率", right: row.rightBan) }
        }.padding(16).background(LifeTheme.card, in: RoundedRectangle(cornerRadius: 16))
    }
    private func metric(_ left: String, title: String, right: String, emphasized: Bool = false) -> some View {
        HStack {
            Text(left).font(emphasized ? .title3.monospacedDigit().bold() : .caption.monospacedDigit()).foregroundStyle(emphasized ? LifeTheme.red : Color.primary).frame(maxWidth: .infinity, alignment: .leading)
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(right).font(emphasized ? .title3.monospacedDigit().bold() : .caption.monospacedDigit()).foregroundStyle(emphasized ? LifeTheme.red : Color.primary).frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    private func winBar(_ raw: String, trailing: Bool) -> some View {
        GeometryReader { geometry in
            let rate = Double(raw.replacingOccurrences(of: "%", with: ""))
            ZStack(alignment: trailing ? .trailing : .leading) {
                Capsule().fill(LifeTheme.red.opacity(0.08))
                if let rate, rate.isFinite, (0...100).contains(rate) {
                    Capsule().fill(LifeTheme.red.opacity(0.65)).frame(width: geometry.size.width * rate / 100)
                }
            }
        }.frame(height: 5).accessibilityHidden(true)
    }
}

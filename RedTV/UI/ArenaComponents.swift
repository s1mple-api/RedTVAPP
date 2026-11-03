import SwiftUI

struct ArenaAvatar: View {
    let url: String
    var size: CGFloat = 38
    var player = false
    var contrastBackground = false
    @State private var image: UIImage?
    @State private var contrast = Color.clear
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else { placeholder }
        }.frame(width: size, height: size).accessibilityHidden(true)
            .background(contrastBackground ? contrast : .clear, in: RoundedRectangle(cornerRadius: size * 0.18))
            .task(id: url) {
                image = nil
                contrast = .clear
                guard let address = externalURL(url), address.pathExtension.lowercased() != "svg" else { return }
                let loaded = await ArenaImages.shared.image(at: address)
                if !Task.isCancelled {
                    image = loaded
                    if contrastBackground, let loaded, let brightness = ArenaImages.foregroundBrightness(loaded) {
                        contrast = brightness > 0.7 ? Color(red: 0.12, green: 0.15, blue: 0.20) : brightness < 0.25 ? .white : .clear
                    }
                }
            }
    }
    private var placeholder: some View {
        Image(systemName: player ? "person.crop.square" : "shield.lefthalf.filled")
            .resizable().scaledToFit().padding(size * 0.2).foregroundStyle(.secondary)
    }
}

struct ArenaStamp: View {
    let date: Date
    var cached: Bool
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: cached ? "clock.arrow.circlepath" : "arrow.triangle.2.circlepath")
            Text(cached ? "离线缓存 · \(ArenaDate.format(date))" : "完美世界电竞 · \(ArenaDate.format(date, pattern: "HH:mm")) 更新")
        }.font(.caption2).foregroundStyle(cached ? RedTheme.red : Color.secondary)
        if cached { Notice(text: "当前连接未能更新，展示最近一次成功读取的数据；比分可能已变化。") }
    }
}

struct ArenaTeamAvatar: View {
    @Environment(\.colorScheme) private var scheme
    let team: ArenaTeam
    var size: CGFloat = 38
    var body: some View { ArenaAvatar(url: scheme == .dark ? team.logo : team.lightLogo, size: size, contrastBackground: true) }
}

struct ArenaBadge: View {
    let text: String
    var live = false
    var body: some View {
        HStack(spacing: 5) {
            if live { Circle().fill(RedTheme.live).frame(width: 5, height: 5) }
            Text(text)
        }.font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(live ? RedTheme.live : RedTheme.red)
            .padding(.horizontal, 7).padding(.vertical, 5)
            .background((live ? RedTheme.live : RedTheme.red).opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
    }
}

struct ArenaMatchCard: View {
    let match: ArenaMatch
    var body: some View {
        NavigationLink(value: Route.arenaMatch(match.id)) {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    ArenaBadge(text: match.stateLabel, live: match.status == 1)
                    Text(ArenaDate.format(match.start, pattern: "HH:mm")).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    Spacer()
                    Text(match.bestOf).font(.caption2.monospaced()).foregroundStyle(.secondary)
                    if match.stars > 0 { Label("\(match.stars)", systemImage: "star.fill").font(.system(size: 10)).foregroundStyle(RedTheme.red) }
                }
                HStack(spacing: 12) {
                    VStack(spacing: 9) { ArenaTeamAvatar(team: match.team1, size: 40); Text(match.team1.name.isEmpty ? "待定" : match.team1.name).font(.subheadline.bold()).lineLimit(1) }.frame(maxWidth: .infinity)
                    HStack(spacing: 9) {
                        Text(match.score1.map(String.init) ?? "–")
                        Text(":").foregroundStyle(.tertiary)
                        Text(match.score2.map(String.init) ?? "–")
                    }.font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit()
                    VStack(spacing: 9) { ArenaTeamAvatar(team: match.team2, size: 40); Text(match.team2.name.isEmpty ? "待定" : match.team2.name).font(.subheadline.bold()).lineLimit(1) }.frame(maxWidth: .infinity)
                }
                Rectangle().fill(.primary.opacity(0.06)).frame(height: 1)
                HStack(spacing: 6) {
                    Text(match.eventName.isEmpty ? "CS2 赛事" : match.eventName).lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                }.font(.caption2).foregroundStyle(.secondary)
            }.padding(16).background(RedTheme.card, in: RoundedRectangle(cornerRadius: 16))
                .overlay(alignment: .leading) { if match.status == 1 { RoundedRectangle(cornerRadius: 2).fill(RedTheme.live).frame(width: 3, height: 36) } }
        }.buttonStyle(.plain).accessibilityIdentifier("match-\(match.id)")
    }
}

struct ArenaEventCard: View {
    let event: ArenaEvent
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ArenaAvatar(url: event.logo, size: 56).padding(7).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 9) {
                HStack { ArenaBadge(text: event.stateLabel, live: event.status == 1); Spacer(); Text(event.tier).font(.caption2.monospaced()).foregroundStyle(.secondary) }
                Text(event.name).font(.headline).lineLimit(2)
                Text(event.dateRange + (event.location.isEmpty ? "" : " · " + event.location)).font(.caption2).foregroundStyle(.secondary)
                HStack { Text(event.prize.isEmpty ? "奖金待公布" : event.prize).font(.caption.weight(.semibold)).foregroundStyle(RedTheme.red); Spacer(); Text("\(event.teamCount) 支战队").font(.caption2).foregroundStyle(.secondary) }
            }
        }.padding(16).background(RedTheme.card, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ArenaTeamRow: View {
    let team: ArenaTeam
    var body: some View {
        HStack(spacing: 14) {
            Text(team.rank.map { String(format: "%02d", $0) } ?? "–").font(.system(.title3, design: .monospaced, weight: .bold)).foregroundStyle((team.rank ?? 99) <= 3 ? RedTheme.red : Color.secondary).frame(width: 30)
            ArenaTeamAvatar(team: team)
            VStack(alignment: .leading, spacing: 5) { Text(team.name).font(.headline); Text(team.players.prefix(5).map(\.name).joined(separator: " · ")).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1) }
            Spacer(minLength: 0)
            if let points = team.points { Text(points.formatted(.number.precision(.fractionLength(0)))).font(.subheadline.monospacedDigit().bold()) }
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }.padding(.vertical, 12)
    }
}

struct ArenaPlayerRow: View {
    @Environment(ArenaStore.self) private var arena
    let player: ArenaPlayer
    var index: Int? = nil
    @State private var portrait: String?
    var body: some View {
        HStack(spacing: 13) {
            if let index { Text(String(format: "%02d", index)).font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 24) }
            ArenaAvatar(url: portrait ?? player.image, size: 54, player: true)
                .background(RedTheme.paper, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 5) { Text(player.name).font(.headline); Text([player.teamName, player.country, player.coach ? "教练" : ""].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption2).foregroundStyle(.secondary) }
            Spacer()
            if let rating = player.rating { Text(rating.formatted(.number.precision(.fractionLength(2)))).font(.title3.monospacedDigit().bold()).foregroundStyle(RedTheme.positive) }
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }.padding(.vertical, 10).task(id: player.id) { portrait = await arena.portrait(for: player) }
    }
}

struct ArenaRosterStrip: View {
    let team: ArenaTeam
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(team.players.filter { !$0.coach }.prefix(5))) { player in
                    NavigationLink(value: Route.arenaPlayer(player.id)) {
                        VStack(spacing: 5) {
                            ArenaAvatar(url: player.image, size: 58, player: true)
                            Text(player.name).font(.system(size: 10, weight: .medium)).lineLimit(1)
                        }.frame(width: 58).foregroundStyle(.primary)
                    }.buttonStyle(.plain).accessibilityIdentifier("roster-player-\(player.id)")
                }
            }.padding(.vertical, 10)
        }
    }
}

struct ArenaFollowButton: View {
    @Environment(ArenaStore.self) private var arena
    let kind: String
    let id: Int
    let title: String
    var subtitle = ""
    var image = ""
    var body: some View {
        Button { arena.toggle(kind: kind, id: id, title: title, subtitle: subtitle, image: image) } label: {
            Label(arena.isFollowed(kind, id) ? "已关注" : "关注", systemImage: arena.isFollowed(kind, id) ? "star.fill" : "star")
        }.buttonStyle(.bordered).font(.subheadline).tint(RedTheme.red)
    }
}

struct DetailFacts: View {
    let values: [(String, String)]
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, pair in
                HStack(alignment: .top) { Text(pair.0).foregroundStyle(.secondary); Spacer(); Text(pair.1.isEmpty ? "待公布" : pair.1).multilineTextAlignment(.trailing) }.font(.subheadline).padding(14)
                if index < values.count - 1 { Divider().padding(.horizontal, 14) }
            }
        }.background(RedTheme.card, in: RoundedRectangle(cornerRadius: 14))
    }
}

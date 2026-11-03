import SwiftUI

struct ArenaFeaturedMatchCard: View {
    let match: ArenaMatch
    var fillsHeight = false
    var body: some View {
        NavigationLink(value: Route.arenaMatch(match.id)) {
            VStack(spacing: 20) {
                HStack(spacing: 6) {
                    if match.status == 1 { Circle().fill(.white).frame(width: 6, height: 6) }
                    Text(match.stateLabel).font(.caption.bold())
                    Spacer()
                    if match.stars > 0 { HStack(spacing: 3) { ForEach(0..<min(match.stars, 5), id: \.self) { _ in Image(systemName: "star.fill") } }.font(.system(size: 10)) }
                    Text(match.bestOf).font(.caption.monospaced().bold()).padding(.leading, 6)
                }
                HStack(spacing: 10) {
                    team(match.team1)
                    VStack(spacing: 6) {
                        Text(scoreText).font(.system(size: 36, weight: .black, design: .rounded)).monospacedDigit()
                        Text(ArenaDate.format(match.start, pattern: "HH:mm")).font(.caption.monospacedDigit()).opacity(0.8)
                    }.frame(minWidth: 85)
                    team(match.team2)
                }
                HStack { Text(match.eventName.isEmpty ? "CS2 焦点赛事" : match.eventName).lineLimit(1); Spacer(minLength: 4); Image(systemName: "arrow.up.right") }.font(.caption.weight(.medium)).opacity(0.9)
            }.padding(20).foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil)
                .background(LinearGradient(colors: [LifeTheme.red, Color(red: 0.86, green: 0.055, blue: 0.20)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
        }.buttonStyle(.plain).accessibilityIdentifier("featured-match-\(match.id)")
    }
    private var scoreText: String {
        guard let left = match.score1, let right = match.score2 else { return "VS" }
        return "\(left) : \(right)"
    }
    private func team(_ team: ArenaTeam) -> some View {
        VStack(spacing: 11) {
            ArenaAvatar(url: team.lightLogo, size: 54, contrastBackground: true).padding(8).background(.white, in: RoundedRectangle(cornerRadius: 15))
            Text(team.name.isEmpty ? "待定" : team.name).font(.subheadline.bold()).lineLimit(1).minimumScaleFactor(0.8)
        }.frame(maxWidth: .infinity)
    }
}

struct ArenaFeaturedMatchDeck: View {
    let matches: [ArenaMatch]
    @State private var selection = 0
    @ScaledMetric(relativeTo: .body) private var cardHeight: CGFloat = 224
    private var cards: [ArenaMatch] { Array(matches.prefix(3)) }
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                if cards.count > 2 {
                    RoundedRectangle(cornerRadius: 22).fill(LifeTheme.red.opacity(0.10))
                        .scaleEffect(x: 0.92, y: 1).offset(y: 12).accessibilityHidden(true)
                }
                if cards.count > 1 {
                    RoundedRectangle(cornerRadius: 22).fill(LifeTheme.red.opacity(0.18))
                        .scaleEffect(x: 0.96, y: 1).offset(y: 6).accessibilityHidden(true)
                }
                TabView(selection: $selection) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, match in
                        ArenaFeaturedMatchCard(match: match, fillsHeight: true).tag(index)
                    }
                }.tabViewStyle(.page(indexDisplayMode: .never))
            }.frame(height: cardHeight).padding(.bottom, cards.count > 1 ? 12 : 0)
            if cards.count > 1 {
                HStack(spacing: 8) {
                    Text("\(min(selection + 1, cards.count)) / \(cards.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        .accessibilityIdentifier("featured-page-position").accessibilityValue("\(min(selection + 1, cards.count))/\(cards.count)")
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(cards.indices, id: \.self) { index in
                            Button { withAnimation { selection = index } } label: {
                                Capsule().fill(selection == index ? LifeTheme.red : Color.secondary.opacity(0.22))
                                    .frame(width: selection == index ? 20 : 6, height: 5).frame(width: 44, height: 44).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel("焦点比赛 \(index + 1)，共 \(cards.count) 场")
                        }
                    }
                    Spacer()
                    Text("左右滑动").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("featured-matches-deck")
            .onChange(of: cards.map(\.id)) { old, updated in
                let visible = old.indices.contains(selection) ? old[selection] : nil
                selection = visible.flatMap { updated.firstIndex(of: $0) } ?? 0
            }
    }
}

struct ArenaCompactMatchCard: View {
    let match: ArenaMatch
    var body: some View {
        NavigationLink(value: Route.arenaMatch(match.id)) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 5) {
                    Text(ArenaDate.format(match.start, pattern: "HH:mm")).font(.caption.monospacedDigit().bold())
                    if match.status == 1 { Circle().fill(LifeTheme.live).frame(width: 5, height: 5) }
                    Text(match.stateLabel).font(.system(size: 9)).foregroundStyle(match.status == 1 ? LifeTheme.live : Color.secondary)
                    Spacer(minLength: 0)
                    if match.stars > 0 { Label("\(match.stars)", systemImage: "star.fill").font(.system(size: 10)).foregroundStyle(LifeTheme.red) }
                }
                team(match.team1, score: match.score1)
                team(match.team2, score: match.score2)
                HStack { Text(match.eventName.isEmpty ? "CS2 赛事" : match.eventName).lineLimit(1); Spacer(minLength: 0); Text(match.bestOf) }.font(.system(size: 9)).foregroundStyle(.secondary)
            }.padding(12).background(LifeTheme.card, in: RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .leading) { if match.status == 1 { RoundedRectangle(cornerRadius: 2).fill(LifeTheme.red).frame(width: 2, height: 25) } }
        }.buttonStyle(.plain).accessibilityIdentifier("match-\(match.id)")
    }
    private func team(_ team: ArenaTeam, score: Int?) -> some View {
        HStack(spacing: 8) {
            ArenaTeamAvatar(team: team, size: 23)
            Text(team.name.isEmpty ? "待定" : team.name).font(.subheadline.weight(.semibold)).lineLimit(1)
            Spacer(minLength: 2)
            Text(score.map(String.init) ?? "–").font(.subheadline.monospacedDigit().bold()).foregroundStyle(.primary)
        }
    }
}

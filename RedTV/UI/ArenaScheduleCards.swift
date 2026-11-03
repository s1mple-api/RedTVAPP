import SwiftUI

struct ArenaFeaturedMatchCard: View {
    let match: ArenaMatch
    var fillsHeight = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationLink(value: Route.arenaMatch(match.id)) {
            VStack(spacing: 12) {
                // 顶部状态栏
                HStack(spacing: 6) {
                    if match.status == 1 {
                        Circle()
                            .fill(.white)
                            .frame(width: 6, height: 6)
                            .shadow(color: .white, radius: 4)
                    }
                    Text(match.stateLabel)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.3)

                    Spacer()

                    if match.stars > 0 {
                        HStack(spacing: 2) {
                            ForEach(0..<min(match.stars, 5), id: \.self) { _ in
                                Image(systemName: "star.fill")
                            }
                        }
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                    }

                    Text(match.bestOf)
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.18), in: Capsule())
                }

                // 中间对阵与比分
                HStack(spacing: 12) {
                    team(match.team1)

                    VStack(spacing: 3) {
                        Text(scoreText)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .shadow(color: .black.opacity(0.16), radius: 2, x: 0, y: 1)
                        Text(ArenaDate.format(match.start, pattern: "HH:mm"))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .opacity(0.85)
                    }
                    .frame(minWidth: 80)

                    team(match.team2)
                }

                // 底部赛事信息
                HStack(spacing: 4) {
                    Text(match.eventName.isEmpty ? "CS2 焦点赛事" : match.eventName)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .opacity(0.85)
            }
            .padding(15)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil)
            .background {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.96, green: 0.12, blue: 0.22),
                            Color(red: 0.76, green: 0.04, blue: 0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    RadialGradient(
                        colors: [.white.opacity(0.15), .clear],
                        center: .topLeading,
                        startRadius: 10,
                        endRadius: 180
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.35), .white.opacity(0.08), RedTheme.red.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: RedTheme.red.opacity(0.25), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("featured-match-\(match.id)")
    }

    private var scoreText: String {
        guard let left = match.score1, let right = match.score2 else { return "VS" }
        return "\(left) : \(right)"
    }

    private func team(_ team: ArenaTeam) -> some View {
        VStack(spacing: 6) {
            ArenaAvatar(url: team.lightLogo, size: 42, contrastBackground: true)
                .padding(6)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            Text(team.name.isEmpty ? "待定" : team.name)
                .font(.system(size: 12, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ArenaFeaturedMatchDeck: View {
    let matches: [ArenaMatch]
    @State private var selection = 0
    @ScaledMetric(relativeTo: .body) private var cardHeight: CGFloat = 186
    private var cards: [ArenaMatch] { Array(matches.prefix(3)) }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                // 底层第 3 层：3D 远景叠放卡片背板（动态推进与景深透视）
                if cards.count > selection + 2 {
                    featuredStackBackplate(match: cards[selection + 2], depth: 2)
                        .scaleEffect(x: 0.90, y: 0.90, anchor: .bottom)
                        .offset(y: 16)
                        .rotation3DEffect(.degrees(-5), axis: (x: 1, y: 0, z: 0))
                        .opacity(0.65)
                        .accessibilityHidden(true)
                }

                // 底层第 2 层：3D 近景叠放卡片背板（动态推进与景深透视）
                if cards.count > selection + 1 {
                    featuredStackBackplate(match: cards[selection + 1], depth: 1)
                        .scaleEffect(x: 0.95, y: 0.95, anchor: .bottom)
                        .offset(y: 8)
                        .rotation3DEffect(.degrees(-2.5), axis: (x: 1, y: 0, z: 0))
                        .opacity(0.85)
                        .accessibilityHidden(true)
                }

                // 顶层焦点比赛卡片轮播（原生 TabView 分页，保证丝滑手势交互与无障碍全兼容）
                TabView(selection: $selection) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, match in
                        ArenaFeaturedMatchCard(match: match, fillsHeight: true)
                            .tag(index)
                            .padding(.horizontal, 2)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .frame(height: cardHeight)
            .padding(.bottom, cards.count > 1 ? 14 : 0)
            .animation(.spring(response: 0.38, dampingFraction: 0.74), value: selection)

            if cards.count > 1 {
                HStack(spacing: 8) {
                    Text("\(min(selection + 1, cards.count)) / \(cards.count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("featured-page-position")
                        .accessibilityValue("\(min(selection + 1, cards.count))/\(cards.count)")

                    Spacer()

                    // 流体胶囊指示器
                    HStack(spacing: 6) {
                        ForEach(cards.indices, id: \.self) { index in
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.76)) {
                                    selection = index
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Capsule()
                                    .fill(selection == index ? RedTheme.red : Color.secondary.opacity(0.25))
                                    .frame(width: selection == index ? 22 : 6, height: 5)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("焦点比赛 \(index + 1)，共 \(cards.count) 场")
                        }
                    }

                    Spacer()

                    Text("左右滑动")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("featured-matches-deck")
        .onChange(of: cards.map(\.id)) { old, updated in
            let visible = old.indices.contains(selection) ? old[selection] : nil
            selection = visible.flatMap { updated.firstIndex(of: $0) } ?? 0
        }
    }

    // 真实的 3D 叠放卡片背板，带有对阵轮廓与透视高光
    @ViewBuilder
    private func featuredStackBackplate(match: ArenaMatch, depth: Int) -> some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(
                LinearGradient(
                    colors: [
                        RedTheme.red.opacity(depth == 1 ? 0.32 : 0.18),
                        Color(red: 0.76, green: 0.04, blue: 0.15).opacity(depth == 1 ? 0.28 : 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(depth == 1 ? 0.25 : 0.12),
                                RedTheme.red.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .overlay(alignment: .bottom) {
                HStack(spacing: 8) {
                    Text(match.team1.name.isEmpty ? "待定" : match.team1.name)
                    Text("VS").font(.caption2.bold()).opacity(0.6)
                    Text(match.team2.name.isEmpty ? "待定" : match.team2.name)
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(depth == 1 ? 0.45 : 0.25))
                .padding(.bottom, 6)
            }
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

struct ArenaCompactMatchCard: View {
    let match: ArenaMatch
    var body: some View {
        NavigationLink(value: Route.arenaMatch(match.id)) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 5) {
                    Text(ArenaDate.format(match.start, pattern: "HH:mm")).font(.caption.monospacedDigit().bold())
                    if match.status == 1 { Circle().fill(RedTheme.live).frame(width: 5, height: 5) }
                    Text(match.stateLabel).font(.system(size: 9)).foregroundStyle(match.status == 1 ? RedTheme.live : Color.secondary)
                    Spacer(minLength: 0)
                    if match.stars > 0 { Label("\(match.stars)", systemImage: "star.fill").font(.system(size: 10)).foregroundStyle(RedTheme.red) }
                }
                team(match.team1, score: match.score1)
                team(match.team2, score: match.score2)
                HStack { Text(match.eventName.isEmpty ? "CS2 赛事" : match.eventName).lineLimit(1); Spacer(minLength: 0); Text(match.bestOf) }.font(.system(size: 9)).foregroundStyle(.secondary)
            }.padding(12).background(RedTheme.card, in: RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .leading) { if match.status == 1 { RoundedRectangle(cornerRadius: 2).fill(RedTheme.red).frame(width: 2, height: 25) } }
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

import SwiftUI

struct RedPageHeader: View {
    let title: String
    let subtitle: String
    let key: String
    @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 26
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                // 精致品牌微标与多层光影
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(RedTheme.card)
                        .shadow(color: RedTheme.red.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 8, x: 0, y: 3)
                    BrandLogo(size: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .frame(width: 42, height: 42)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(LinearGradient(colors: [RedTheme.red.opacity(0.35), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                }

                // 标题与标签
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(key == "arena" ? RedTheme.live : RedTheme.red)
                            .frame(width: 5, height: 5)
                            .shadow(color: (key == "arena" ? RedTheme.live : RedTheme.red).opacity(0.8), radius: 3)
                        Text("Red TV")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(1.4)
                            .foregroundStyle(RedTheme.red)
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary.opacity(0.6))
                        Text(badgeText(for: key))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(.secondary)
                    }

                    Text(title)
                        .font(.system(size: titleSize, weight: .heavy, design: .rounded))
                        .tracking(-0.6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 12)

                // 交互操作按键
                HStack(spacing: 8) {
                    NavigationLink(value: Route.search) {
                        actionIcon("magnifyingglass")
                    }
                    .accessibilityLabel("搜索")
                    .accessibilityIdentifier("header-search-\(key)")

                    NavigationLink(value: Route.settings) {
                        actionIcon("slider.horizontal.3")
                    }
                    .accessibilityLabel("设置")
                    .accessibilityIdentifier("header-settings-\(key)")
                }
                .buttonStyle(.plain)
            }

            // 副标题与修饰线条
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("page-header-\(key)")
    }

    private func badgeText(for key: String) -> String {
        switch key {
        case "arena": return "LIVE ARENA"
        case "events": return "TOURNAMENT"
        case "data": return "ANALYTICS"
        case "news": return "NEWS WIRE"
        case "profile": return "MY HUB"
        default: return "ESPORTS"
        }
    }

    private func actionIcon(_ name: String) -> some View {
        ZStack {
            Circle()
                .fill(RedTheme.card)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.05), radius: 6, x: 0, y: 2)

            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.16 : 0.7),
                            Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )

            Image(systemName: name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(width: 38, height: 38)
        .frame(width: 44, height: 44) // 保持 44x44 的 Apple 人机界面规范最小可点击热区
        .contentShape(Rectangle())
    }
}

private struct RedTabPageModifier: ViewModifier {
    let title: String
    let subtitle: String
    let key: String
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(RedTheme.paper.ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    RedPageHeader(title: title, subtitle: subtitle, key: key)
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                        .padding(.bottom, 12)
                        .frame(maxWidth: 760)
                        .frame(maxWidth: .infinity)

                    // 极度细腻的磨砂底边分隔线
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    RedTheme.red.opacity(0.18),
                                    Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.04),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 0.8)
                }
                .background {
                    ZStack {
                        RedTheme.paper
                        // 顶部极其微妙的电竞氛围发光
                        RadialGradient(
                            colors: [RedTheme.red.opacity(colorScheme == .dark ? 0.09 : 0.035), .clear],
                            center: .topLeading,
                            startRadius: 20,
                            endRadius: 240
                        )
                    }
                    .ignoresSafeArea(edges: .top)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
    }
}

extension View {
    @ViewBuilder func redTabPage(_ title: String, subtitle: String, key: String, isRoot: Bool = true) -> some View {
        if isRoot { modifier(RedTabPageModifier(title: title, subtitle: subtitle, key: key)) }
        else { background(RedTheme.paper).navigationTitle(title).navigationBarTitleDisplayMode(.inline).redDetailNavigation() }
    }
    func redDetailNavigation() -> some View { toolbar(.visible, for: .navigationBar) }
}

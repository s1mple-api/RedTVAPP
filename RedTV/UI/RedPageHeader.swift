import SwiftUI

struct LifePageHeader: View {
    let title: String
    let subtitle: String
    let key: String
    @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 11) {
                BrandLogo(size: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Red TV").font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1.6).foregroundStyle(LifeTheme.red)
                    Text(title).font(.system(size: titleSize, weight: .bold))
                        .tracking(-0.6).lineLimit(1).minimumScaleFactor(0.85)
                }
                Spacer(minLength: 12)
                HStack(spacing: 8) {
                    NavigationLink(value: Route.search) { actionIcon("magnifyingglass") }
                        .accessibilityLabel("搜索").accessibilityIdentifier("header-search-\(key)")
                    NavigationLink(value: Route.settings) { actionIcon("slider.horizontal.3") }
                        .accessibilityLabel("设置").accessibilityIdentifier("header-settings-\(key)")
                }.buttonStyle(.plain)
            }
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }.accessibilityElement(children: .contain).accessibilityIdentifier("page-header-\(key)")
    }

    private func actionIcon(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 17, weight: .medium))
            .foregroundStyle(.primary).frame(width: 44, height: 44)
            .background(LifeTheme.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.035), lineWidth: 1) }
    }
}

private struct LifeTabPageModifier: ViewModifier {
    let title: String
    let subtitle: String
    let key: String
    func body(content: Content) -> some View {
        content
            .background(LifeTheme.paper.ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) {
                LifePageHeader(title: title, subtitle: subtitle, key: key)
                    .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 18)
                    .frame(maxWidth: 760).frame(maxWidth: .infinity)
                    .background(LifeTheme.paper)
            }
            .toolbar(.hidden, for: .navigationBar)
    }
}

extension View {
    @ViewBuilder func lifeTabPage(_ title: String, subtitle: String, key: String, isRoot: Bool = true) -> some View {
        if isRoot { modifier(LifeTabPageModifier(title: title, subtitle: subtitle, key: key)) }
        else { background(LifeTheme.paper).navigationTitle(title).navigationBarTitleDisplayMode(.inline).lifeDetailNavigation() }
    }
    func lifeDetailNavigation() -> some View { toolbar(.visible, for: .navigationBar) }
}

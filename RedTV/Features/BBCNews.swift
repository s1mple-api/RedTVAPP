import SwiftUI

struct BBCNewsView: View {
    var embedded = false
    @Environment(AppStore.self) private var store
    @State private var section = "all"
    private var sections: [(String, String)] {
        var seen = Set<String>()
        return [("all", "全部")] + (store.dashboard?.feed ?? []).compactMap { article in
            guard let key = article.section, let label = article.sectionLabel, !key.isEmpty, seen.insert(key).inserted else { return nil }
            return (key, label)
        }
    }
    private var articles: [Article] { (store.dashboard?.feed ?? []).filter { section == "all" || $0.section == section }.sorted { $0.publishedAt > $1.publishedAt } }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                FilterChips(values: sections, selection: $section)
                if let error = store.dashboardError { ErrorNotice(message: error) { Task { await store.refreshDashboard() } } }
                if let date = store.cachedAt { Notice(text: "展示已同步新闻缓存 · \(ArenaDate.format(date))", icon: "clock.arrow.circlepath") }
                if store.dashboardLoading && store.dashboard == nil { ProgressView("正在读取 BBC 新闻…").frame(maxWidth: .infinity).padding(40) }
                else if articles.isEmpty { EmptyState(title: "暂时没有新闻", message: "下拉刷新，或尝试其他分类。", icon: "newspaper") }
                ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in NavigationLink(value: Route.article(article.id)) { ArticleCard(article: article, featured: index == 0) }.buttonStyle(.plain) }
                Text("新闻由 Red TV 服务同步。中文内容为自动翻译，详情可切换原文并访问 BBC 来源。").font(.caption2).foregroundStyle(.secondary).lineSpacing(4)
            }.padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 24).lifePage()
        }.lifeTabPage("新闻", subtitle: "赛场之外，看见世界。", key: "news", isRoot: !embedded).refreshable { await store.refreshDashboard() }
    }
}

struct ArticleCard: View {
    let article: Article
    var featured = false
    private var imageURL: URL? { externalURL(article.imageUrl) }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if featured, let imageURL { BBCArticleImage(url: imageURL).frame(height: 190) }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("BBC" + (article.sectionLabel.flatMap { $0.isEmpty ? nil : " · \($0)" } ?? ""))
                    .font(.caption2.bold()).foregroundStyle(LifeTheme.red).lineLimit(1)
                Spacer(minLength: 4)
                Text(LifeDate.display(article.publishedAt)).font(.caption2).foregroundStyle(.secondary).fixedSize()
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(article.displayTitle).font(featured ? .title3.bold() : .headline)
                        .lineSpacing(3).multilineTextAlignment(.leading).lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    if !article.displaySummary.isEmpty {
                        Text(article.displaySummary).font(.subheadline).foregroundStyle(.secondary)
                            .lineSpacing(3).multilineTextAlignment(.leading).lineLimit(featured ? 3 : 2)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).layoutPriority(1)
                if !featured, let imageURL {
                    BBCArticleImage(url: imageURL).frame(width: 96, height: 88).fixedSize()
                }
            }
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.primary).background(LifeTheme.card, in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .combine)
    }
}

// The image owns only its assigned rectangle, so a loaded image cannot widen
// a row or change the text column's alignment after the placeholder appears.
struct BBCArticleImage: View {
    let url: URL
    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: url) { phase in
                if let image = phase.image { image.resizable().scaledToFill() }
                else {
                    ZStack {
                        LifeTheme.rose
                        Image(systemName: "photo").font(.title3).foregroundStyle(LifeTheme.red.opacity(0.6))
                    }
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityHidden(true)
    }
}

struct ArenaSearchView: View {
    @Environment(AppStore.self) private var store
    @Environment(ArenaStore.self) private var arena
    @State private var query = ""
    private var term: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private func contains(_ value: String) -> Bool { !term.isEmpty && value.localizedCaseInsensitiveContains(term) }
    var body: some View {
        List {
            Section { Text("搜索当前已加载的赛事、战队、选手与 BBC 新闻。更多内容可在各栏目翻页浏览。").font(.caption).foregroundStyle(.secondary) }
            if term.isEmpty { Section { EmptyState(title: "找到你关注的名字", message: "输入赛事、战队、选手或新闻关键词。", icon: "magnifyingglass") } }
            else {
                let events = (arena.events.value?.value.items ?? []).filter { contains($0.name) || contains($0.englishName) }
                let teams = (arena.teams.value?.value ?? []).filter { contains($0.name) }
                let players = (arena.players.value?.value ?? []).filter { contains($0.name) || contains($0.teamName) }
                let articles = (store.dashboard?.feed ?? []).filter { contains($0.displayTitle) || contains($0.title) }
                if events.isEmpty && teams.isEmpty && players.isEmpty && articles.isEmpty { Section { EmptyState(title: "当前内容中没有匹配结果", message: "试试其他名称，或先到对应栏目加载更多内容。", icon: "magnifyingglass") } }
                if !events.isEmpty { Section("赛事") { ForEach(events) { event in NavigationLink(event.name, value: Route.arenaEvent(event.id)) } } }
                if !teams.isEmpty { Section("战队") { ForEach(teams) { team in NavigationLink(value: Route.arenaTeam(team.id)) { ArenaTeamRow(team: team) } } } }
                if !players.isEmpty { Section("选手") { ForEach(players) { player in NavigationLink(value: Route.arenaPlayer(player.id)) { ArenaPlayerRow(player: player) } } } }
                if !articles.isEmpty { Section("BBC 新闻") { ForEach(articles) { article in NavigationLink(article.displayTitle, value: Route.article(article.id)) } } }
            }
        }.scrollContentBackground(.hidden).background(LifeTheme.paper).navigationTitle("搜索").navigationBarTitleDisplayMode(.inline).lifeDetailNavigation()
            .searchable(text: $query, prompt: "赛事、战队、选手、BBC")
    }
}

struct LegacyResourceView: View {
    @Environment(AppStore.self) private var store
    let path: String
    var body: some View {
        VStack(spacing: 20) {
            EmptyState(title: "这条收藏来自旧版应用", message: "Red TV 现已专注 CS2 赛事与 BBC 新闻。旧收藏仍可保留或在资料库中移除。", icon: "archivebox")
            if let url = store.configuration.shareURL(path: path) { Link("前往原网站查看", destination: url).buttonStyle(.bordered) }
        }.padding(24).frame(maxHeight: .infinity).background(LifeTheme.paper).navigationTitle("旧版收藏").lifeDetailNavigation()
    }
}

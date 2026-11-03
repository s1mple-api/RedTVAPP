import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var selected = 0
    @State private var homePath: [Route] = []
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        @Bindable var store = store
        TabView(selection: $selected) {
            NavigationStack(path: $homePath) { ArenaHomeView().navigationDestination(for: Route.self) { DestinationView(route: $0) } }
                .tabItem { Label("赛场", systemImage: "scope") }.tag(0)
            NavigationStack { ArenaEventsView().navigationDestination(for: Route.self) { DestinationView(route: $0) } }
                .tabItem { Label("赛事", systemImage: "trophy") }.tag(1)
            NavigationStack { ArenaDataView().navigationDestination(for: Route.self) { DestinationView(route: $0) } }
                .tabItem { Label("数据", systemImage: "chart.bar.xaxis") }.tag(2)
            NavigationStack { BBCNewsView().navigationDestination(for: Route.self) { DestinationView(route: $0) } }
                .tabItem { Label("新闻", systemImage: "newspaper") }.tag(3)
            NavigationStack { ProfileView().navigationDestination(for: Route.self) { DestinationView(route: $0) } }
                .tabItem { Label("我的", systemImage: "person.crop.circle") }.tag(4)
        }
        .environment(store.arena)
        .sheet(isPresented: $store.showSettings) { NavigationStack { ConnectionSettingsView() }.environment(store) }
        .task { await store.bootstrap() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.arena.loadMatchCenter() } }
        }
        .onOpenURL { url in
            let path: String
            if url.scheme == "redtv" { path = "/" + (url.host ?? "") + url.path }
            else if url.host == "data.wanmei.com" {
                let p = url.path.split(separator: "/").map(String.init)
                if p.count == 3, p[1] == "match" { path = "/wanmei/matches/" + p[2] }
                else if p.count == 4, ["events", "teams"].contains(p[1]) { path = "/wanmei/" + p[1] + "/" + p[3] }
                else if p.count == 3, p[1] == "players" { path = "/wanmei/players/" + p[2] }
                else { return }
            } else if url.host == URL(string: store.configuration.websiteURL)?.host { path = url.path }
            else { return }
            if let route = Route(path: path) { selected = 0; homePath.append(route) }
        }
    }
}

struct DestinationView: View {
    let route: Route
    @ViewBuilder var body: some View {
        switch route {
        case let .article(id): ArticleView(id: id)
        case let .arenaMatch(id): ArenaMatchCenterDetailView(id: id)
        case let .arenaEvent(id): ArenaEventView(id: id)
        case let .arenaTeam(id): ArenaTeamView(id: id)
        case let .arenaPlayer(id): ArenaPlayerProfileView(id: id)
        case .news: BBCNewsView(embedded: true)
        case .search: ArenaSearchView()
        case .library: LibraryView()
        case .account: AccountView()
        case .settings: AppSettingsView()
        case .about: AboutView()
        case .follows: ArenaFollowsView()
        case let .legacy(path): LegacyResourceView(path: path)
        }
    }
}

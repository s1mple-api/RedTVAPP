import SwiftUI

struct ArenaFollowsView: View {
    @Environment(ArenaStore.self) private var arena
    var body: some View {
        List {
            Section { Text("关注保存在此 iPhone。赛场中的“关注”筛选会显示关注比赛、赛事或战队的当日赛程。").font(.caption).foregroundStyle(.secondary) }
            if arena.follows.isEmpty { EmptyState(title: "把热爱留在这里", message: "在比赛、赛事、战队或选手详情点击关注。", icon: "star") }
            ForEach(arena.follows) { item in
                if let route = item.route {
                    NavigationLink(value: route) {
                        HStack(spacing: 14) { ArenaAvatar(url: item.image, player: item.kind == "player"); VStack(alignment: .leading, spacing: 6) { Text(item.title).font(.headline); Text(item.subtitle).font(.caption).foregroundStyle(.secondary) } }
                    }.swipeActions { Button("取消关注", role: .destructive) { arena.remove(item) } }
                }
            }
        }.scrollContentBackground(.hidden).background(LifeTheme.paper).navigationTitle("赛事关注").navigationBarTitleDisplayMode(.inline).lifeDetailNavigation()
    }
}

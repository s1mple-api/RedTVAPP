import SwiftUI

enum LifeTheme {
    static let red = Color(red: 1, green: 0.141, blue: 0.259)
    static let paper = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.043, green: 0.063, blue: 0.086, alpha: 1) : UIColor(red: 0.965, green: 0.969, blue: 0.976, alpha: 1) })
    static let rose = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.21, green: 0.08, blue: 0.11, alpha: 1) : UIColor(red: 1, green: 0.925, blue: 0.94, alpha: 1) })
    static let card = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.082, green: 0.11, blue: 0.145, alpha: 1) : .white })
    static let live = Color(red: 1, green: 0.32, blue: 0.32)
    static let positive = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.61, green: 0.82, blue: 0.47, alpha: 1) : UIColor(red: 0.12, green: 0.48, blue: 0.34, alpha: 1) })
}

struct Wordmark: View {
    var size: CGFloat = 25
    var body: some View {
        (Text("Red").foregroundColor(.primary) + Text(" TV").foregroundColor(LifeTheme.red))
            .font(.system(size: size, weight: .black, design: .rounded)).tracking(-1.2)
            .accessibilityLabel("Red TV")
    }
}

struct BrandLogo: View {
    var size: CGFloat = 48
    var body: some View {
        Image("AppLogo").resizable().scaledToFit().frame(width: size, height: size)
            .accessibilityLabel("Red TV 标志")
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.system(.caption2, design: .monospaced, weight: .medium))
            .tracking(2).foregroundStyle(LifeTheme.red)
    }
}

struct SectionHeading: View {
    let title: String
    var subtitle: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.title2.weight(.bold))
            if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary).lineSpacing(4) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Notice: View {
    let text: String
    var icon = "info.circle"
    var body: some View {
        Label { Text(text).font(.caption).lineSpacing(4).fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: icon) }
            .foregroundStyle(.secondary).padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(LifeTheme.rose, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct EmptyState: View {
    var title = "暂时没有内容"
    var message = "来源更新后，内容会出现在这里。"
    var icon = "text.page"
    var body: some View {
        ContentUnavailableView { Label(title, systemImage: icon) } description: { Text(message) }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
    }
}

struct ErrorNotice: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(message, systemImage: "wifi.exclamationmark").font(.subheadline).fixedSize(horizontal: false, vertical: true)
            Button("重新加载", action: retry).buttonStyle(.bordered).tint(LifeTheme.red)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(LifeTheme.rose, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct ResourceContent<Value, Content: View>: View {
    let resource: Resource<Value>
    let retry: () -> Void
    @ViewBuilder let content: (Value) -> Content
    var body: some View {
        if let value = resource.value {
            if let error = resource.error { ErrorNotice(message: error, retry: retry) }
            content(value)
        } else if let error = resource.error {
            ErrorNotice(message: error, retry: retry)
        } else {
            ProgressView("正在读取…").frame(maxWidth: .infinity).padding(48)
        }
    }
}

struct RemoteImage: View {
    let url: URL?
    var label = "Red TV"
    var height: CGFloat = 180
    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image { image.resizable().scaledToFill() }
            else {
                ZStack {
                    LifeTheme.rose
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Red").font(.system(size: height > 100 ? 42 : 21, weight: .black, design: .rounded)).tracking(-2)
                        Text(label.uppercased()).font(.system(.caption2, design: .monospaced)).tracking(2)
                    }.foregroundStyle(LifeTheme.red)
                }
            }
        }.frame(height: height).frame(maxWidth: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityHidden(true)
    }
}

func externalURL(_ value: String) -> URL? {
    guard let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
    return url
}

struct SourceLink: View {
    let raw: String
    var title = "查看信息来源"
    var body: some View {
        if let url = externalURL(raw) {
            Link(destination: url) { Label(title, systemImage: "arrow.up.right.square").font(.subheadline.weight(.medium)).frame(minHeight: 44) }
        }
    }
}

struct ReadingActions: View {
    @Environment(AppStore.self) private var store
    let item: SavedItem
    var follow = false
    var body: some View {
        let kind: LibraryKind = follow ? .follows : .bookmarks
        HStack(spacing: 12) {
            Button { store.toggle(item, kind: kind) } label: {
                Label(store.contains(item.path, in: kind) ? (follow ? "已关注" : "已收藏") : (follow ? "关注" : "收藏"), systemImage: store.contains(item.path, in: kind) ? (follow ? "star.fill" : "bookmark.fill") : kind.icon)
            }.buttonStyle(.bordered).accessibilityIdentifier("save-content")
            if let url = store.configuration.shareURL(path: item.path) {
                ShareLink(item: url) { Label("分享", systemImage: "square.and.arrow.up") }.buttonStyle(.bordered)
            }
        }.font(.subheadline).tint(LifeTheme.red)
    }
}

struct PageControls: View {
    let page: Int
    let pages: Int
    let change: (Int) -> Void
    var body: some View {
        if pages > 1 {
            HStack {
                Button { change(page - 1) } label: { Label("上一页", systemImage: "chevron.left") }.disabled(page <= 1)
                Spacer()
                Text("\(page) / \(pages)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
                Button { change(page + 1) } label: { Label("下一页", systemImage: "chevron.right") }.disabled(page >= pages)
            }.buttonStyle(.bordered).padding(.vertical, 12)
        }
    }
}

struct FilterChips: View {
    let values: [(String, String)]
    @Binding var selection: String
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(values, id: \.0) { value in
                    Button { selection = value.0 } label: {
                        Text(value.1).font(.subheadline.weight(selection == value.0 ? .semibold : .regular))
                            .padding(.horizontal, 14).frame(minHeight: 40)
                            .background(selection == value.0 ? LifeTheme.red : LifeTheme.card, in: Capsule())
                            .foregroundStyle(selection == value.0 ? Color.white : Color.primary)
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}

extension View {
    func lifePage() -> some View {
        self.frame(maxWidth: 760).frame(maxWidth: .infinity).background(LifeTheme.paper)
    }
    func lifeToolbar() -> some View {
        self.toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink(value: Route.search) { Image(systemName: "magnifyingglass") }.accessibilityLabel("搜索")
            }
        }
    }
}


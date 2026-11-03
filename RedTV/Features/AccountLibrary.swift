import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        List {
            Section {
                NavigationLink(value: Route.account) {
                    HStack(spacing: 18) {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 52)).foregroundStyle(RedTheme.red)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(store.user?.displayName ?? "让热爱，有迹可循。").font(.headline)
                            Text(store.user == nil ? "登录以同步新闻收藏与阅读记录" : "@\(store.user!.username)").font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 12)
                }.listRowBackground(RedTheme.rose)
            }
            Section("赛事与阅读") {
                NavigationLink(value: Route.follows) { HStack { Label("赛事关注", systemImage: "star"); Spacer(); Text("\(store.arena.follows.count)").foregroundStyle(.secondary) } }.accessibilityIdentifier("arena-follows")
                ForEach([LibraryKind.bookmarks, .history]) { kind in
                    NavigationLink { LibraryView(initialKind: kind) } label: { HStack { Label(kind.label, systemImage: kind.icon); Spacer(); Text("\(store.library[kind].count)").foregroundStyle(.secondary).monospacedDigit() } }
                }
            }
            Section {
                NavigationLink(value: Route.search) { Label("搜索内容", systemImage: "magnifyingglass") }
            }
            Section("应用") {
                NavigationLink(value: Route.settings) { Label("设置", systemImage: "gearshape") }
                NavigationLink(value: Route.about) { Label("关于 Red TV", systemImage: "info.circle") }
            }
            Section { Text(store.syncState).font(.caption).foregroundStyle(.secondary) }
        }.scrollContentBackground(.hidden).contentMargins(.top, 4, for: .scrollContent).listSectionSpacing(16)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
            .redTabPage("我的", subtitle: "收藏热爱，记录每一次关注。", key: "profile")
    }
}

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var kind: LibraryKind
    init(initialKind: LibraryKind = .bookmarks) { _kind = State(initialValue: initialKind) }
    var body: some View {
        List {
            Section {
                Picker("资料类型", selection: $kind) { ForEach(LibraryKind.allCases) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
            }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            Section {
                if store.library[kind].isEmpty {
                    EmptyState(title: "还没有\(kind.label)", message: kind == .history ? "打开阅读的内容会保存在这里。" : "浏览内容时，点一下\(kind.label)即可留在这里。", icon: kind.icon).listRowBackground(Color.clear)
                }
                ForEach(store.library[kind]) { item in
                    if let route = Route(path: item.path) {
                        NavigationLink(value: route) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.title).font(.headline).lineLimit(3)
                                Text("\(sourceName(item.source)) · \(Date(timeIntervalSince1970: Double(item.savedAt) / 1000).formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 7)
                        }.swipeActions { Button("移除", role: .destructive) { store.remove(item.path, kind: kind) } }
                    }
                }
            }
            Section {
                Text(store.syncState).font(.caption).foregroundStyle(.secondary)
                if let error = store.syncError { Text(error).font(.caption).foregroundStyle(.secondary) }
                if store.user != nil { Button("立即同步") { Task { await store.syncLibrary() } } }
                else { NavigationLink("登录以跨设备同步", value: Route.account) }
            }
        }.scrollContentBackground(.hidden).background(RedTheme.paper).navigationTitle("我的资料库").navigationBarTitleDisplayMode(.inline).redDetailNavigation()
            .refreshable { await store.syncLibrary() }
    }
}

struct AccountView: View {
    @Environment(AppStore.self) private var store
    @State private var register = false
    @State private var username = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var busy = false
    @State private var error: String?
    private var valid: Bool {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().range(of: "^[a-z0-9_]{3,32}$", options: .regularExpression) != nil && password.count >= 10 && password.utf8.count <= 72 && (!register || (1...30).contains(displayName.trimmingCharacters(in: .whitespacesAndNewlines).count))
    }
    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) { BrandLogo(size: 54); Wordmark(size: 34) }.padding(.vertical, 12)
                if let user = store.user {
                    Text(user.displayName).font(.title2.bold())
                    LabeledContent("用户名", value: user.username)
                    LabeledContent("账号角色", value: user.role == "admin" ? "管理员" : "普通用户")
                    Text(store.syncState).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("把关心的内容，随身带走。").font(.headline)
                    Text("登录后同步 BBC 新闻收藏与阅读记录。赛事、战队和选手关注保存在此 iPhone。").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if store.user != nil {
                Section {
                    Button("同步个人内容") { Task { await store.syncLibrary() } }
                    Button("退出登录", role: .destructive) {
                        Task {
                            busy = true; error = nil
                            do { try await store.logout() } catch { self.error = error.localizedDescription }
                            busy = false
                        }
                    }.disabled(busy)
                }
            } else {
                Section {
                    Picker("账号操作", selection: $register) { Text("登录").tag(false); Text("注册").tag(true) }.pickerStyle(.segmented)
                    TextField("用户名", text: $username).textInputAutocapitalization(.never).autocorrectionDisabled().textContentType(.username).accessibilityIdentifier("auth-username")
                    if register { TextField("公开昵称", text: $displayName).textContentType(.nickname) }
                    SecureField("密码", text: $password).textContentType(register ? .newPassword : .password).accessibilityIdentifier("auth-password")
                } footer: { Text("用户名为 3–32 位字母、数字或下划线；密码至少 10 个字符，最多 72 字节。注册昵称为 1–30 个字符。") }
                Section {
                    Button {
                        Task {
                            busy = true; error = nil
                            do { try await store.authenticate(register: register, username: username, password: password, displayName: displayName); password = "" }
                            catch { self.error = error.localizedDescription }
                            busy = false
                        }
                    } label: {
                        HStack { Text(register ? "创建账号" : "登录"); Spacer(); if busy { ProgressView() } else { Image(systemName: "arrow.right") } }
                    }.disabled(!valid || busy || store.sessionLoading).accessibilityIdentifier("auth-submit")
                }
            }
            if let error { Section { Text(error).foregroundStyle(RedTheme.red).font(.subheadline) } }
            if let error = store.syncError { Section { Text(error).font(.caption).foregroundStyle(.secondary); Button("重试账号连接") { Task { await store.loadSession() } } } }
        }.scrollContentBackground(.hidden).background(RedTheme.paper).navigationTitle("Red TV 账号").navigationBarTitleDisplayMode(.inline).redDetailNavigation()
    }
}

struct ConnectionSettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var configuration = ServerConfiguration()
    @State private var error: String?
    @State private var testing = false
    @State private var notice: String?
    var body: some View {
        Form {
            Section {
                TextField("API 地址", text: $configuration.apiURL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("settings-api-url")
                TextField("网站地址", text: $configuration.websiteURL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
            } header: { Text("BBC 新闻与账号服务") } footer: { Text("填写 Red TV 服务根地址，不包含 /api/v1。网站地址用于新闻分享与账号请求。赛事数据直接连接完美世界电竞，不受此设置影响。") }
            #if DEBUG
            Section("本机开发") {
                Button("使用本机开发服务") { configuration = ServerConfiguration(apiURL: "http://localhost:8080", websiteURL: "http://localhost:5173"); notice = nil }
                Text("模拟器可使用 localhost。真机请填写 Mac 的局域网 IP，并确保 Go 服务可以从局域网访问。").font(.caption).foregroundStyle(.secondary)
            }
            #endif
            Section {
                Button {
                    Task {
                        testing = true; error = nil; notice = nil
                        do {
                            let client = APIClient(configuration: configuration)
                            let _: UserResponse = try await client.get("auth/me")
                            notice = "服务连接成功，账号接口响应正常。"
                        } catch { self.error = error.localizedDescription }
                        testing = false
                    }
                } label: { HStack { Text("测试连接"); Spacer(); if testing { ProgressView() } } }.disabled(!configuration.isValid || testing)
                Button("保存并连接") {
                    configuration.apiURL = configuration.apiURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    configuration.websiteURL = configuration.websiteURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    guard configuration.isValid else { error = "请输入有效的服务地址。正式版本仅支持 HTTPS。"; return }
                    Task { await store.apply(configuration); dismiss() }
                }.disabled(!configuration.isValid || testing).accessibilityIdentifier("settings-save")
            }
            if let notice { Section { Label(notice, systemImage: "checkmark.circle").foregroundStyle(.green).font(.subheadline) } }
            if let error { Section { Text(error).foregroundStyle(RedTheme.red).font(.subheadline) } }
            Section { Text("切换服务后，资料库按服务与账号分别保存。匿名收藏可在登录时合并至该账号。").font(.caption).foregroundStyle(.secondary) }
        }.scrollContentBackground(.hidden).background(RedTheme.paper).navigationTitle("连接设置").navigationBarTitleDisplayMode(.inline).redDetailNavigation()
            .task { configuration = store.configuration }
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 16) { BrandLogo(size: 68); Wordmark(size: 38) }
                Eyebrow(text: "EVERY ROUND MATTERS")
                Text("聚焦赛场，\n也看见世界。").font(.largeTitle.bold()).lineSpacing(7)
                Text("以 CS2 赛程、比分、赛事与战队选手数据为中心，辅以 BBC 国际新闻，为热爱留一个随身入口。").foregroundStyle(.secondary).lineSpacing(8)
                DetailFacts(values: [("赛事与统计", "完美世界电竞"), ("国际新闻", "BBC / Red TV"), ("赛事关注", "保存在此 iPhone"), ("新闻收藏", "支持 Red TV 账号同步")])
                Notice(text: "数据保留来源口径，比分需下拉刷新。连接失败时可展示 24 小时内成功读取的缓存并标注时间。新闻中文内容为自动翻译，详情提供来源链接。")
                SourceLink(raw: "https://data.wanmei.com/csgo", title: "访问完美世界电竞")
                Text("原生 iOS 客户端 · Swift / SwiftUI\n版本 2.0.0 · 独立客户端").font(.caption).foregroundStyle(.secondary).lineSpacing(8)
            }.padding(24).redPage()
        }.background(RedTheme.paper).navigationTitle("关于").navigationBarTitleDisplayMode(.inline).redDetailNavigation()
    }
}

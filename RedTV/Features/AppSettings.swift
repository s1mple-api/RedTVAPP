import SwiftUI

struct AppSettingsView: View {
    @AppStorage("life.appearance") private var appearance = AppAppearance.light.rawValue
    var body: some View {
        Form {
            Section {
                ForEach(AppAppearance.allCases) { value in
                    Button { appearance = value.rawValue } label: {
                        HStack { Text(value.title).foregroundStyle(.primary); Spacer(); if appearance == value.rawValue { Image(systemName: "checkmark").fontWeight(.semibold) } }
                    }.accessibilityIdentifier("appearance-\(value.rawValue)").accessibilityAddTraits(appearance == value.rawValue ? .isSelected : [])
                }
            } header: { Text("主题") } footer: { Text("默认使用浅色主题。选择跟随系统后，外观会随本机的显示设置自动切换。") }
            Section("数据服务") {
                NavigationLink { ConnectionSettingsView() } label: { Label("连接设置", systemImage: "network") }
                LabeledContent("赛事来源", value: "完美世界电竞")
            }
            Section { NavigationLink(value: Route.about) { Label("关于 Red TV", systemImage: "info.circle") } }
        }.scrollContentBackground(.hidden).background(RedTheme.paper).navigationTitle("设置").navigationBarTitleDisplayMode(.inline).redDetailNavigation()
    }
}

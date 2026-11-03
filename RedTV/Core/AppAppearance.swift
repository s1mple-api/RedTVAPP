import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case light, dark, system
    var id: Self { self }
    var title: String { switch self { case .light: "浅色"; case .dark: "深色"; case .system: "跟随系统" } }
    var scheme: ColorScheme? { switch self { case .light: .light; case .dark: .dark; case .system: nil } }
}

enum ArenaRanking: String, CaseIterable, Identifiable {
    case hltv, valve
    var id: Self { self }
    var title: String { self == .hltv ? "HLTV" : "Valve" }
    var regions: [(Int, String)] {
        self == .valve ? [(0, "全球"), (1, "欧洲"), (2, "美洲"), (3, "亚洲")] : [(-1, "全球"), (1, "欧洲"), (2, "北美"), (3, "中国"), (4, "独联体"), (5, "南美"), (6, "大洋洲")]
    }
    var defaultRegion: Int { self == .hltv ? -1 : 0 }
}

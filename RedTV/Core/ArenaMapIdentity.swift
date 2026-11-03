import Foundation

// CS map emblems are bundled SVG assets, mirrored from the game's artwork at:
// https://somegit.dev/CSGOWTF/csgowtf/src/branch/dev/public/images/map_icons
// Retrieved 2026-11-03. Name aliases affect icon lookup, never source data.

enum ArenaMapIdentity: String, CaseIterable, Identifiable {
    case cache, dust2, mirage, inferno, nuke, train, overpass, vertigo, ancient, anubis

    var id: String { rawValue }
    var assetName: String { "ArenaMap_" + rawValue }
    var nameEn: String {
        switch self {
        case .cache: "Cache"
        case .dust2: "Dust II"
        case .mirage: "Mirage"
        case .inferno: "Inferno"
        case .nuke: "Nuke"
        case .train: "Train"
        case .overpass: "Overpass"
        case .vertigo: "Vertigo"
        case .ancient: "Ancient"
        case .anubis: "Anubis"
        }
    }
    var displayName: String {
        switch self {
        case .cache: "死城之谜"
        case .dust2: "炙热沙城 II"
        case .mirage: "荒漠迷城"
        case .inferno: "炼狱小镇"
        case .nuke: "核子危机"
        case .train: "列车停放站"
        case .overpass: "死亡游乐园"
        case .vertigo: "殒命大厦"
        case .ancient: "远古遗迹"
        case .anubis: "阿努比斯"
        }
    }

    init?(name: String) {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: "de_", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "Ⅱ", with: "ii")
            .replacingOccurrences(of: "ⅱ", with: "ii")
        if let map = Self(rawValue: normalized) { self = map; return }
        if let map = Self.allCases.first(where: { $0.displayName.lowercased().replacingOccurrences(of: " ", with: "") == normalized }) { self = map; return }
        switch normalized {
        case "陨命大厦": self = .vertigo
        case "沙漠2", "dustii": self = .dust2
        case "火车": self = .train
        default: return nil
        }
    }
}

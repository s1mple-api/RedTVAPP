import SwiftUI

struct ArenaMapIcon: View {
    let name: String
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let map = ArenaMapIdentity(name: name) {
                Image(map.assetName).resizable().renderingMode(.original).scaledToFit()
            } else {
                Image(systemName: "map").resizable().scaledToFit()
                    .padding(size * 0.18).foregroundStyle(.secondary)
            }
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct ArenaMapLabel: View {
    let name: String
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: 8) {
            ArenaMapIcon(name: name, size: size)
            Text(name.isEmpty ? "地图待定" : name)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
    }
}

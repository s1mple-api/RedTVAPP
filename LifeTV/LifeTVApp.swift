// xcode: set sdk=iOS

import SwiftUI

@main struct LifeTVApp: App {
    @State private var store = AppStore()
    @AppStorage("life.appearance") private var appearance = AppAppearance.light.rawValue
    var body: some Scene {
        WindowGroup {
            RootView().id(store.configurationID).environment(store).tint(LifeTheme.red)
                .preferredColorScheme((AppAppearance(rawValue: appearance) ?? .light).scheme)
        }
    }
}


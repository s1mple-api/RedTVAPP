// xcode: set sdk=iOS

import SwiftUI

@main struct RedTVApp: App {
    @State private var store = AppStore()
    @AppStorage("life.appearance") private var appearance = AppAppearance.light.rawValue
    var body: some Scene {
        WindowGroup {
            RootView().id(store.configurationID).environment(store).tint(RedTheme.red)
                .preferredColorScheme((AppAppearance(rawValue: appearance) ?? .light).scheme)
        }
    }
}


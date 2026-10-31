import SwiftUI

@main
struct MeihuaToolboxApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .tint(Theme.accent)
        }
    }
}
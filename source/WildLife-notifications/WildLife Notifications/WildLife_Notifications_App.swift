// Edited by FBronski
// 20.07.2026

import SwiftUI

@main
struct WildLife_Notifications_App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: delegate.rootViewModel)
        }
    }
}

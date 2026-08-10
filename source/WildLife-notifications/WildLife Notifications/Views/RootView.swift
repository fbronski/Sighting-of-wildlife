// Edited by FBronski
// 20.07.2026

import SwiftUI

@MainActor
struct RootView: View {
    @State var viewModel: RootViewModel
    

    var body: some View {
        TabView {
            SichtungView(viewModel: viewModel)
                .tabItem {
                    Label("Wildsichtungen", systemImage: "photo.artframe.circle")
                }
            ContentView(viewModel: viewModel)
                .tabItem {
                    Label("Archiv bei Immich", systemImage: "archivebox.circle")
                }
            SettingsView(viewModel: $viewModel)
                .tabItem {
                    Label("Einstellungen", systemImage: "gear.circle")
                }
        }
        
    }
}

//#if DEBUG

#Preview {
    RootView(viewModel: RootViewModel())
}

//#endif

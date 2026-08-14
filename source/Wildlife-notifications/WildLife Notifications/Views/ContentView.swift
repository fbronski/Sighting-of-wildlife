// Edited by FBronski
// 20.07.2026

import SwiftUI
import _WebKit_SwiftUI

struct ContentView: View {
    @State var viewModel: RootViewModel
    
    var body: some View {
        if #available(iOS 26.0, *) {
            WebView(url: viewModel.url)
        } else {
            // Fallback on earlier versions
        }
    }
    
    
}

#Preview {
    ContentView(viewModel: RootViewModel())
}

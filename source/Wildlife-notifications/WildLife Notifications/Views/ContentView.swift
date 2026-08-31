// Edited by FBronski
// 20.07.2026

import SwiftUI
import WebKit
import _WebKit_SwiftUI

struct ContentView: View {
    @State var viewModel: RootViewModel
    
    var body: some View {
        if #available(iOS 26.0, *) {
            WebView(url: viewModel.url)
        } else {
            LegacyWebView(url: viewModel.url)
        }
    }
    
    
}

private struct LegacyWebView: UIViewRepresentable {
    let url: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        load(url, in: webView, coordinator: context.coordinator)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        load(url, in: uiView, coordinator: context.coordinator)
    }

    private func load(_ url: URL?, in webView: WKWebView, coordinator: Coordinator) {
        guard let url, coordinator.loadedURL != url else {
            return
        }

        coordinator.loadedURL = url
        webView.load(URLRequest(url: url))
    }

    final class Coordinator {
        var loadedURL: URL?
    }
}

#Preview {
    ContentView(viewModel: RootViewModel())
}

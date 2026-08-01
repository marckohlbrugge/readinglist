import SwiftUI
import WebKit

struct WebPreviewView: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> TrackingWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.preferredContentMode = .recommended

        let view = TrackingWebView(frame: .zero, configuration: configuration)
        view.setValue(false, forKey: "drawsBackground")
        view.uiDelegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: TrackingWebView, context _: Context) {
        guard nsView.lastRequestedURL != url else {
            return
        }

        nsView.lastRequestedURL = url
        nsView.load(URLRequest(url: url))
    }

    @MainActor
    final class Coordinator: NSObject, WKUIDelegate {
        // Loads links that ask for a new window (target="_blank") in the same
        // preview instead of silently dropping them.
        func webView(
            _ webView: WKWebView,
            createWebViewWith _: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures _: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }
    }
}

final class TrackingWebView: WKWebView {
    var lastRequestedURL: URL?
}

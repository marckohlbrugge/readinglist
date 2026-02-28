import SwiftUI
import WebKit

struct WebPreviewView: NSViewRepresentable {
    let url: URL

    func makeNSView(context _: Context) -> TrackingWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.preferredContentMode = .recommended

        let view = TrackingWebView(frame: .zero, configuration: configuration)
        view.setValue(false, forKey: "drawsBackground")
        return view
    }

    func updateNSView(_ nsView: TrackingWebView, context _: Context) {
        guard nsView.lastRequestedURL != url else {
            return
        }

        nsView.lastRequestedURL = url
        nsView.load(URLRequest(url: url))
    }
}

final class TrackingWebView: WKWebView {
    var lastRequestedURL: URL?
}

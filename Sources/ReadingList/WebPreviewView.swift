import AppKit
import SwiftUI
import WebKit

enum ReaderModeState: Equatable {
    case off
    case extracting
    case showing
    case unavailable
}

struct WebPreviewView: NSViewRepresentable {
    let url: URL
    var isReaderModeEnabled = false
    var onReaderStateChange: (ReaderModeState) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.preferredContentMode = .recommended
        context.coordinator.install(in: configuration.userContentController)

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.setValue(false, forKey: "drawsBackground")
        view.uiDelegate = context.coordinator
        view.navigationDelegate = context.coordinator
        context.coordinator.webView = view
        return view
    }

    func updateNSView(_: WKWebView, context: Context) {
        context.coordinator.onReaderStateChange = onReaderStateChange
        context.coordinator.update(url: url, isReaderModeEnabled: isReaderModeEnabled)
    }

    @MainActor
    final class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
        private enum PageProgress {
            case loading
            case committed
            case domReady
            case finished
        }

        // Readability runs in its own JavaScript world so it can't collide
        // with, or be tampered with by, the page's own scripts.
        private static let readerWorld = WKContentWorld.world(name: "ReaderMode")
        private static let documentReadyMessage = "readerDocumentReady"
        private static let userScriptSource = ReadabilityScript.source + """

        function readingListExtractArticle() {
            const article = new Readability(document.cloneNode(true)).parse();
            if (!article || !article.content) {
                return null;
            }
            return JSON.stringify({
                title: article.title,
                byline: article.byline,
                siteName: article.siteName,
                content: article.content,
                textLength: article.length,
                lang: article.lang,
                dir: article.dir
            });
        }

        window.webkit.messageHandlers.\(documentReadyMessage).postMessage(null);
        """

        weak var webView: WKWebView?
        var onReaderStateChange: (ReaderModeState) -> Void = { _ in }

        private var url: URL?
        private var isReaderModeEnabled = false
        private var article: ReaderArticle?
        private var isArticleUnavailable = false
        private var isShowingArticle = false
        private var articleNavigation: WKNavigation?
        private var pageProgress = PageProgress.loading
        private var isExtracting = false
        private var loadGeneration = 0

        private var readerState = ReaderModeState.off {
            didSet {
                guard readerState != oldValue else {
                    return
                }
                // Defer so SwiftUI state never changes during a view update.
                let state = readerState
                Task { @MainActor [weak self] in
                    self?.onReaderStateChange(state)
                }
            }
        }

        func install(in userContentController: WKUserContentController) {
            userContentController.addUserScript(
                WKUserScript(
                    source: Self.userScriptSource,
                    injectionTime: .atDocumentEnd,
                    forMainFrameOnly: true,
                    in: Self.readerWorld
                )
            )
            userContentController.add(self, contentWorld: Self.readerWorld, name: Self.documentReadyMessage)
        }

        func update(url: URL, isReaderModeEnabled: Bool) {
            if url != self.url {
                self.url = url
                self.isReaderModeEnabled = isReaderModeEnabled
                article = nil
                isArticleUnavailable = false
                readerState = isReaderModeEnabled ? .extracting : .off
                loadPage()
                return
            }

            guard isReaderModeEnabled != self.isReaderModeEnabled else {
                return
            }
            self.isReaderModeEnabled = isReaderModeEnabled

            if isReaderModeEnabled {
                if let article {
                    showArticle(article)
                } else if isArticleUnavailable {
                    readerState = .unavailable
                } else {
                    readerState = .extracting
                    extractArticle()
                }
            } else {
                readerState = .off
                if isShowingArticle {
                    loadPage()
                }
            }
        }

        private func loadPage() {
            guard let webView, let url else {
                return
            }

            loadGeneration += 1
            isExtracting = false
            isShowingArticle = false
            articleNavigation = nil
            pageProgress = .loading
            webView.load(URLRequest(url: url))
        }

        private func showArticle(_ article: ReaderArticle) {
            guard let webView, let url else {
                return
            }

            isShowingArticle = true
            readerState = .showing
            articleNavigation = webView.loadHTMLString(article.html(), baseURL: url)
        }

        /// Extracts once the DOM is ready, and again after the page finishes
        /// loading if the first attempt came up empty (pages that render
        /// their content with JavaScript).
        private func extractArticle() {
            guard isReaderModeEnabled,
                  article == nil,
                  !isArticleUnavailable,
                  !isShowingArticle,
                  !isExtracting,
                  pageProgress == .domReady || pageProgress == .finished,
                  let webView
            else {
                return
            }

            isExtracting = true
            let generation = loadGeneration
            let isFinalAttempt = pageProgress == .finished

            Task { @MainActor in
                let extracted = await readableArticle(in: webView)
                guard generation == loadGeneration else {
                    return
                }
                isExtracting = false

                if let extracted {
                    article = extracted
                    if isReaderModeEnabled {
                        showArticle(extracted)
                    }
                } else if isFinalAttempt {
                    markArticleUnavailable()
                } else if pageProgress == .finished {
                    extractArticle()
                }
            }
        }

        private func readableArticle(in webView: WKWebView) async -> ReaderArticle? {
            let result = try? await webView.callAsyncJavaScript(
                "return readingListExtractArticle();",
                contentWorld: Self.readerWorld
            )
            guard let json = result as? String,
                  let article = ReaderArticle(json: json),
                  article.isReadable
            else {
                return nil
            }
            return article
        }

        private func markArticleUnavailable() {
            isArticleUnavailable = true
            if isReaderModeEnabled {
                readerState = .unavailable
            }
        }

        private func isArticleNavigation(_ navigation: WKNavigation?) -> Bool {
            navigation != nil && navigation === articleNavigation
        }

        private func isLinkWithinArticle(_ target: URL) -> Bool {
            guard let url, target.fragment != nil else {
                return false
            }
            var targetComponents = URLComponents(url: target, resolvingAgainstBaseURL: true)
            var articleComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
            targetComponents?.fragment = nil
            articleComponents?.fragment = nil
            return targetComponents == articleComponents
        }

        // MARK: WKScriptMessageHandler

        func userContentController(
            _: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == Self.documentReadyMessage,
                  !isShowingArticle,
                  pageProgress == .committed
            else {
                return
            }
            pageProgress = .domReady
            extractArticle()
        }

        // MARK: WKNavigationDelegate

        func webView(
            _: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            preferences: WKWebpagePreferences,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
        ) {
            guard isShowingArticle, navigationAction.targetFrame?.isMainFrame != false else {
                decisionHandler(.allow, preferences)
                return
            }

            if navigationAction.navigationType == .linkActivated,
               let target = navigationAction.request.url,
               !isLinkWithinArticle(target)
            {
                NSWorkspace.shared.open(target)
                decisionHandler(.cancel, preferences)
                return
            }

            preferences.allowsContentJavaScript = false
            decisionHandler(.allow, preferences)
        }

        func webView(_: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            guard !isArticleNavigation(navigation) else {
                return
            }
            pageProgress = .loading
        }

        func webView(_: WKWebView, didCommit navigation: WKNavigation!) {
            guard !isArticleNavigation(navigation), !isShowingArticle else {
                return
            }
            pageProgress = .committed
        }

        func webView(_: WKWebView, didFinish navigation: WKNavigation!) {
            guard !isArticleNavigation(navigation), !isShowingArticle else {
                return
            }
            pageProgress = .finished
            extractArticle()
        }

        func webView(_: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
            pageDidFail(navigation, error: error)
        }

        func webView(
            _: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: any Error
        ) {
            pageDidFail(navigation, error: error)
        }

        private func pageDidFail(_ navigation: WKNavigation?, error: any Error) {
            guard !isArticleNavigation(navigation),
                  !isShowingArticle,
                  (error as NSError).code != NSURLErrorCancelled
            else {
                return
            }
            pageProgress = .finished
            if readerState == .extracting, !isExtracting {
                markArticleUnavailable()
            }
        }

        // MARK: WKUIDelegate

        // Loads links that ask for a new window (target="_blank") in the same
        // preview instead of silently dropping them.
        func webView(
            _ webView: WKWebView,
            createWebViewWith _: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures _: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                if isShowingArticle {
                    NSWorkspace.shared.open(url)
                } else {
                    webView.load(URLRequest(url: url))
                }
            }
            return nil
        }
    }
}

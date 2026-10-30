import Foundation

/// An article extracted from a web page by Readability, rendered as a
/// distraction-free page for reader mode.
struct ReaderArticle: Decodable, Equatable, Sendable {
    var title: String?
    var byline: String?
    var siteName: String?
    var content: String
    var textLength: Int?
    var lang: String?
    var dir: String?

    /// Readability returns its best guess even for pages that aren't articles
    /// (video pages, app shells); anything shorter than this isn't worth reading.
    static let minimumTextLength = 200

    var isReadable: Bool {
        (textLength ?? 0) >= Self.minimumTextLength
    }

    init(
        title: String? = nil,
        byline: String? = nil,
        siteName: String? = nil,
        content: String,
        textLength: Int? = nil,
        lang: String? = nil,
        dir: String? = nil
    ) {
        self.title = title
        self.byline = byline
        self.siteName = siteName
        self.content = content
        self.textLength = textLength
        self.lang = lang
        self.dir = dir
    }

    init?(json: String) {
        guard let data = json.data(using: .utf8),
              let article = try? JSONDecoder().decode(ReaderArticle.self, from: data)
        else {
            return nil
        }
        self = article
    }

    var metadataLine: String? {
        let parts = [siteName, byline]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let uniqueParts = parts.reduce(into: [String]()) { result, part in
            if !result.contains(where: { $0.caseInsensitiveCompare(part) == .orderedSame }) {
                result.append(part)
            }
        }
        return uniqueParts.isEmpty ? nil : uniqueParts.joined(separator: " · ")
    }

    func html() -> String {
        var header = ""
        if let metadataLine {
            header += "<p class=\"reader-meta\">\(Self.escape(metadataLine))</p>\n"
        }
        if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            header += "<h1 class=\"reader-title\">\(Self.escape(title))</h1>\n"
        }

        let langAttribute = lang.map { " lang=\"\(Self.escape($0))\"" } ?? ""
        let dirAttribute = dir.map { " dir=\"\(Self.escape($0))\"" } ?? ""

        return """
        <!DOCTYPE html>
        <html\(langAttribute)\(dirAttribute)>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="script-src 'none'">
        <style>\(Self.stylesheet)</style>
        </head>
        <body>
        <article>
        <header>
        \(header)</header>
        \(content)
        </article>
        </body>
        </html>
        """
    }

    static func escape(_ text: String) -> String {
        var escaped = ""
        escaped.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": escaped += "&amp;"
            case "<": escaped += "&lt;"
            case ">": escaped += "&gt;"
            case "\"": escaped += "&quot;"
            case "'": escaped += "&#39;"
            default: escaped.append(character)
            }
        }
        return escaped
    }

    private static let stylesheet = """
    :root {
        color-scheme: light dark;
        --secondary: color-mix(in srgb, CanvasText 55%, transparent);
        --hairline: color-mix(in srgb, CanvasText 15%, transparent);
        --tint: color-mix(in srgb, CanvasText 5%, transparent);
    }
    html { -webkit-text-size-adjust: 100%; }
    body {
        margin: 0;
        padding: 36px 28px 96px;
        color: CanvasText;
        background: transparent;
        font: 19px/1.65 ui-serif, "New York", Georgia, serif;
        -webkit-font-smoothing: antialiased;
        overflow-wrap: break-word;
    }
    article { max-width: 38em; margin: 0 auto; }
    header { margin-bottom: 2em; }
    .reader-meta {
        margin: 0 0 0.6em;
        font: 500 13px/1.4 -apple-system, system-ui, sans-serif;
        letter-spacing: 0.01em;
        color: var(--secondary);
    }
    .reader-title { margin: 0; font-size: 1.75em; line-height: 1.2; font-weight: 700; }
    h1, h2, h3, h4, h5, h6 { line-height: 1.3; margin: 1.6em 0 0.6em; }
    h2 { font-size: 1.35em; }
    h3 { font-size: 1.15em; }
    h4, h5, h6 { font-size: 1em; }
    p, ul, ol, dl, figure, table, pre, blockquote { margin: 0 0 1.1em; }
    a { color: -apple-system-control-accent; text-decoration: none; }
    a:hover { text-decoration: underline; }
    img, video, svg, iframe { max-width: 100%; height: auto; }
    img { border-radius: 6px; }
    figure { margin-left: 0; margin-right: 0; }
    figcaption, caption {
        margin-top: 0.5em;
        font: 14px/1.45 -apple-system, system-ui, sans-serif;
        color: var(--secondary);
    }
    blockquote {
        margin-left: 0;
        padding-left: 1em;
        border-left: 3px solid var(--hairline);
        color: var(--secondary);
    }
    code, pre, kbd, samp { font-family: ui-monospace, Menlo, monospace; font-size: 0.82em; }
    code { background: var(--tint); padding: 0.1em 0.3em; border-radius: 4px; }
    pre { background: var(--tint); padding: 12px 14px; border-radius: 8px; overflow-x: auto; line-height: 1.5; }
    pre code { background: none; padding: 0; font-size: inherit; }
    hr { border: 0; border-top: 1px solid var(--hairline); margin: 2em 0; }
    table { display: block; overflow-x: auto; border-collapse: collapse; font-size: 0.85em; }
    th, td { border: 1px solid var(--hairline); padding: 6px 10px; text-align: left; }
    """
}

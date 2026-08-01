import Foundation
import FoundationModels

// MARK: - Data loading

struct Item {
    let title: String
    let urlString: String
    let hostname: String
    let preview: String?
    let dateAdded: Date?

    var titleIsJustURL: Bool {
        title == urlString || title.hasPrefix("http")
    }
}

func loadItems() throws -> [Item] {
    let url = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Safari/Bookmarks.plist")
    let data = try Data(contentsOf: url)
    let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    guard let root = plist as? [String: Any] else { return [] }

    func findReadingList(_ node: [String: Any]) -> [String: Any]? {
        if node["Title"] as? String == "com.apple.ReadingList" { return node }
        for child in node["Children"] as? [[String: Any]] ?? [] {
            if let found = findReadingList(child) { return found }
        }
        return nil
    }

    guard let rl = findReadingList(root) else { return [] }
    return (rl["Children"] as? [[String: Any]] ?? []).compactMap { payload in
        guard let urlString = payload["URLString"] as? String,
              let url = URL(string: urlString) else { return nil }
        let meta = payload["ReadingList"] as? [String: Any]
        let uri = payload["URIDictionary"] as? [String: Any]
        let title = (uri?["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let preview = (meta?["PreviewText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return Item(
            title: (title?.isEmpty == false ? title! : urlString),
            urlString: urlString,
            hostname: url.host?.lowercased() ?? "(no host)",
            preview: (preview?.isEmpty == false ? preview : nil),
            dateAdded: (meta?["DateAdded"] as? Date) ?? (payload["DateAdded"] as? Date)
        )
    }
}

// Deterministic sampling so runs are comparable.
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}

func sample(_ items: [Item], _ n: Int, seed: UInt64 = 42) -> [Item] {
    var rng = SeededRNG(seed: seed)
    return Array(items.shuffled(using: &rng).prefix(n))
}

func truncate(_ s: String, _ n: Int) -> String {
    s.count <= n ? s : String(s.prefix(n - 1)) + "…"
}

func itemContext(_ item: Item, includePreview: Bool) -> String {
    var lines = ["Title: \(item.title)", "Site: \(item.hostname)"]
    if includePreview, let preview = item.preview {
        lines.append("Excerpt: \(truncate(preview, 400))")
    }
    return lines.joined(separator: "\n")
}

// MARK: - Generable types

@Generable
struct ItemTopics {
    @Guide(description: "1 to 3 broad topic tags for this saved link, lowercase, 1-2 words each, e.g. \"web design\", \"ai\", \"travel\"")
    var topics: [String]
}

@Generable
struct SuggestedLists {
    @Guide(description: "5 to 8 suggested reading-list categories that together cover most of these links")
    var lists: [SuggestedList]
}

@Generable
struct SuggestedList {
    @Guide(description: "Short category name, 1-3 words, title case")
    var name: String
    @Guide(description: "3-6 lowercase keywords that identify links belonging to this category")
    var keywords: [String]
}

@Generable
struct ListAssignment {
    @Guide(description: "The single best-matching category name from the provided options, or \"None\" if nothing fits")
    var category: String
}

@Generable
struct CleanedPreview {
    @Guide(description: "One clean, informative sentence (max 140 characters) describing what this page is about, written in neutral tone. No marketing fluff, no cookie/newsletter boilerplate.")
    var summary: String
}

// MARK: - Experiments

func audit(_ items: [Item]) {
    print("== DATA AUDIT (\(items.count) items) ==")
    let withPreview = items.filter { $0.preview != nil }
    let urlTitles = items.filter(\.titleIsJustURL)
    print("with preview text : \(withPreview.count) (\(withPreview.count * 100 / max(items.count, 1))%)")
    print("title is just URL : \(urlTitles.count) (\(urlTitles.count * 100 / max(items.count, 1))%)")

    let lengths = withPreview.compactMap { $0.preview?.count }.sorted()
    if !lengths.isEmpty {
        print("preview length    : median \(lengths[lengths.count / 2]), p10 \(lengths[lengths.count / 10]), p90 \(lengths[lengths.count * 9 / 10]), max \(lengths.last!)")
    }

    let boilerplateMarkers = ["cookie", "subscribe", "sign in", "javascript", "newsletter", "log in"]
    let noisy = withPreview.filter { item in
        let p = item.preview!.lowercased()
        return boilerplateMarkers.contains(where: p.contains)
    }
    print("previews w/ boilerplate markers: \(noisy.count) of \(withPreview.count)")

    let hosts = Dictionary(grouping: items, by: \.hostname)
        .map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
    print("distinct hosts    : \(hosts.count); top: " + hosts.prefix(8).map { "\($0.0) (\($0.1))" }.joined(separator: ", "))
}

func topics(_ items: [Item]) async {
    let picks = sample(items, 40)
    print("== TOPIC EXTRACTION (title+preview, \(picks.count) items) ==")
    var counts: [String: Int] = [:]
    var failures = 0
    let start = Date()

    for item in picks {
        let session = LanguageModelSession(instructions: "You tag saved web links with broad reusable topics so they can be grouped. Prefer general tags shared across many links over hyper-specific ones.")
        do {
            let result = try await session.respond(
                to: "Tag this saved link:\n\(itemContext(item, includePreview: true))",
                generating: ItemTopics.self
            )
            let tags = result.content.topics.map { $0.lowercased() }
            for t in tags {
                counts[t, default: 0] += 1
            }
            print("• \(truncate(item.title, 58))  →  \(tags.joined(separator: ", "))")
        } catch {
            failures += 1
            print("• \(truncate(item.title, 58))  →  FAILED (\(shortError(error)))")
        }
    }

    let elapsed = Date().timeIntervalSince(start)
    print(String(format: "\n%d items in %.0fs (%.1fs/item), %d failures", picks.count, elapsed, elapsed / Double(picks.count), failures))
    let top = counts.sorted { $0.value > $1.value }.prefix(20)
    print("aggregated topics: " + top.map { "\($0.key) ×\($0.value)" }.joined(separator: ", "))
}

func titleOnlyComparison(_ items: [Item]) async {
    let picks = sample(items.filter { $0.preview != nil }, 10, seed: 7)
    print("== TITLE-ONLY vs TITLE+PREVIEW (\(picks.count) items) ==")
    for item in picks {
        var results: [String] = []
        for includePreview in [false, true] {
            let session = LanguageModelSession(instructions: "You tag saved web links with broad reusable topics.")
            do {
                let r = try await session.respond(
                    to: "Tag this saved link:\n\(itemContext(item, includePreview: includePreview))",
                    generating: ItemTopics.self
                )
                results.append(r.content.topics.map { $0.lowercased() }.joined(separator: ", "))
            } catch {
                results.append("FAILED")
            }
        }
        print("• \(truncate(item.title, 50))")
        print("    title-only : \(results[0])")
        print("    with prev. : \(results[1])")
    }
}

func suggestLists(_ items: [Item]) async {
    let picks = sample(items, 80, seed: 99)
    print("== SMART LIST SUGGESTION (from \(picks.count) titles) ==")
    let titleBlock = picks.map { "- \($0.title) (\($0.hostname))" }.joined(separator: "\n")
    let session = LanguageModelSession(instructions: "You design reading-list categories. Given link titles, propose categories that would group them usefully.")
    do {
        let start = Date()
        let r = try await session.respond(
            to: "Here are saved links:\n\(truncate(titleBlock, 6000))\n\nPropose categories.",
            generating: SuggestedLists.self
        )
        print(String(format: "(%.1fs)", Date().timeIntervalSince(start)))
        for list in r.content.lists {
            print("• \(list.name): \(list.keywords.joined(separator: ", "))")
        }
    } catch {
        print("FAILED: \(shortError(error))")
    }
}

func classify(_ items: [Item], categories: [String]) async {
    let picks = sample(items, 20, seed: 123)
    print("== CLASSIFY INTO LISTS \(categories) (\(picks.count) items) ==")
    var histogram: [String: Int] = [:]
    for item in picks {
        let session = LanguageModelSession(instructions: "Assign the link to exactly one category from this set: \(categories.joined(separator: ", ")), or \"None\" if nothing fits well.")
        do {
            let r = try await session.respond(
                to: "Assign this link:\n\(itemContext(item, includePreview: true))",
                generating: ListAssignment.self
            )
            let cat = r.content.category
            let valid = categories.contains(cat) || cat == "None"
            histogram[cat, default: 0] += 1
            print("• \(truncate(item.title, 55)) → \(cat)\(valid ? "" : "  ⚠️ NOT IN SET")")
        } catch {
            print("• \(truncate(item.title, 55)) → FAILED (\(shortError(error)))")
        }
    }
    print("distribution: \(histogram.sorted { $0.value > $1.value }.map { "\($0.key) ×\($0.value)" }.joined(separator: ", "))")
}

func cleanup(_ items: [Item]) async {
    let picks = sample(items.filter { ($0.preview?.count ?? 0) > 80 }, 8, seed: 5)
    print("== PREVIEW CLEANUP (\(picks.count) items) ==")
    for item in picks {
        let session = LanguageModelSession(instructions: "You clean up scraped page excerpts into one informative sentence.")
        do {
            let r = try await session.respond(
                to: "Page title: \(item.title)\nScraped excerpt: \(truncate(item.preview ?? "", 500))",
                generating: CleanedPreview.self
            )
            print("• \(truncate(item.title, 55))")
            print("    before: \(truncate(item.preview ?? "", 110))")
            print("    after : \(r.content.summary)")
        } catch {
            print("• \(truncate(item.title, 55)) → FAILED (\(shortError(error)))")
        }
    }
}

func fetchEnrichment(_ items: [Item]) async {
    let picks = sample(items.filter { $0.preview == nil && !$0.titleIsJustURL }, 5, seed: 11)
    print("== PAGE FETCH ENRICHMENT (\(picks.count) items without preview) ==")
    for item in picks {
        guard let url = URL(string: item.urlString) else { continue }
        do {
            let fetchStart = Date()
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.setValue("Mozilla/5.0 (Macintosh)", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
            let fetchTime = Date().timeIntervalSince(fetchStart)
            let html = String(decoding: data, as: UTF8.self)
            let text = stripHTML(html)
            let session = LanguageModelSession(instructions: "You clean up page content into one informative sentence describing the page.")
            let r = try await session.respond(
                to: "Page title: \(item.title)\nPage text: \(truncate(text, 1500))",
                generating: CleanedPreview.self
            )
            print("• \(truncate(item.title, 55)) [fetch \(String(format: "%.1f", fetchTime))s, \(data.count / 1024)KB]")
            print("    summary: \(r.content.summary)")
        } catch {
            print("• \(truncate(item.title, 55)) → FAILED (\(shortError(error)))")
        }
    }
}

func stripHTML(_ html: String) -> String {
    var text = html
    for tag in ["script", "style", "noscript", "svg", "head"] {
        text = text.replacingOccurrences(
            of: "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>",
            with: " ", options: [.regularExpression, .caseInsensitive]
        )
    }
    text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
    text = text.replacingOccurrences(of: "&[a-zA-Z#0-9]+;", with: " ", options: .regularExpression)
    return text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func shortError(_ error: Error) -> String {
    if let generationError = error as? LanguageModelSession.GenerationError {
        return String(describing: generationError).components(separatedBy: "(").first ?? "generation error"
    }
    return truncate(error.localizedDescription, 80)
}

// MARK: - Main

@main
struct Experiments {
    static func main() async {
        guard case .available = SystemLanguageModel.default.availability else {
            print("Model unavailable"); exit(1)
        }
        let items: [Item]
        do {
            items = try loadItems()
        } catch {
            print("Could not load items: \(error)"); exit(1)
        }

        let mode = CommandLine.arguments.dropFirst().first ?? "all"
        switch mode {
        case "audit":
            audit(items)
        case "topics":
            await topics(items)
        case "compare":
            await titleOnlyComparison(items)
        case "suggest":
            await suggestLists(items)
        case "classify":
            let categories = Array(CommandLine.arguments.dropFirst(2))
            await classify(items, categories: categories.isEmpty
                ? ["Design", "Programming", "AI", "Business", "Products", "Entertainment", "News"]
                : categories)
        case "cleanup":
            await cleanup(items)
        case "fetch":
            await fetchEnrichment(items)
        default:
            audit(items)
            print("")
            await topics(items)
            print("")
            await titleOnlyComparison(items)
            print("")
            await suggestLists(items)
            print("")
            await cleanup(items)
            print("")
            await fetchEnrichment(items)
        }
    }
}

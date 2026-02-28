import Foundation

enum DemoReadingListData {
    static func makeItems(now: Date = Date(), calendar: Calendar = .current) -> [ReadingListItem] {
        var items: [ReadingListItem] = []

        func dateAdded(daysAgo: Int, hourOffset: Int = 0) -> Date? {
            let totalHours = (daysAgo * 24) + hourOffset
            return calendar.date(byAdding: .hour, value: -totalHours, to: now)
        }

        func viewedDate(daysAgo: Int?) -> Date? {
            guard let daysAgo else {
                return nil
            }
            return calendar.date(byAdding: .day, value: -daysAgo, to: now)
        }

        func slug(_ text: String) -> String {
            text
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .joined(separator: "-")
        }

        let supplementalPreviewPhrases = [
            "I saved this to compare it with a few related links before deciding what is actually useful.",
            "There are probably two or three concrete takeaways here that I can turn into notes or small experiments.",
            "This looks like the kind of link that is easy to forget, so I want it in one place while I am reviewing similar topics.",
            "I want to revisit this with a bit more context and see whether it should become part of a smart list.",
            "The main reason this is saved is to cross-reference it with other items from the same week.",
            "Even if I do not need it immediately, it seems likely to be useful when I am refining product decisions.",
            "I kept this because it connects nicely to a couple of open questions I already have in my backlog.",
            "This might not be urgent, but it is the sort of reference I usually wish I had kept when I need it later.",
        ]

        func stableSeed(for text: String) -> UInt64 {
            text.unicodeScalars.reduce(UInt64(1_469_598_103_934_665_603)) { partialResult, scalar in
                (partialResult &* 1_099_511_628_211) ^ UInt64(scalar.value)
            }
        }

        func supplementalPhrase(seed: UInt64, offset: UInt64 = 0) -> String {
            guard !supplementalPreviewPhrases.isEmpty else {
                return ""
            }

            let count = UInt64(supplementalPreviewPhrases.count)
            let index = Int((seed &+ offset) % count)
            return supplementalPreviewPhrases[index]
        }

        func sentenceCount(in text: String) -> Int {
            text.split { character in
                character == "." || character == "!" || character == "?"
            }.count
        }

        func expandedPreview(_ base: String, title: String, url: URL) -> String {
            let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return base
            }

            if sentenceCount(in: trimmed) >= 2, trimmed.count >= 120 {
                return trimmed
            }

            let seed = stableSeed(for: "\(title)|\(url.absoluteString)")
            let first = supplementalPhrase(seed: seed)
            let second = supplementalPhrase(seed: seed, offset: 3)
            guard !first.isEmpty else {
                return trimmed
            }

            if sentenceCount(in: trimmed) >= 2 {
                return "\(trimmed) \(first)"
            }

            return "\(trimmed) \(first) \(second)"
        }

        func append(
            _ title: String,
            _ urlString: String,
            preview: String,
            addedDaysAgo: Int,
            addedHourOffset: Int = 0,
            viewedDaysAgo: Int? = nil
        ) {
            guard let url = URL(string: urlString) else {
                return
            }

            items.append(
                ReadingListItem(
                    title: title,
                    url: url,
                    previewText: expandedPreview(preview, title: title, url: url),
                    dateAdded: dateAdded(daysAgo: addedDaysAgo, hourOffset: addedHourOffset),
                    dateLastViewed: viewedDate(daysAgo: viewedDaysAgo)
                )
            )
        }

        let betaListTopics = [
            "Undo for Real Life",
            "Inbox Zero in Three Lifetimes",
            "Launch Checklist Roulette",
            "Ship It Friday",
            "Feature Flag Fortune Cookie",
            "One More Iteration",
            "No Meetings Wednesday",
            "Dark Mode for Spreadsheets",
            "Patch Notes for Humans",
            "Retry Button for Decisions",
            "404 for Chores",
            "Coffee Driven Roadmaps",
            "Keyboard Shortcut Trainer",
            "Time Zone Translator for Remote Teams",
        ]
        for (index, topic) in betaListTopics.enumerated() {
            append(
                "BetaList: \(topic)",
                "https://betalist.com/startups/\(slug(topic))",
                preview: "Saved startup concept to revisit when brainstorming product ideas.",
                addedDaysAgo: (index * 2) % 30,
                addedHourOffset: index,
                viewedDaysAgo: index.isMultiple(of: 8) ? 2 : nil
            )
        }

        let rubyWeeklyTopics = [
            "Rails 8 performance notes",
            "Pattern matching in Ruby 3.4",
            "Background jobs that survive production",
            "Hotwire without surprises",
            "RuboCop defaults worth revisiting",
            "Profiling memory in production",
            "Debugging flaky tests",
            "Simple authentication in Rails",
            "Deployment checklists that actually work",
            "Refactoring without fear",
        ]
        for (index, topic) in rubyWeeklyTopics.enumerated() {
            let issueNumber = 700 + index
            append(
                "Ruby Weekly #\(issueNumber): \(topic)",
                "https://rubyweekly.com/issues/\(issueNumber)",
                preview: "Ruby ecosystem roundup with practical links worth keeping.",
                addedDaysAgo: (index * 3) % 35,
                addedHourOffset: index + 1
            )
        }

        let rubyOnRailsTopics = [
            "Active Record strict loading patterns",
            "Action Mailbox in real products",
            "Solid Queue rollout notes",
            "Caching invalidation strategies",
            "Rake tasks that pay for themselves",
            "Database indexes for fast feeds",
        ]
        for (index, topic) in rubyOnRailsTopics.enumerated() {
            append(
                "Ruby on Rails: \(topic)",
                "https://rubyonrails.org/2026/2/\(index + 1)/\(slug(topic))",
                preview: "Rails article to test ideas in side projects.",
                addedDaysAgo: 4 + (index * 4),
                addedHourOffset: index * 2,
                viewedDaysAgo: index == 2 ? 5 : nil
            )
        }

        let rubyLangTopics = [
            "Matz keynote notes",
            "Ruby 3.4 changelog highlights",
            "Parser updates and syntax polish",
            "YJIT improvements summary",
            "Stdlib changes to watch",
        ]
        for (index, topic) in rubyLangTopics.enumerated() {
            append(
                "Ruby Language: \(topic)",
                "https://www.ruby-lang.org/en/news/2026/02/\(index + 1)-\(slug(topic))/",
                preview: "Official Ruby language updates and release notes.",
                addedDaysAgo: 7 + (index * 5),
                viewedDaysAgo: index == 1 ? 3 : nil
            )
        }

        let macStoriesTopics = [
            "Best Mac shortcuts this month",
            "Window management experiments",
            "Automation setup for writing",
            "Desktop widget review",
            "Notes app power workflows",
            "Comparing task managers on macOS",
            "Native app round up",
            "Finder tips that still matter",
            "Mac app launch checklist",
            "Reviewing this year's utility apps",
        ]
        for (index, topic) in macStoriesTopics.enumerated() {
            append(
                "MacStories: \(topic)",
                "https://www.macstories.net/stories/\(slug(topic))/",
                preview: "macOS workflow article saved for a later deep dive.",
                addedDaysAgo: index + 1,
                addedHourOffset: index
            )
        }

        let macRumorsTopics = [
            "Apple Silicon buyer guide update",
            "macOS release timeline rumor",
            "MacBook accessory roundup",
            "Vision features coming to macOS",
            "Developer beta first impressions",
            "New Mac mini expectations",
            "Apple event recap for Mac users",
            "iCloud storage changes explained",
        ]
        for (index, topic) in macRumorsTopics.enumerated() {
            append(
                "MacRumors: \(topic)",
                "https://www.macrumors.com/2026/02/\(index + 1)/\(slug(topic))/",
                preview: "Mac news piece to skim when catching up.",
                addedDaysAgo: 2 + (index * 2),
                viewedDaysAgo: index == 3 ? 1 : nil
            )
        }

        let sixColorsTopics = [
            "State of the Mac dashboard",
            "Thoughts on app discoverability",
            "Reviewing note taking apps",
            "The return of menu bar utilities",
            "Task batching on desktop",
            "A week with minimalist setup",
        ]
        for (index, topic) in sixColorsTopics.enumerated() {
            append(
                "Six Colors: \(topic)",
                "https://sixcolors.com/post/2026/02/\(slug(topic))/",
                preview: "Opinionated but useful takes on Apple platforms.",
                addedDaysAgo: 5 + (index * 3),
                viewedDaysAgo: index == 4 ? 2 : nil
            )
        }

        let daringFireballTopics = [
            "Linking to launch day reactions",
            "Notes on release engineering",
            "UI polish in small apps",
            "The long tail of utility software",
        ]
        for (index, topic) in daringFireballTopics.enumerated() {
            append(
                "Daring Fireball: \(topic)",
                "https://daringfireball.net/linked/2026/02/\(slug(topic))",
                preview: "Quick link post that usually sends me down another rabbit hole.",
                addedDaysAgo: 9 + (index * 4),
                viewedDaysAgo: index == 0 ? 2 : nil
            )
        }

        let videoEntries: [(title: String, url: String, preview: String, daysAgo: Int, viewed: Int?)] = [
            (
                "YouTube: SwiftUI list performance in practice",
                "https://www.youtube.com/watch?v=swiftui-list-perf-01",
                "Concrete ideas for smoother scrolling and less view churn.",
                1,
                nil
            ),
            (
                "YouTube: Better keyboard navigation on macOS",
                "https://www.youtube.com/watch?v=keyboard-nav-ux-02",
                "Small keyboard details that make desktop apps feel native.",
                3,
                nil
            ),
            (
                "Vimeo: Product design critiques for utility apps",
                "https://vimeo.com/128844001",
                "Design review style session with practical takeaways.",
                6,
                1
            ),
            (
                "Twitch VOD: Build in public stream recap",
                "https://www.twitch.tv/videos/1000022222",
                "Live coding session focused on bug fixing and polishing.",
                8,
                nil
            ),
            (
                "TikTok: tiny macOS productivity tricks",
                "https://www.tiktok.com/@demo/video/7420002222",
                "Short clip collection worth trying once.",
                4,
                nil
            ),
            (
                "Bilibili: app icon design walkthrough",
                "https://www.bilibili.com/video/BV1demoIcon01/",
                "Visual design process from sketch to final icon.",
                11,
                nil
            ),
            (
                "Rumble: independent dev business notes",
                "https://rumble.com/v5-indie-dev-notes.html",
                "Long form discussion on pricing and launch timing.",
                14,
                5
            ),
            (
                "Loom: team feedback on onboarding flow",
                "https://www.loom.com/share/demo-reading-list-002",
                "Walkthrough with concrete UX suggestions.",
                2,
                nil
            ),
        ]
        for entry in videoEntries {
            append(
                entry.title,
                entry.url,
                preview: entry.preview,
                addedDaysAgo: entry.daysAgo,
                viewedDaysAgo: entry.viewed
            )
        }

        let pdfEntries: [(title: String, url: String, preview: String, daysAgo: Int, viewed: Int?)] = [
            (
                "PDF: Designing Data Intensive Applications summary",
                "https://example.com/notes/ddia-summary.pdf",
                "Chapter notes and implementation reminders.",
                3,
                nil
            ),
            (
                "PDF: macOS Human Interface Guidelines extract",
                "https://developer.apple.com/design/human-interface-guidelines/macos.pdf",
                "Key sections for native interactions and hierarchy.",
                7,
                nil
            ),
            (
                "PDF: Research paper on delayed reading behavior",
                "https://arxiv.org/pdf/2401.01234.pdf",
                "Useful framing for why reading lists grow forever.",
                18,
                6
            ),
            (
                "Whitepaper download with format=pdf",
                "https://example.org/download?format=pdf&topic=ranking",
                "Ranking and retrieval heuristics for personal knowledge bases.",
                9,
                nil
            ),
            (
                "Platform architecture report (application/pdf)",
                "https://example.net/files/report?content-type=application/pdf",
                "Architecture choices for desktop first apps.",
                15,
                nil
            ),
            (
                "PDF: Product roadmap narrative template",
                "https://example.dev/templates/roadmap-narrative.pdf",
                "Template for writing roadmap updates people actually read.",
                12,
                2
            ),
        ]
        for entry in pdfEntries {
            append(
                entry.title,
                entry.url,
                preview: entry.preview,
                addedDaysAgo: entry.daysAgo,
                viewedDaysAgo: entry.viewed
            )
        }

        let miscEntries: [(title: String, url: String, preview: String, daysAgo: Int, viewed: Int?)] = [
            (
                "GitHub issue: table selection edge case",
                "https://github.com/example/repo/issues/42",
                "Tracking a subtle selection timing issue in a list view.",
                5,
                1
            ),
            (
                "GitHub PR: better context menus in split view",
                "https://github.com/example/repo/pull/84",
                "Reference implementation for clean contextual actions.",
                6,
                nil
            ),
            (
                "Hacker News: read later app discussion",
                "https://news.ycombinator.com/item?id=43000000",
                "Product feedback thread with feature ideas and tradeoffs.",
                2,
                nil
            ),
            (
                "XKCD: workflow comic worth bookmarking",
                "https://xkcd.com/1205/",
                "Still relevant whenever process gets overengineered.",
                20,
                8
            ),
            (
                "Apple docs: Swift concurrency guide",
                "https://swift.org/documentation/concurrency/",
                "Actor isolation and structured concurrency notes.",
                10,
                3
            ),
            (
                "Blog: The cake is a cached response",
                "https://example.blog/the-cake-is-a-cached-response",
                "A playful post on cache invalidation and stale data bugs.",
                13,
                nil
            ),
        ]
        for entry in miscEntries {
            append(
                entry.title,
                entry.url,
                preview: entry.preview,
                addedDaysAgo: entry.daysAgo,
                viewedDaysAgo: entry.viewed
            )
        }

        let hackerNewsTopics = [
            "Show HN: tiny macOS utility for unread links",
            "Ask HN: best long form reading workflow",
            "A practical guide to reducing context switching",
            "Building desktop software as a solo founder",
            "How to avoid losing saved links forever",
            "A simple way to triage big reading backlogs",
            "What makes a native macOS app feel right",
            "Shipping a useful app before it is perfect",
            "Designing keyboard first interfaces",
            "Caching lessons from real world apps",
            "Why everyone has a read later graveyard",
            "Minimal software and opinionated defaults",
            "Show HN: personal search over saved links",
            "Small products with surprisingly loyal users",
        ]
        for (index, topic) in hackerNewsTopics.enumerated() {
            append(
                "Hacker News: \(topic)",
                "https://news.ycombinator.com/item?id=\(43_001_000 + index)",
                preview: "HN thread saved for product and UX ideas.",
                addedDaysAgo: (index % 21) + 1,
                addedHourOffset: index + 1
            )
        }

        let productHuntTopics = [
            "Cursor for bookmarks",
            "Inbox gardener",
            "Tab bankruptcy assistant",
            "Screenshot librarian",
            "Launch notes helper",
            "Quiet mode for notifications",
            "One click changelog",
            "Roadmap confetti generator",
            "Personal CRM for side projects",
            "Decision journal",
            "Habit tracker for builders",
            "Little wins dashboard",
        ]
        for (index, topic) in productHuntTopics.enumerated() {
            append(
                "Product Hunt: \(topic)",
                "https://www.producthunt.com/posts/\(slug(topic))",
                preview: "Interesting launch to revisit later.",
                addedDaysAgo: (index % 24) + 1,
                addedHourOffset: index + 2
            )
        }

        let marcIoTopics = [
            "Ship the thing and iterate",
            "Avoiding vanity metrics in early products",
            "Pricing experiments that taught me something",
            "Building in public without burning out",
            "The compounding value of small tools",
            "What changed after talking to users weekly",
            "How side projects become real products",
            "Simple onboarding beats clever onboarding",
            "Working with constraints as a feature",
            "A notes app but for product decisions",
            "How to decide what not to build",
            "A tiny lesson from every launch",
        ]
        for (index, topic) in marcIoTopics.enumerated() {
            append(
                "marc.io: \(topic)",
                "https://marc.io/\(slug(topic))",
                preview: "Personal writing with practical product lessons.",
                addedDaysAgo: (index % 26) + 1,
                addedHourOffset: index + 3
            )
        }

        let wipTopics = [
            "A better weekly planning ritual",
            "How to keep momentum on side projects",
            "The real cost of too many ideas",
            "When to prune features",
            "Shipping ugly first versions",
            "Why simple products win trust",
            "Picking one KPI for a month",
            "How to write release notes people read",
            "Iterating on positioning in public",
            "What to automate and what to leave manual",
            "Weekly product review template",
            "A launch checklist that survives contact with reality",
        ]
        for (index, topic) in wipTopics.enumerated() {
            append(
                "wip.co: \(topic)",
                "https://wip.co/posts/\(slug(topic))",
                preview: "Build in public notes and founder workflow ideas.",
                addedDaysAgo: (index % 27) + 1,
                addedHourOffset: index + 4
            )
        }

        let extraMacRumorsTopics = [
            "macOS beta battery observations",
            "New Apple display rumors",
            "Mac accessories worth watching",
            "Apple event prep for developers",
            "Studio display software update notes",
        ]
        for (index, topic) in extraMacRumorsTopics.enumerated() {
            append(
                "MacRumors: \(topic)",
                "https://www.macrumors.com/2026/03/\(index + 1)/\(slug(topic))/",
                preview: "Additional Apple and Mac coverage.",
                addedDaysAgo: 3 + (index * 2),
                addedHourOffset: index + 5
            )
        }

        let appleDeveloperTopics = [
            "WWDC session: SwiftUI list details",
            "Design update for macOS controls",
            "App Store Connect quality checklist",
            "Testing strategy for desktop apps",
            "Performance guidance for web views",
            "SF Symbols update highlights",
            "Accessibility pass before release",
            "New APIs for window management",
            "Sign in with Apple edge cases",
            "Human interface update notes",
            "Platform state of the union recap",
        ]
        for (index, topic) in appleDeveloperTopics.enumerated() {
            append(
                "Apple Developer: \(topic)",
                "https://developer.apple.com/news/?id=\(slug(topic))-\(index + 1)",
                preview: "Apple platform notes relevant to polishing this app.",
                addedDaysAgo: (index % 20) + 1,
                addedHourOffset: index + 6
            )
        }

        return items.sorted { lhs, rhs in
            switch (lhs.dateAdded, rhs.dateAdded) {
            case let (leftDate?, rightDate?):
                return leftDate > rightDate
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }
}

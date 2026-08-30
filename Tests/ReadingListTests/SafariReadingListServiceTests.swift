import Foundation
@testable import ReadingList
import Testing

@Suite("SafariReadingListService")
struct SafariReadingListServiceTests {
    private func writeFixture(items: [[String: Any]]) throws -> URL {
        let root: [String: Any] = [
            "WebBookmarkType": "WebBookmarkTypeList",
            "Children": [
                [
                    "Title": "com.apple.ReadingList",
                    "WebBookmarkType": "WebBookmarkTypeList",
                    "Children": items,
                ] as [String: Any],
            ],
        ]

        let data = try PropertyListSerialization.data(
            fromPropertyList: root,
            format: .binary,
            options: 0
        )
        let url = FileManager.default.temporaryDirectory
            .appending(path: "Bookmarks-\(UUID().uuidString).plist", directoryHint: .notDirectory)
        try data.write(to: url)
        return url
    }

    private func itemPayload(
        urlString: String,
        title: String? = nil,
        dateAdded: Date? = nil,
        dateLastViewed: Date? = nil,
        previewText: String? = nil
    ) -> [String: Any] {
        var readingList: [String: Any] = [:]
        if let dateAdded {
            readingList["DateAdded"] = dateAdded
        }
        if let dateLastViewed {
            readingList["DateLastViewed"] = dateLastViewed
        }
        if let previewText {
            readingList["PreviewText"] = previewText
        }

        var payload: [String: Any] = ["URLString": urlString]
        if let title {
            payload["URIDictionary"] = ["title": title]
        }
        if !readingList.isEmpty {
            payload["ReadingList"] = readingList
        }
        return payload
    }

    @Test func fetchParsesTitlesDatesAndPreview() async throws {
        let added = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let url = try writeFixture(items: [
            itemPayload(
                urlString: "https://example.com/article",
                title: "An Article",
                dateAdded: added,
                previewText: "Preview text here"
            ),
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let service = SafariReadingListService(bookmarksPlistURL: url)
        let items = try await service.fetchItems()

        #expect(items.count == 1)
        let item = try #require(items.first)
        #expect(item.title == "An Article")
        #expect(item.hostname == "example.com")
        #expect(item.previewText == "Preview text here")
        #expect(item.isViewed == false)
        let dateAdded = try #require(item.dateAdded)
        #expect(abs(dateAdded.timeIntervalSince(added)) < 1)
    }

    @Test func fetchSortsNewestFirstAndDeduplicatesByURL() async throws {
        let older = Date(timeIntervalSinceReferenceDate: 600_000_000)
        let newer = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let url = try writeFixture(items: [
            itemPayload(urlString: "https://a.example.com/", title: "Old", dateAdded: older),
            itemPayload(urlString: "https://b.example.com/", title: "New", dateAdded: newer),
            itemPayload(urlString: "https://a.example.com/", title: "Old Duplicate", dateAdded: older),
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let service = SafariReadingListService(bookmarksPlistURL: url)
        let items = try await service.fetchItems()

        #expect(items.map(\.title) == ["New", "Old"])
    }

    @Test func fetchFallsBackToURLWhenTitleMissing() async throws {
        let url = try writeFixture(items: [
            itemPayload(urlString: "https://example.com/untitled"),
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let service = SafariReadingListService(bookmarksPlistURL: url)
        let items = try await service.fetchItems()

        #expect(items.first?.title == "https://example.com/untitled")
    }

    @Test func markAsReadRoundTrip() async throws {
        let added = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let url = try writeFixture(items: [
            itemPayload(urlString: "https://example.com/read-me", title: "Read Me", dateAdded: added),
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let service = SafariReadingListService(bookmarksPlistURL: url)
        let viewedDate = Date()
        try await service.setReadState(
            url: URL(string: "https://example.com/read-me")!,
            dateAdded: added,
            viewedDate: viewedDate
        )

        let items = try await service.fetchItems()
        let item = try #require(items.first)
        #expect(item.isViewed)
        let lastViewed = try #require(item.dateLastViewed)
        #expect(abs(lastViewed.timeIntervalSince(viewedDate)) < 1)
    }

    @Test func markAsUnreadRemovesViewedDate() async throws {
        let added = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let url = try writeFixture(items: [
            itemPayload(
                urlString: "https://example.com/unread-me",
                title: "Unread Me",
                dateAdded: added,
                dateLastViewed: Date()
            ),
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let service = SafariReadingListService(bookmarksPlistURL: url)
        try await service.setReadState(
            url: URL(string: "https://example.com/unread-me")!,
            dateAdded: added,
            viewedDate: nil
        )

        let items = try await service.fetchItems()
        let item = try #require(items.first)
        #expect(item.isViewed == false)
        #expect(item.dateLastViewed == nil)
    }

    @Test func markAsReadDisambiguatesByDateAdded() async throws {
        let older = Date(timeIntervalSinceReferenceDate: 600_000_000)
        let newer = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let sharedURL = "https://example.com/shared"
        let url = try writeFixture(items: [
            itemPayload(urlString: sharedURL, title: "Newer Copy", dateAdded: newer),
            itemPayload(urlString: sharedURL, title: "Older Copy", dateAdded: older),
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let service = SafariReadingListService(bookmarksPlistURL: url)
        try await service.setReadState(
            url: URL(string: sharedURL)!,
            dateAdded: older,
            viewedDate: Date()
        )

        let data = try Data(contentsOf: url)
        let root = try #require(
            try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        )
        let children = try #require(root["Children"] as? [[String: Any]])
        let readingListNode = try #require(children.first)
        let items = try #require(readingListNode["Children"] as? [[String: Any]])

        let newerMetadata = items[0]["ReadingList"] as? [String: Any]
        let olderMetadata = items[1]["ReadingList"] as? [String: Any]
        #expect(newerMetadata?["DateLastViewed"] == nil)
        #expect(olderMetadata?["DateLastViewed"] != nil)
    }

    @Test func markAsReadThrowsWhenItemMissing() async throws {
        let url = try writeFixture(items: [
            itemPayload(urlString: "https://example.com/exists", title: "Exists"),
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let service = SafariReadingListService(bookmarksPlistURL: url)

        await #expect(throws: ReadingListWriteError.self) {
            try await service.setReadState(
                url: URL(string: "https://example.com/missing")!,
                dateAdded: nil,
                viewedDate: Date()
            )
        }
    }

    @Test func deleteRemovesItem() async throws {
        let added = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let url = try writeFixture(items: [
            itemPayload(urlString: "https://example.com/delete-me", title: "Delete Me", dateAdded: added),
            itemPayload(urlString: "https://example.com/keep-me", title: "Keep Me", dateAdded: added),
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let service = SafariReadingListService(bookmarksPlistURL: url)
        try await service.deleteItem(
            url: URL(string: "https://example.com/delete-me")!,
            dateAdded: added
        )

        let items = try await service.fetchItems()
        #expect(items.map(\.title) == ["Keep Me"])
    }

    @Test func concurrentDeletesDoNotResurrectItems() async throws {
        let added = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let itemCount = 10
        let url = try writeFixture(items: (0 ..< itemCount).map { index in
            itemPayload(
                urlString: "https://example.com/item-\(index)",
                title: "Item \(index)",
                dateAdded: added
            )
        })
        defer { try? FileManager.default.removeItem(at: url) }

        let service = SafariReadingListService(bookmarksPlistURL: url)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0 ..< itemCount {
                group.addTask {
                    try await service.deleteItem(
                        url: URL(string: "https://example.com/item-\(index)")!,
                        dateAdded: added
                    )
                }
            }
            try await group.waitForAll()
        }

        let remaining = try await service.fetchItems()
        #expect(remaining.isEmpty)
    }

    @Test func deleteDisambiguatesByDateAdded() async throws {
        let older = Date(timeIntervalSinceReferenceDate: 600_000_000)
        let newer = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let sharedURL = "https://example.com/shared"
        let url = try writeFixture(items: [
            itemPayload(urlString: sharedURL, title: "Newer Copy", dateAdded: newer),
            itemPayload(urlString: sharedURL, title: "Older Copy", dateAdded: older),
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let service = SafariReadingListService(bookmarksPlistURL: url)
        try await service.deleteItem(url: URL(string: sharedURL)!, dateAdded: older)

        let data = try Data(contentsOf: url)
        let root = try #require(
            try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        )
        let children = try #require(root["Children"] as? [[String: Any]])
        let readingListNode = try #require(children.first)
        let items = try #require(readingListNode["Children"] as? [[String: Any]])

        #expect(items.count == 1)
        let title = (items[0]["URIDictionary"] as? [String: Any])?["title"] as? String
        #expect(title == "Newer Copy")
    }

    @Test func deleteThrowsWhenItemMissing() async throws {
        let url = try writeFixture(items: [
            itemPayload(urlString: "https://example.com/exists", title: "Exists"),
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let service = SafariReadingListService(bookmarksPlistURL: url)

        await #expect(throws: ReadingListWriteError.self) {
            try await service.deleteItem(
                url: URL(string: "https://example.com/missing")!,
                dateAdded: nil
            )
        }
    }

    @Test func fetchThrowsWhenFileMissing() async throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "missing-\(UUID().uuidString).plist", directoryHint: .notDirectory)
        let service = SafariReadingListService(bookmarksPlistURL: url)

        await #expect(throws: ReadingListLoadError.self) {
            _ = try await service.fetchItems()
        }
    }
}

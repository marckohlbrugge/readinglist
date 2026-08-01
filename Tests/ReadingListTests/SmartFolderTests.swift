import Foundation
@testable import ReadingList
import Testing

private func makeItem(
    title: String = "Title",
    urlString: String = "https://example.com/",
    previewText: String? = nil,
    dateAdded: Date? = Date(),
    dateLastViewed: Date? = nil
) -> ReadingListItem {
    ReadingListItem(
        title: title,
        url: URL(string: urlString)!,
        previewText: previewText,
        dateAdded: dateAdded,
        dateLastViewed: dateLastViewed
    )
}

@Suite("SmartFolder matching")
struct SmartFolderTests {
    @Test func hostnameMatchesExactAndSubdomains() {
        let folder = SmartFolder(
            id: "videos",
            name: "Videos",
            systemImage: "play.rectangle.fill",
            hostnames: ["youtube.com"],
            isBuiltIn: true
        )

        #expect(folder.matches(item: makeItem(urlString: "https://youtube.com/watch?v=1")))
        #expect(folder.matches(item: makeItem(urlString: "https://www.youtube.com/watch?v=1")))
        #expect(!folder.matches(item: makeItem(urlString: "https://notyoutube.com/watch?v=1")))
        #expect(!folder.matches(item: makeItem(urlString: "https://example.com/youtube.com")))
    }

    @Test func keywordsMatchTitleURLAndPreview() {
        let folder = SmartFolder(
            id: "pdfs",
            name: "PDFs",
            systemImage: "doc.fill",
            keywords: [".pdf"],
            isBuiltIn: true
        )

        #expect(folder.matches(item: makeItem(urlString: "https://example.com/paper.pdf")))
        #expect(folder.matches(item: makeItem(title: "Annual report.PDF")))
        #expect(folder.matches(item: makeItem(previewText: "Download the file.pdf here")))
        #expect(!folder.matches(item: makeItem(title: "No match")))
    }

    @Test func combinedCriteriaRequireAllFilters() {
        let folder = SmartFolder(
            id: "combo",
            name: "Combo",
            systemImage: "folder.fill",
            hostnames: ["example.com"],
            keywords: ["swift"],
            isBuiltIn: false
        )

        #expect(folder.matches(item: makeItem(title: "Swift news", urlString: "https://example.com/a")))
        #expect(!folder.matches(item: makeItem(title: "Swift news", urlString: "https://other.com/a")))
        #expect(!folder.matches(item: makeItem(title: "Rust news", urlString: "https://example.com/a")))
    }

    @Test func hostnameNormalizationHandlesCaseAndWhitespace() {
        let folder = SmartFolder(
            id: "normalized",
            name: "Normalized",
            systemImage: "folder.fill",
            hostnames: ["  YouTube.com  "],
            isBuiltIn: false
        )

        #expect(folder.matches(item: makeItem(urlString: "https://youtube.com/")))
    }
}

@Suite("AddedDateFilter")
struct AddedDateFilterTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSinceReferenceDate: 700_000_000)

    @Test func anyMatchesEverythingIncludingNilDates() {
        #expect(AddedDateFilter.any.matches(dateAdded: nil, now: now, calendar: calendar))
        #expect(AddedDateFilter.any.matches(dateAdded: now, now: now, calendar: calendar))
    }

    @Test func nonAnyFiltersRejectNilDates() {
        #expect(!AddedDateFilter.today.matches(dateAdded: nil, now: now, calendar: calendar))
        #expect(!AddedDateFilter.last7Days.matches(dateAdded: nil, now: now, calendar: calendar))
    }

    @Test func todayMatchesSameDayOnly() {
        let sameDay = now.addingTimeInterval(-60)
        let yesterday = now.addingTimeInterval(-60 * 60 * 24)
        #expect(AddedDateFilter.today.matches(dateAdded: sameDay, now: now, calendar: calendar))
        #expect(!AddedDateFilter.today.matches(dateAdded: yesterday, now: now, calendar: calendar))
    }

    @Test func last7DaysUsesRollingWindow() {
        let sixDaysAgo = now.addingTimeInterval(-60 * 60 * 24 * 6)
        let eightDaysAgo = now.addingTimeInterval(-60 * 60 * 24 * 8)
        #expect(AddedDateFilter.last7Days.matches(dateAdded: sixDaysAgo, now: now, calendar: calendar))
        #expect(!AddedDateFilter.last7Days.matches(dateAdded: eightDaysAgo, now: now, calendar: calendar))
    }
}

@Suite("ReadingStatusFilter")
struct ReadingStatusFilterTests {
    @Test func includesRespectsViewedState() {
        let unread = makeItem()
        let viewed = makeItem(dateLastViewed: Date())

        #expect(ReadingStatusFilter.unread.includes(unread))
        #expect(!ReadingStatusFilter.unread.includes(viewed))
        #expect(ReadingStatusFilter.viewed.includes(viewed))
        #expect(!ReadingStatusFilter.viewed.includes(unread))
        #expect(ReadingStatusFilter.all.includes(unread))
        #expect(ReadingStatusFilter.all.includes(viewed))
    }
}

@Suite("CustomSmartFolder")
struct CustomSmartFolderTests {
    @Test func smartFolderIDRoundTrips() {
        let id = UUID()
        let smartFolderID = CustomSmartFolder.smartFolderID(for: id)
        #expect(CustomSmartFolder.customFolderID(from: smartFolderID) == id)
    }

    @Test func customFolderIDRejectsForeignIDs() {
        #expect(CustomSmartFolder.customFolderID(from: "builtin-recent") == nil)
        #expect(CustomSmartFolder.customFolderID(from: "custom-not-a-uuid") == nil)
    }
}

@Suite("ReadingListItem")
struct ReadingListItemTests {
    @Test func hostnameIsLowercasedAndFallsBack() {
        #expect(makeItem(urlString: "https://EXAMPLE.com/A").hostname == "example.com")
        #expect(makeItem(urlString: "file:///tmp/local.pdf").hostname == "(no host)")
    }

    @Test func idDisambiguatesSameURLByDateAdded() {
        let a = makeItem(dateAdded: Date(timeIntervalSince1970: 1))
        let b = makeItem(dateAdded: Date(timeIntervalSince1970: 2))
        #expect(a.id != b.id)
    }
}

import Foundation

enum ReadingListLoadError: LocalizedError {
    case bookmarksFileMissing(URL)
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case let .bookmarksFileMissing(url):
            return "Safari bookmarks file was not found at \(url.path)."
        case .unsupportedFormat:
            return "Safari bookmarks file format is unsupported."
        }
    }
}

enum ReadingListWriteError: LocalizedError {
    case itemNotFound(URL)

    var errorDescription: String? {
        switch self {
        case let .itemNotFound(url):
            return "Could not find reading list item for \(url.absoluteString)."
        }
    }
}

struct SafariReadingListService: Sendable {
    let bookmarksPlistURL: URL

    init(
        bookmarksPlistURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Safari/Bookmarks.plist", directoryHint: .notDirectory)
    ) {
        self.bookmarksPlistURL = bookmarksPlistURL
    }

    func fetchItems() throws -> [ReadingListItem] {
        guard FileManager.default.fileExists(atPath: bookmarksPlistURL.path) else {
            throw ReadingListLoadError.bookmarksFileMissing(bookmarksPlistURL)
        }

        let data = try Data(contentsOf: bookmarksPlistURL)
        var format = PropertyListSerialization.PropertyListFormat.binary
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)

        guard let root = plist as? [String: Any] else {
            throw ReadingListLoadError.unsupportedFormat
        }

        guard let readingListNode = findReadingListNode(in: root) else {
            return []
        }

        let children = readingListNode["Children"] as? [[String: Any]] ?? []
        let parsed = children.compactMap(parseItem)
        let sorted = parsed.sorted(by: compareItemsByDate)
        return deduplicateByURL(sorted)
    }

    func markItemAsRead(url: URL, dateAdded: Date?, viewedDate: Date = Date()) throws {
        guard FileManager.default.fileExists(atPath: bookmarksPlistURL.path) else {
            throw ReadingListLoadError.bookmarksFileMissing(bookmarksPlistURL)
        }

        let data = try Data(contentsOf: bookmarksPlistURL)
        var format = PropertyListSerialization.PropertyListFormat.binary
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)

        guard var root = plist as? [String: Any] else {
            throw ReadingListLoadError.unsupportedFormat
        }

        let didUpdate = setItemViewedDate(
            in: &root,
            targetURLString: url.absoluteString,
            targetDateAdded: dateAdded,
            viewedDate: viewedDate
        )
        guard didUpdate else {
            throw ReadingListWriteError.itemNotFound(url)
        }

        let updatedData = try PropertyListSerialization.data(
            fromPropertyList: root,
            format: format,
            options: 0
        )
        try updatedData.write(to: bookmarksPlistURL, options: .atomic)
    }

    func markItemAsUnread(url: URL, dateAdded: Date?) throws {
        guard FileManager.default.fileExists(atPath: bookmarksPlistURL.path) else {
            throw ReadingListLoadError.bookmarksFileMissing(bookmarksPlistURL)
        }

        let data = try Data(contentsOf: bookmarksPlistURL)
        var format = PropertyListSerialization.PropertyListFormat.binary
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)

        guard var root = plist as? [String: Any] else {
            throw ReadingListLoadError.unsupportedFormat
        }

        let didUpdate = setItemViewedDate(
            in: &root,
            targetURLString: url.absoluteString,
            targetDateAdded: dateAdded,
            viewedDate: nil
        )
        guard didUpdate else {
            throw ReadingListWriteError.itemNotFound(url)
        }

        let updatedData = try PropertyListSerialization.data(
            fromPropertyList: root,
            format: format,
            options: 0
        )
        try updatedData.write(to: bookmarksPlistURL, options: .atomic)
    }

    private func findReadingListNode(in node: [String: Any]) -> [String: Any]? {
        if let title = node["Title"] as? String, title == "com.apple.ReadingList" {
            return node
        }

        if let children = node["Children"] as? [[String: Any]] {
            for child in children {
                if let match = findReadingListNode(in: child) {
                    return match
                }
            }
        }

        return nil
    }

    private func parseItem(_ payload: [String: Any]) -> ReadingListItem? {
        guard
            let urlString = payload["URLString"] as? String,
            let url = URL(string: urlString)
        else {
            return nil
        }

        let uriDictionary = payload["URIDictionary"] as? [String: Any]
        let readingListMetadata = payload["ReadingList"] as? [String: Any]

        let titleCandidate = (uriDictionary?["title"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let title = (titleCandidate?.isEmpty == false ? titleCandidate : nil) ?? url.absoluteString

        let previewCandidate = (readingListMetadata?["PreviewText"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let preview = (previewCandidate?.isEmpty == false) ? previewCandidate : nil

        let dateAdded = parseDate(readingListMetadata?["DateAdded"]) ?? parseDate(payload["DateAdded"])
        let dateLastViewed = parseDate(readingListMetadata?["DateLastViewed"])

        return ReadingListItem(
            title: title,
            url: url,
            previewText: preview,
            dateAdded: dateAdded,
            dateLastViewed: dateLastViewed
        )
    }

    private func parseDate(_ raw: Any?) -> Date? {
        switch raw {
        case let date as Date:
            return date
        case let value as NSNumber:
            return Date(timeIntervalSinceReferenceDate: value.doubleValue)
        case let value as String:
            return parseDateString(value)
        default:
            return nil
        }
    }

    private func parseDateString(_ text: String) -> Date? {
        let iso8601 = ISO8601DateFormatter()
        if let date = iso8601.date(from: text) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter.date(from: text)
    }

    private func compareItemsByDate(_ lhs: ReadingListItem, _ rhs: ReadingListItem) -> Bool {
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

    private func deduplicateByURL(_ items: [ReadingListItem]) -> [ReadingListItem] {
        var seen: Set<String> = []
        var unique: [ReadingListItem] = []
        unique.reserveCapacity(items.count)

        for item in items {
            if seen.insert(item.url.absoluteString).inserted {
                unique.append(item)
            }
        }

        return unique
    }

    private func setItemViewedDate(
        in node: inout [String: Any],
        targetURLString: String,
        targetDateAdded: Date?,
        viewedDate: Date?
    ) -> Bool {
        if let title = node["Title"] as? String, title == "com.apple.ReadingList" {
            guard var children = node["Children"] as? [[String: Any]] else {
                return false
            }

            for index in children.indices {
                guard let urlString = children[index]["URLString"] as? String,
                      urlString == targetURLString
                else {
                    continue
                }

                guard matchesDateAdded(children[index], targetDateAdded: targetDateAdded) else {
                    continue
                }

                var readingList = (children[index]["ReadingList"] as? [String: Any]) ?? [:]
                if let viewedDate {
                    readingList["DateLastViewed"] = viewedDate
                } else {
                    readingList.removeValue(forKey: "DateLastViewed")
                }
                children[index]["ReadingList"] = readingList
                node["Children"] = children
                return true
            }

            return false
        }

        guard var children = node["Children"] as? [[String: Any]] else {
            return false
        }

        for index in children.indices {
            var child = children[index]
            if setItemViewedDate(
                in: &child,
                targetURLString: targetURLString,
                targetDateAdded: targetDateAdded,
                viewedDate: viewedDate
            ) {
                children[index] = child
                node["Children"] = children
                return true
            }
        }

        return false
    }

    private func matchesDateAdded(_ payload: [String: Any], targetDateAdded: Date?) -> Bool {
        guard let targetDateAdded else {
            return true
        }

        let readingListMetadata = payload["ReadingList"] as? [String: Any]
        let dateAdded = parseDate(readingListMetadata?["DateAdded"]) ?? parseDate(payload["DateAdded"])
        guard let dateAdded else {
            return false
        }

        return abs(dateAdded.timeIntervalSince(targetDateAdded)) < 1
    }
}

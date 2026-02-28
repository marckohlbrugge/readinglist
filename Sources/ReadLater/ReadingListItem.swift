import Foundation

struct ReadingListItem: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let url: URL
    let hostname: String
    let previewText: String?
    let dateAdded: Date?
    let dateLastViewed: Date?

    var isViewed: Bool {
        dateLastViewed != nil
    }

    init(
        title: String,
        url: URL,
        previewText: String?,
        dateAdded: Date?,
        dateLastViewed: Date?
    ) {
        self.title = title
        self.url = url
        hostname = Self.normalizedHost(from: url)
        self.previewText = previewText
        self.dateAdded = dateAdded
        self.dateLastViewed = dateLastViewed

        let dateStamp = dateAdded?.timeIntervalSince1970 ?? 0
        id = "\(url.absoluteString)|\(dateStamp)"
    }

    private static func normalizedHost(from url: URL) -> String {
        guard let host = url.host?.lowercased(), !host.isEmpty else {
            return "(no host)"
        }
        return host
    }
}

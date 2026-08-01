import Foundation

enum ReadingStatusFilter: String, CaseIterable, Identifiable, Sendable {
    case unread
    case all
    case viewed

    var id: Self { self }

    var title: String {
        switch self {
        case .unread:
            return "Unread"
        case .all:
            return "All"
        case .viewed:
            return "Viewed"
        }
    }

    var allListTitle: String {
        switch self {
        case .unread:
            return "All Unread"
        case .all:
            return "All Links"
        case .viewed:
            return "All Viewed"
        }
    }

    var subtitleNoun: String {
        switch self {
        case .unread:
            return "unread"
        case .all:
            return "links"
        case .viewed:
            return "viewed"
        }
    }

    var systemImage: String {
        switch self {
        case .unread:
            return "circle"
        case .all:
            return "circle.grid.2x2"
        case .viewed:
            return "checkmark.circle"
        }
    }

    func includes(_ item: ReadingListItem) -> Bool {
        switch self {
        case .unread:
            return !item.isViewed
        case .all:
            return true
        case .viewed:
            return item.isViewed
        }
    }
}

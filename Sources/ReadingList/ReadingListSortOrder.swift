import Foundation

enum ReadingListSortOrder: String, CaseIterable, Identifiable, Sendable {
    case newestFirst
    case oldestFirst

    var id: Self { self }

    var title: String {
        switch self {
        case .newestFirst:
            return "Newest First"
        case .oldestFirst:
            return "Oldest First"
        }
    }

    var systemImage: String {
        switch self {
        case .newestFirst:
            return "arrow.down"
        case .oldestFirst:
            return "arrow.up"
        }
    }
}

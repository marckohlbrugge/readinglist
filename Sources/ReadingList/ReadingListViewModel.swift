import Combine
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

struct DomainFolder: Identifiable, Sendable {
    let hostname: String
    let count: Int

    var id: String { hostname }
}

@MainActor
final class ReadingListViewModel: ObservableObject {
    @Published var allItems: [ReadingListItem] = []
    @Published var isLoading = false
    @Published var loadError: String?
    @Published private(set) var updatingReadStateItemIDs: Set<ReadingListItem.ID> = []

    private let service: SafariReadingListService
    private let smartFolderStore: SmartFolderStore
    private let demoItems: [ReadingListItem]?

    init(service: SafariReadingListService, smartFolderStore: SmartFolderStore) {
        self.service = service
        self.smartFolderStore = smartFolderStore
        demoItems = nil
    }

    init(smartFolderStore: SmartFolderStore, demoItems: [ReadingListItem]) {
        let dummyURL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Safari/Bookmarks.plist", directoryHint: .notDirectory)
        service = SafariReadingListService(bookmarksPlistURL: dummyURL)
        self.smartFolderStore = smartFolderStore
        self.demoItems = demoItems
    }

    var isUsingDemoData: Bool {
        demoItems != nil
    }

    var availableSmartFolders: [SmartFolder] {
        smartFolderStore.allFolders
    }

    var builtInSmartFolders: [SmartFolder] {
        smartFolderStore.builtInFolders
    }

    var customSmartFolders: [SmartFolder] {
        smartFolderStore.customSmartFolders
    }

    func displayedItems(
        for selection: FolderSelection,
        query: String,
        statusFilter: ReadingStatusFilter,
        sortOrder: ReadingListSortOrder = .newestFirst
    ) -> [ReadingListItem] {
        let base = items(for: selection).filter(statusFilter.includes)
        let searchText = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let filtered: [ReadingListItem]
        if searchText.isEmpty {
            filtered = base
        } else {
            filtered = base.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                    item.url.absoluteString.localizedCaseInsensitiveContains(searchText) ||
                    item.hostname.localizedCaseInsensitiveContains(searchText) ||
                    (item.previewText?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return sortedItems(filtered, by: sortOrder)
    }

    private func sortedItems(
        _ items: [ReadingListItem],
        by sortOrder: ReadingListSortOrder
    ) -> [ReadingListItem] {
        items.sorted { lhs, rhs in
            switch (lhs.dateAdded, rhs.dateAdded) {
            case let (leftDate?, rightDate?):
                switch sortOrder {
                case .newestFirst:
                    return leftDate > rightDate
                case .oldestFirst:
                    return leftDate < rightDate
                }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }

    func domainFolders(minimumCount: Int, statusFilter: ReadingStatusFilter) -> [DomainFolder] {
        let source = allItems.filter(statusFilter.includes)
        let grouped = Dictionary(grouping: source, by: \.hostname)
        return grouped
            .map { DomainFolder(hostname: $0.key, count: $0.value.count) }
            .filter { $0.count >= minimumCount }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }
                return lhs.hostname.localizedCaseInsensitiveCompare(rhs.hostname) == .orderedAscending
            }
    }

    func title(for selection: FolderSelection) -> String {
        selection.title(using: availableSmartFolders)
    }

    func allCount(statusFilter: ReadingStatusFilter) -> Int {
        allItems.lazy.filter(statusFilter.includes).count
    }

    func smartFolderCount(_ folder: SmartFolder, statusFilter: ReadingStatusFilter) -> Int {
        allItems.lazy.filter {
            folder.matches(item: $0) && statusFilter.includes($0)
        }.count
    }

    func reload() {
        if let demoItems {
            isLoading = false
            loadError = nil
            allItems = demoItems
            return
        }

        isLoading = true
        loadError = nil

        let reader = service

        Task {
            do {
                let items = try await Task.detached(priority: .userInitiated) {
                    try reader.fetchItems()
                }.value

                isLoading = false
                allItems = items
            } catch {
                isLoading = false
                loadError = error.localizedDescription
                allItems = []
            }
        }
    }

    func markAsRead(_ item: ReadingListItem) {
        guard !item.isViewed else {
            return
        }
        updateReadState(for: item, viewedDate: Date())
    }

    func markAsUnread(_ item: ReadingListItem) {
        guard item.isViewed else {
            return
        }
        updateReadState(for: item, viewedDate: nil)
    }

    private func updateReadState(for item: ReadingListItem, viewedDate: Date?) {
        guard !updatingReadStateItemIDs.contains(item.id) else {
            return
        }

        updatingReadStateItemIDs.insert(item.id)

        if isUsingDemoData {
            defer {
                updatingReadStateItemIDs.remove(item.id)
            }
            updateItemReadStateLocally(itemID: item.id, viewedDate: viewedDate)
            return
        }

        let reader = service
        let targetID = item.id
        let targetURL = item.url
        let targetDateAdded = item.dateAdded

        Task {
            defer {
                updatingReadStateItemIDs.remove(targetID)
            }

            do {
                try await Task.detached(priority: .userInitiated) {
                    if let viewedDate {
                        try reader.markItemAsRead(
                            url: targetURL,
                            dateAdded: targetDateAdded,
                            viewedDate: viewedDate
                        )
                    } else {
                        try reader.markItemAsUnread(
                            url: targetURL,
                            dateAdded: targetDateAdded
                        )
                    }
                }.value

                guard allItems.contains(where: { $0.id == targetID }) else {
                    return
                }

                updateItemReadStateLocally(itemID: targetID, viewedDate: viewedDate)
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    private func updateItemReadStateLocally(itemID: ReadingListItem.ID, viewedDate: Date?) {
        guard let index = allItems.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        let existing = allItems[index]
        allItems[index] = ReadingListItem(
            title: existing.title,
            url: existing.url,
            previewText: existing.previewText,
            dateAdded: existing.dateAdded,
            dateLastViewed: viewedDate
        )
    }

    private func items(for selection: FolderSelection) -> [ReadingListItem] {
        switch selection {
        case .all:
            return allItems
        case let .smartFolder(folderID):
            guard let folder = availableSmartFolders.first(where: { $0.id == folderID }) else {
                return []
            }
            return allItems.filter { folder.matches(item: $0) }
        case let .domain(hostname):
            return allItems.filter { $0.hostname == hostname }
        }
    }
}

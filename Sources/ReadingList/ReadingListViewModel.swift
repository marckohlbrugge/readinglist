import Foundation
import Observation

@MainActor
@Observable
final class ReadingListViewModel {
    private(set) var allItems: [ReadingListItem] = []
    private(set) var isLoading = false
    private(set) var updatingReadStateItemIDs: Set<ReadingListItem.ID> = []
    var loadError: String?

    var selectedFolder: FolderSelection? = .all {
        didSet {
            guard selectedFolder != oldValue else { return }
            recomputeSelectionData(resetPagination: true)
        }
    }

    var searchQuery = "" {
        didSet {
            guard searchQuery != oldValue else { return }
            recomputeSelectionData(resetPagination: true)
        }
    }

    var statusFilter: ReadingStatusFilter {
        didSet {
            guard statusFilter != oldValue else { return }
            UserDefaults.standard.set(statusFilter.rawValue, forKey: Self.statusFilterDefaultsKey)
            recomputeAllDerivedData(resetPagination: true)
        }
    }

    var sortOrder: ReadingListSortOrder {
        didSet {
            guard sortOrder != oldValue else { return }
            UserDefaults.standard.set(sortOrder.rawValue, forKey: Self.sortOrderDefaultsKey)
            recomputeSelectionData(resetPagination: true)
        }
    }

    var selectedItemID: ReadingListItem.ID?

    private(set) var filteredItems: [ReadingListItem] = []
    private(set) var frequentDomainFolders: [DomainFolder] = []
    private(set) var allCount = 0
    private(set) var smartFolderCounts: [String: Int] = [:]
    private(set) var selectionItemCount = 0

    private var visibleItemLimit = ReadingListViewModel.itemsPageSize
    private var reloadTask: Task<Void, Never>?
    private var fileMonitor: BookmarksFileMonitor?

    private let service: SafariReadingListService
    private let smartFolderStore: SmartFolderStore
    private let demoItems: [ReadingListItem]?

    static let minimumDomainCount = 10
    private static let itemsPageSize = 250
    private static let statusFilterDefaultsKey = "ReadingList.statusFilter"
    private static let sortOrderDefaultsKey = "ReadingList.sortOrder"

    init(service: SafariReadingListService, smartFolderStore: SmartFolderStore) {
        self.service = service
        self.smartFolderStore = smartFolderStore
        demoItems = nil
        (statusFilter, sortOrder) = Self.restoredFilterAndSort()

        let monitor = BookmarksFileMonitor(url: service.bookmarksPlistURL) { [weak self] in
            self?.reload()
        }
        monitor.start()
        fileMonitor = monitor
    }

    init(smartFolderStore: SmartFolderStore, demoItems: [ReadingListItem]) {
        let dummyURL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Safari/Bookmarks.plist", directoryHint: .notDirectory)
        service = SafariReadingListService(bookmarksPlistURL: dummyURL)
        self.smartFolderStore = smartFolderStore
        self.demoItems = demoItems
        (statusFilter, sortOrder) = Self.restoredFilterAndSort()
    }

    private static func restoredFilterAndSort() -> (ReadingStatusFilter, ReadingListSortOrder) {
        let defaults = UserDefaults.standard
        let filter = defaults.string(forKey: statusFilterDefaultsKey)
            .flatMap(ReadingStatusFilter.init(rawValue:)) ?? .unread
        let sort = defaults.string(forKey: sortOrderDefaultsKey)
            .flatMap(ReadingListSortOrder.init(rawValue:)) ?? .newestFirst
        return (filter, sort)
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

    var activeSelection: FolderSelection {
        selectedFolder ?? .all
    }

    var visibleItems: [ReadingListItem] {
        Array(filteredItems.prefix(visibleItemLimit))
    }

    var selectedItem: ReadingListItem? {
        guard let selectedItemID else {
            return nil
        }
        return filteredItems.first(where: { $0.id == selectedItemID })
    }

    var isPresentingLoadError: Bool {
        get { loadError != nil }
        set {
            if !newValue {
                loadError = nil
            }
        }
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

    func title(for selection: FolderSelection) -> String {
        switch selection {
        case .all:
            return statusFilter.allListTitle
        default:
            return selection.title(using: availableSmartFolders)
        }
    }

    func reload() {
        if let demoItems {
            isLoading = false
            loadError = nil
            allItems = demoItems
            recomputeAllDerivedData(resetPagination: false)
            return
        }

        isLoading = true
        loadError = nil

        reloadTask?.cancel()
        reloadTask = Task {
            do {
                let items = try await service.fetchItems()
                guard !Task.isCancelled else { return }
                allItems = items
                recomputeAllDerivedData(resetPagination: false)
                isLoading = false
            } catch is CancellationError {
                // A newer reload replaced this one.
            } catch {
                guard !Task.isCancelled else { return }
                isLoading = false
                loadError = error.localizedDescription
            }
        }
    }

    func smartFoldersDidChange() {
        validateSelectedFolder()
        recomputeAllDerivedData(resetPagination: true)
    }

    func loadMoreItemsIfNeeded(currentItemID: ReadingListItem.ID) {
        guard
            let lastVisibleID = visibleItems.last?.id,
            currentItemID == lastVisibleID,
            visibleItemLimit < filteredItems.count
        else {
            return
        }

        visibleItemLimit = min(visibleItemLimit + Self.itemsPageSize, filteredItems.count)
    }

    func markAsRead(_ item: ReadingListItem) {
        guard !item.isViewed else {
            return
        }
        setReadState(of: item, viewedDate: Date())
    }

    func markAsUnread(_ item: ReadingListItem) {
        guard item.isViewed else {
            return
        }
        setReadState(of: item, viewedDate: nil)
    }

    func toggleReadState(of item: ReadingListItem) {
        if item.isViewed {
            markAsUnread(item)
        } else {
            markAsRead(item)
        }
    }

    private func setReadState(of item: ReadingListItem, viewedDate: Date?) {
        guard !updatingReadStateItemIDs.contains(item.id) else {
            return
        }

        updatingReadStateItemIDs.insert(item.id)

        if isUsingDemoData {
            defer {
                updatingReadStateItemIDs.remove(item.id)
            }
            applyLocalReadState(itemID: item.id, viewedDate: viewedDate)
            return
        }

        Task {
            defer {
                updatingReadStateItemIDs.remove(item.id)
            }

            do {
                try await service.setReadState(
                    url: item.url,
                    dateAdded: item.dateAdded,
                    viewedDate: viewedDate
                )
                applyLocalReadState(itemID: item.id, viewedDate: viewedDate)
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    private func applyLocalReadState(itemID: ReadingListItem.ID, viewedDate: Date?) {
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
        recomputeAllDerivedData(resetPagination: false)
    }

    private func validateSelectedFolder() {
        guard case let .smartFolder(id) = selectedFolder else {
            return
        }

        let exists = availableSmartFolders.contains(where: { $0.id == id })
        if !exists {
            selectedFolder = .all
        }
    }

    private func recomputeAllDerivedData(resetPagination: Bool) {
        let statusFilter = statusFilter
        allCount = allItems.lazy.filter(statusFilter.includes).count

        let folders = availableSmartFolders
        smartFolderCounts = Dictionary(uniqueKeysWithValues: folders.map { folder in
            let count = allItems.lazy.filter {
                folder.matches(item: $0) && statusFilter.includes($0)
            }.count
            return (folder.id, count)
        })

        let source = allItems.filter(statusFilter.includes)
        let grouped = Dictionary(grouping: source, by: \.hostname)
        frequentDomainFolders = grouped
            .map { DomainFolder(hostname: $0.key, count: $0.value.count) }
            .filter { $0.count >= Self.minimumDomainCount }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }
                return lhs.hostname.localizedCaseInsensitiveCompare(rhs.hostname) == .orderedAscending
            }

        recomputeSelectionData(resetPagination: resetPagination)
    }

    private func recomputeSelectionData(resetPagination: Bool) {
        selectionItemCount = displayedItems(
            for: activeSelection,
            query: "",
            statusFilter: statusFilter,
            sortOrder: sortOrder
        ).count

        filteredItems = displayedItems(
            for: activeSelection,
            query: searchQuery,
            statusFilter: statusFilter,
            sortOrder: sortOrder
        )

        if resetPagination {
            visibleItemLimit = min(Self.itemsPageSize, filteredItems.count)
        } else {
            visibleItemLimit = min(max(visibleItemLimit, Self.itemsPageSize), filteredItems.count)
        }

        if let selectedItemID,
           !filteredItems.contains(where: { $0.id == selectedItemID })
        {
            self.selectedItemID = nil
        }
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

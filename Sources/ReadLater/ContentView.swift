import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ReadingListViewModel
    @ObservedObject var smartFolderStore: SmartFolderStore
    @Environment(\.openURL) private var openURL
    @State private var selectedFolder: FolderSelection? = .all
    @State private var query = ""
    @State private var hideViewed = true
    @State private var isShowingSmartFolderManager = false
    @State private var filteredItems: [ReadingListItem] = []
    @State private var frequentDomainFolders: [DomainFolder] = []
    @State private var allCountForStatus = 0
    @State private var smartFolderCounts: [String: Int] = [:]
    @State private var unreadCountForSelection = 0
    @State private var visibleItemLimit = 250
    @State private var selectedItemID: ReadingListItem.ID?
    @State private var smartListManagerInitialSelection: UUID?
    @State private var pendingOpenURLs: [URL] = []
    @State private var pendingOpenLinksSourceName = ""
    @State private var isShowingOpenLinksConfirmation = false
    private let minimumDomainCount = 10
    private let itemsPageSize = 250
    private let openLinksConfirmationThreshold = 15

    var body: some View {
        NavigationSplitView {
            sidebarView
        } content: {
            detailView
        } detail: {
            previewView
        }
        .sheet(isPresented: $isShowingSmartFolderManager, onDismiss: {
            smartListManagerInitialSelection = nil
            validateSelectedFolder()
            recomputeAllDerivedData(resetVisibleLimit: true)
        }) {
            SmartFolderManagerView(
                store: smartFolderStore,
                selectedFolder: $selectedFolder,
                initialSelectedCustomFolderID: smartListManagerInitialSelection
            )
        }
        .onAppear {
            recomputeAllDerivedData(resetVisibleLimit: true)
        }
        .onChange(of: viewModel.allItems) { _ in
            recomputeAllDerivedData(resetVisibleLimit: true)
        }
        .onChange(of: smartFolderStore.customFolders) { _ in
            validateSelectedFolder()
            recomputeAllDerivedData(resetVisibleLimit: true)
        }
        .onChange(of: selectedFolder) { _ in
            recomputeSelectionDerivedData(resetVisibleLimit: true)
        }
        .onChange(of: query) { _ in
            recomputeSelectionDerivedData(resetVisibleLimit: true)
        }
        .onChange(of: hideViewed) { _ in
            recomputeSelectionDerivedData(resetVisibleLimit: true)
        }
        .alert(
            "Reading List Error",
            isPresented: showErrorBinding
        ) {
            Button("OK", role: .cancel) {
                viewModel.loadError = nil
            }
        } message: {
            Text(viewModel.loadError ?? "Unknown error")
        }
        .confirmationDialog(
            "Open \(pendingOpenURLs.count) links in Safari?",
            isPresented: $isShowingOpenLinksConfirmation,
            titleVisibility: .visible
        ) {
            Button("Open \(pendingOpenURLs.count) Links") {
                openURLsInSafari(pendingOpenURLs)
                clearPendingOpenLinksAction()
            }
            Button("Cancel", role: .cancel) {
                clearPendingOpenLinksAction()
            }
        } message: {
            Text("This can open many tabs for \(pendingOpenLinksSourceName).")
        }
    }

    private var sidebarView: some View {
        List(selection: $selectedFolder) {
            Section("Smart Lists") {
                NavigationLink(value: FolderSelection.all) {
                    sidebarLabel(
                        title: "All Unread",
                        icon: "circle.fill",
                        count: allCountForStatus,
                        iconTint: sidebarIconTint(for: .all)
                    )
                }

                ForEach(viewModel.builtInSmartFolders) { folder in
                    NavigationLink(value: FolderSelection.smartFolder(folder.id)) {
                        sidebarLabel(
                            title: folder.displayName,
                            icon: folder.systemImage,
                            count: smartFolderCounts[folder.id, default: 0],
                            iconTint: sidebarIconTint(for: .smartFolder(folder.id))
                        )
                    }
                }

                ForEach(viewModel.customSmartFolders) { folder in
                    NavigationLink(value: FolderSelection.smartFolder(folder.id)) {
                        sidebarLabel(
                            title: folder.displayName,
                            icon: folder.systemImage,
                            count: smartFolderCounts[folder.id, default: 0],
                            iconTint: sidebarIconTint(for: .smartFolder(folder.id))
                        )
                    }
                    .contextMenu {
                        if let customFolderID = CustomSmartFolder.customFolderID(from: folder.id) {
                            Button {
                                openSmartListManager(editingCustomFolderID: customFolderID)
                            } label: {
                                Label("Edit Smart List", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                deleteCustomSmartList(id: customFolderID)
                            } label: {
                                Label("Delete Smart List", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section("Websites") {
                if frequentDomainFolders.isEmpty {
                    Text("No domains have \(minimumDomainCount)+ links yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(frequentDomainFolders) { folder in
                        NavigationLink(value: FolderSelection.domain(folder.hostname)) {
                            domainSidebarLabel(
                                hostname: folder.hostname,
                                count: folder.count
                            )
                        }
                        .contextMenu {
                            Button {
                                openAllLinksForDomain(folder.hostname)
                            } label: {
                                Label("Open All in Safari", systemImage: "safari")
                            }

                            Button {
                                copyLinksForDomain(folder.hostname)
                            } label: {
                                Label("Copy Links", systemImage: "doc.on.doc")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 220, ideal: 270)
    }

    private var detailView: some View {
        Group {
            if filteredItems.isEmpty {
                emptyStateView
            } else {
                List(selection: $selectedItemID) {
                    ForEach(visibleItems) { item in
                        ReadingListRow(item: item)
                            .tag(item.id as ReadingListItem.ID?)
                            .listRowSeparator(.hidden)
                            .contextMenu {
                                itemContextMenu(for: item)
                            }
                            .onAppear {
                                loadMoreItemsIfNeeded(currentItemID: item.id)
                            }
                    }
                }
                .listStyle(.plain)
                .onChange(of: selectedItemID) { id in
                    guard let id else {
                        return
                    }
                    loadMoreItemsIfNeeded(currentItemID: id)
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 360, ideal: 440)
        .navigationTitle(currentSelectionTitle)
        .navigationSubtitle(currentSelectionSubtitle)
        .toolbar { detailToolbarContent }
        .searchable(
            text: $query,
            placement: .toolbar,
            prompt: "Search links"
        )
    }

    @ToolbarContentBuilder
    private var detailToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                viewModel.reload()
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
            .help("Reload")

            Button {
                hideViewed.toggle()
            } label: {
                Label(
                    hideViewed ? "Hide Viewed On" : "Hide Viewed Off",
                    systemImage: hideViewed
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle"
                )
            }
            .help(hideViewed ? "Hide viewed items" : "Show viewed items")

            Button {
                openSmartListManager()
            } label: {
                Label("Manage Smart Lists", systemImage: "slider.horizontal.3")
            }
        }
    }

    private var previewView: some View {
        Group {
            if let selectedItem {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Text(selectedItem.title)
                            .font(.headline)
                            .lineLimit(1)

                        Spacer()

                        let isUpdatingReadState = viewModel.updatingReadStateItemIDs.contains(selectedItem.id)

                        Button {
                            if selectedItem.isViewed {
                                viewModel.markAsUnread(selectedItem)
                            } else {
                                viewModel.markAsRead(selectedItem)
                            }
                        } label: {
                            if isUpdatingReadState {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label(
                                    selectedItem.isViewed ? "Mark as Unread" : "Mark as Read",
                                    systemImage: selectedItem.isViewed
                                        ? "arrow.uturn.backward.circle"
                                        : "checkmark.circle"
                                )
                                .labelStyle(.iconOnly)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .disabled(isUpdatingReadState)
                        .accessibilityLabel(selectedItem.isViewed ? "Mark as Unread" : "Mark as Read")
                        .help(selectedItem.isViewed ? "Mark as unread" : "Mark as read")

                        Button {
                            openURL(selectedItem.url)
                        } label: {
                            Label("Open in Safari", systemImage: "safari")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .help("Open in Safari")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                    Divider()

                    WebPreviewView(url: selectedItem.url)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.and.text.magnifyingglass")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                    Text("Select a link to preview")
                        .font(.headline)
                    Text("Click an item in the middle list to open it here.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationSplitViewColumnWidth(min: 420, ideal: 620)
    }

    private var currentSelectionTitle: String {
        switch activeSelection {
        case .all:
            return "All Unread"
        default:
            return viewModel.title(for: activeSelection)
        }
    }

    private var currentSelectionSubtitle: String {
        if viewModel.isUsingDemoData {
            return "\(unreadCountForSelection) unread • Demo Data"
        }
        return "\(unreadCountForSelection) unread"
    }

    private var showErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.loadError != nil },
            set: { visible in
                if !visible {
                    viewModel.loadError = nil
                }
            }
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)

            Text("No links found")
                .font(.headline)

            Text("Try another list, status filter, or search term.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openSmartListManager(editingCustomFolderID: UUID? = nil) {
        smartListManagerInitialSelection = editingCustomFolderID
        if let editingCustomFolderID {
            selectedFolder = .smartFolder(CustomSmartFolder.smartFolderID(for: editingCustomFolderID))
        }
        isShowingSmartFolderManager = true
    }

    private func deleteCustomSmartList(id: UUID) {
        let smartFolderID = CustomSmartFolder.smartFolderID(for: id)
        smartFolderStore.removeFolder(id: id)

        if selectedFolder == .smartFolder(smartFolderID) {
            selectedFolder = .all
        }
    }

    @ViewBuilder
    private func itemContextMenu(for item: ReadingListItem) -> some View {
        let isUpdatingReadState = viewModel.updatingReadStateItemIDs.contains(item.id)

        Button {
            openURL(item.url)
        } label: {
            Label("Open in Safari", systemImage: "safari")
        }

        Button {
            copyToClipboard(item.url.absoluteString)
        } label: {
            Label("Copy Link", systemImage: "doc.on.doc")
        }

        Divider()

        Button {
            if item.isViewed {
                viewModel.markAsUnread(item)
            } else {
                viewModel.markAsRead(item)
            }
        } label: {
            Label(
                item.isViewed ? "Mark as Unread" : "Mark as Read",
                systemImage: item.isViewed ? "arrow.uturn.backward.circle" : "checkmark.circle"
            )
        }
        .disabled(isUpdatingReadState)
    }

    private func openAllLinksForDomain(_ hostname: String) {
        let urls = domainItemsForContextActions(hostname).map(\.url)
        let sourceName = hostname.hasPrefix("www.") ? String(hostname.dropFirst(4)) : hostname
        requestOpenURLsInSafari(urls, sourceName: sourceName)
    }

    private func copyLinksForDomain(_ hostname: String) {
        let urls = uniqueOrderedURLs(domainItemsForContextActions(hostname).map(\.url))
        guard !urls.isEmpty else {
            return
        }

        let text = urls.map(\.absoluteString).joined(separator: "\n")
        copyToClipboard(text)
    }

    private func domainItemsForContextActions(_ hostname: String) -> [ReadingListItem] {
        viewModel.displayedItems(
            for: .domain(hostname),
            query: "",
            statusFilter: activeStatusFilter
        )
    }

    private func requestOpenURLsInSafari(_ urls: [URL], sourceName: String) {
        let uniqueURLs = uniqueOrderedURLs(urls)
        guard !uniqueURLs.isEmpty else {
            return
        }

        if uniqueURLs.count >= openLinksConfirmationThreshold {
            pendingOpenURLs = uniqueURLs
            pendingOpenLinksSourceName = sourceName
            isShowingOpenLinksConfirmation = true
            return
        }

        openURLsInSafari(uniqueURLs)
    }

    private func openURLsInSafari(_ urls: [URL]) {
        for url in urls {
            openURL(url)
        }
    }

    private func clearPendingOpenLinksAction() {
        pendingOpenURLs = []
        pendingOpenLinksSourceName = ""
    }

    private func uniqueOrderedURLs(_ urls: [URL]) -> [URL] {
        var seen: Set<String> = []
        var result: [URL] = []
        result.reserveCapacity(urls.count)

        for url in urls {
            if seen.insert(url.absoluteString).inserted {
                result.append(url)
            }
        }

        return result
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func sidebarLabel(
        title: String,
        icon: String,
        count: Int,
        iconTint: Color
    ) -> some View {
        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconTint)

            Text(title)
                .font(.body)
                .lineLimit(1)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Text("\(count)")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }

    private func domainSidebarLabel(hostname: String, count: Int) -> some View {
        let displayHostname = hostname.hasPrefix("www.")
            ? String(hostname.dropFirst(4))
            : hostname

        return HStack(spacing: 8) {
            FaviconImage(hostname: hostname, size: 14)
            Text(displayHostname)
                .font(.body)
                .lineLimit(1)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Text("\(count)")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }

    private func sidebarIconTint(for selection: FolderSelection) -> Color {
        switch selection {
        case .all:
            return .accentColor
        case let .smartFolder(id):
            guard let folder = viewModel.availableSmartFolders.first(where: { $0.id == id }) else {
                return .blue
            }
            switch folder.systemImage {
            case "clock.fill":
                return .orange
            case "play.rectangle.fill":
                return .red
            case "doc.fill":
                return .indigo
            default:
                return .blue
            }
        case .domain:
            return .gray
        }
    }

    private var activeSelection: FolderSelection {
        selectedFolder ?? .all
    }

    private var activeStatusFilter: ReadingStatusFilter {
        hideViewed ? .unread : .all
    }

    private var sidebarStatusFilter: ReadingStatusFilter {
        .unread
    }

    private var visibleItems: [ReadingListItem] {
        Array(filteredItems.prefix(visibleItemLimit))
    }

    private var selectedItem: ReadingListItem? {
        guard let selectedItemID else {
            return nil
        }
        return filteredItems.first(where: { $0.id == selectedItemID })
    }

    private func validateSelectedFolder() {
        guard case let .smartFolder(id) = selectedFolder else {
            return
        }

        let exists = viewModel.availableSmartFolders.contains(where: { $0.id == id })
        if !exists {
            selectedFolder = .all
        }
    }

    private func loadMoreItemsIfNeeded(currentItemID: String) {
        guard
            let lastVisibleID = visibleItems.last?.id,
            currentItemID == lastVisibleID,
            visibleItemLimit < filteredItems.count
        else {
            return
        }

        visibleItemLimit = min(visibleItemLimit + itemsPageSize, filteredItems.count)
    }

    private func recomputeAllDerivedData(resetVisibleLimit: Bool) {
        recomputeSidebarDerivedData()
        recomputeSelectionDerivedData(resetVisibleLimit: resetVisibleLimit)
    }

    private func recomputeSidebarDerivedData() {
        allCountForStatus = viewModel.allCount(statusFilter: sidebarStatusFilter)
        let folders = viewModel.availableSmartFolders
        smartFolderCounts = Dictionary(uniqueKeysWithValues: folders.map { folder in
            (folder.id, viewModel.smartFolderCount(folder, statusFilter: sidebarStatusFilter))
        })

        frequentDomainFolders = viewModel.domainFolders(
            minimumCount: minimumDomainCount,
            statusFilter: sidebarStatusFilter
        )
    }

    private func recomputeSelectionDerivedData(resetVisibleLimit: Bool) {
        unreadCountForSelection = viewModel.displayedItems(
            for: activeSelection,
            query: "",
            statusFilter: .unread
        ).count

        filteredItems = viewModel.displayedItems(
            for: activeSelection,
            query: query,
            statusFilter: activeStatusFilter
        )

        if resetVisibleLimit {
            visibleItemLimit = min(itemsPageSize, filteredItems.count)
        } else {
            visibleItemLimit = min(max(visibleItemLimit, itemsPageSize), filteredItems.count)
        }

        if let selectedItemID,
           !filteredItems.contains(where: { $0.id == selectedItemID })
        {
            self.selectedItemID = nil
        }
    }
}

private struct ReadingListRow: View {
    let item: ReadingListItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if !item.isViewed {
                UnreadDotBadge()
                    .padding(.top, 5)
            } else {
                Color.clear
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)
            }

            FaviconImage(hostname: item.hostname, size: 36)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(summaryText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                HStack(spacing: 8) {
                    Text(displayHostname)
                    Spacer(minLength: 8)
                    if let dateAdded = item.dateAdded {
                        Text(dateAdded.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .frame(minHeight: 96, alignment: .topLeading)
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    private var summaryText: String {
        if let preview = item.previewText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !preview.isEmpty
        {
            return preview
        }
        return item.url.absoluteString
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
    }

    private var displayHostname: String {
        item.hostname.hasPrefix("www.")
            ? String(item.hostname.dropFirst(4))
            : item.hostname
    }
}

private struct UnreadDotBadge: View {
    var body: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 8, height: 8)
            .accessibilityLabel("Unread")
    }
}

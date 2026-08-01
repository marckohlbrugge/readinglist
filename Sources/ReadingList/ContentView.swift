import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var viewModel: ReadingListViewModel
    var smartFolderStore: SmartFolderStore
    @Environment(\.openURL) private var openURL
    @State private var isShowingSmartFolderManager = false
    @State private var smartListManagerInitialSelection: UUID?
    @State private var pendingOpenURLs: [URL] = []
    @State private var pendingOpenLinksSourceName = ""
    @State private var isShowingOpenLinksConfirmation = false
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
            viewModel.smartFoldersDidChange()
        }) {
            SmartFolderManagerView(
                store: smartFolderStore,
                selectedFolder: $viewModel.selectedFolder,
                initialSelectedCustomFolderID: smartListManagerInitialSelection
            )
        }
        .onChange(of: smartFolderStore.customFolders) {
            viewModel.smartFoldersDidChange()
        }
        .alert(
            "Reading List Error",
            isPresented: $viewModel.isPresentingLoadError
        ) {
            Button("OK", role: .cancel) {}
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
        List(selection: $viewModel.selectedFolder) {
            Section("Smart Lists") {
                NavigationLink(value: FolderSelection.all) {
                    sidebarLabel(
                        title: viewModel.statusFilter.allListTitle,
                        icon: "circle.fill",
                        count: viewModel.allCount,
                        iconTint: sidebarIconTint(for: .all)
                    )
                }

                ForEach(viewModel.builtInSmartFolders) { folder in
                    NavigationLink(value: FolderSelection.smartFolder(folder.id)) {
                        sidebarLabel(
                            title: folder.displayName,
                            icon: folder.systemImage,
                            count: viewModel.smartFolderCounts[folder.id, default: 0],
                            iconTint: sidebarIconTint(for: .smartFolder(folder.id))
                        )
                    }
                }

                ForEach(viewModel.customSmartFolders) { folder in
                    NavigationLink(value: FolderSelection.smartFolder(folder.id)) {
                        sidebarLabel(
                            title: folder.displayName,
                            icon: folder.systemImage,
                            count: viewModel.smartFolderCounts[folder.id, default: 0],
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
                if viewModel.frequentDomainFolders.isEmpty {
                    Text("No domains have \(ReadingListViewModel.minimumDomainCount)+ links yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.frequentDomainFolders) { folder in
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
            if viewModel.filteredItems.isEmpty {
                emptyStateView
            } else {
                List(selection: $viewModel.selectedItemID) {
                    ForEach(viewModel.visibleItems) { item in
                        ReadingListRow(item: item)
                            .tag(item.id as ReadingListItem.ID?)
                            .listRowSeparator(.hidden)
                            .contextMenu {
                                itemContextMenu(for: item)
                            }
                            .onAppear {
                                viewModel.loadMoreItemsIfNeeded(currentItemID: item.id)
                            }
                    }
                }
                .listStyle(.plain)
                .onChange(of: viewModel.selectedItemID) { _, id in
                    guard let id else {
                        return
                    }
                    viewModel.loadMoreItemsIfNeeded(currentItemID: id)
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 360, ideal: 500)
        .navigationTitle(viewModel.title(for: viewModel.activeSelection))
        .navigationSubtitle(currentSelectionSubtitle)
        .toolbar { detailToolbarContent }
        .searchable(
            text: $viewModel.searchQuery,
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
            .keyboardShortcut("r", modifiers: .command)
            .help("Reload")

            Picker("Status", selection: $viewModel.statusFilter) {
                ForEach(ReadingStatusFilter.allCases) { filter in
                    Label(filter.title, systemImage: filter.systemImage)
                        .tag(filter)
                }
            }
            .pickerStyle(.menu)
            .help("Filter by read status")

            Picker("Sort", selection: $viewModel.sortOrder) {
                ForEach(ReadingListSortOrder.allCases) { order in
                    Label(order.title, systemImage: order.systemImage)
                        .tag(order)
                }
            }
            .pickerStyle(.menu)
            .help("Sort by date added")

            Button {
                openSmartListManager()
            } label: {
                Label("Manage Smart Lists", systemImage: "slider.horizontal.3")
            }
        }
    }

    private var previewView: some View {
        Group {
            if let selectedItem = viewModel.selectedItem {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Text(selectedItem.title)
                            .font(.headline)
                            .lineLimit(1)

                        Spacer()

                        let isUpdatingReadState = viewModel.updatingReadStateItemIDs.contains(selectedItem.id)

                        Button {
                            viewModel.toggleReadState(of: selectedItem)
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
                        .keyboardShortcut("u", modifiers: [.command, .shift])
                        .accessibilityLabel(selectedItem.isViewed ? "Mark as Unread" : "Mark as Read")
                        .help(selectedItem.isViewed ? "Mark as unread (⇧⌘U)" : "Mark as read (⇧⌘U)")

                        Button {
                            openURL(selectedItem.url)
                        } label: {
                            Label("Open in Safari", systemImage: "safari")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .keyboardShortcut(.return, modifiers: .command)
                        .help("Open in Safari (⌘↩)")
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
        .navigationSplitViewColumnWidth(min: 360, ideal: 520)
    }

    private var currentSelectionSubtitle: String {
        let countLabel = "\(viewModel.selectionItemCount) \(viewModel.statusFilter.subtitleNoun)"
        if viewModel.isUsingDemoData {
            return "\(countLabel) • Demo Data"
        }
        return countLabel
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            if viewModel.isLoading {
                ProgressView()
                Text("Loading your reading list\u{2026}")
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)

                Text("No links found")
                    .font(.headline)

                Text("Try another list, status filter, or search term.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openSmartListManager(editingCustomFolderID: UUID? = nil) {
        smartListManagerInitialSelection = editingCustomFolderID
        if let editingCustomFolderID {
            viewModel.selectedFolder = .smartFolder(CustomSmartFolder.smartFolderID(for: editingCustomFolderID))
        }
        isShowingSmartFolderManager = true
    }

    private func deleteCustomSmartList(id: UUID) {
        let smartFolderID = CustomSmartFolder.smartFolderID(for: id)
        smartFolderStore.removeFolder(id: id)

        if viewModel.selectedFolder == .smartFolder(smartFolderID) {
            viewModel.selectedFolder = .all
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
            viewModel.toggleReadState(of: item)
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
            statusFilter: viewModel.statusFilter,
            sortOrder: viewModel.sortOrder
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
        HStack(spacing: 10) {
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
}

import SwiftUI

struct SmartFolderManagerView: View {
    @ObservedObject var store: SmartFolderStore
    @Binding var selectedFolder: FolderSelection?
    var initialSelectedCustomFolderID: UUID? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var selectedCustomFolderID: UUID?
    @State private var didApplyInitialSelection = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedCustomFolderID) {
                ForEach(store.customFolders) { folder in
                    Label(folder.displayName, systemImage: folder.iconSystemName)
                        .tag(folder.id as UUID?)
                }
                .onDelete(perform: deleteFolders)
            }
            .navigationTitle("Smart Lists")
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        addFolder()
                    } label: {
                        Label("Add Smart List", systemImage: "plus")
                    }

                    Button {
                        restoreDefaultLists()
                    } label: {
                        Label("Restore Default Lists", systemImage: "arrow.counterclockwise")
                    }

                    Button {
                        deleteSelectedFolder()
                    } label: {
                        Label("Delete Smart List", systemImage: "trash")
                    }
                    .disabled(selectedCustomFolderID == nil)
                }
            }
        } detail: {
            if let folderBinding = selectedFolderBinding {
                SmartFolderEditor(folder: folderBinding) {
                    deleteSelectedFolder()
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("Select or create a smart list")
                        .font(.headline)
                    Text("Saved smart lists can match hostnames, keywords, and added-date ranges.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 860, minHeight: 520)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            applyPreferredSelectionIfNeeded()
            ensureSelectionIsValid()
        }
        .onChange(of: store.customFolders.map(\.id)) { _ in
            ensureSelectionIsValid()
        }
    }

    private var selectedFolderBinding: Binding<CustomSmartFolder>? {
        guard let selectedCustomFolderID else {
            return nil
        }
        guard store.customFolders.contains(where: { $0.id == selectedCustomFolderID }) else {
            return nil
        }

        return Binding(
            get: {
                store.customFolders.first(where: { $0.id == selectedCustomFolderID })
                    ?? CustomSmartFolder(id: selectedCustomFolderID)
            },
            set: { updatedFolder in
                guard let index = store.customFolders.firstIndex(where: { $0.id == selectedCustomFolderID }) else {
                    return
                }
                store.customFolders[index] = updatedFolder
            }
        )
    }

    private func addFolder() {
        let newID = store.addFolder()
        selectedCustomFolderID = newID
        selectedFolder = .smartFolder(CustomSmartFolder.smartFolderID(for: newID))
    }

    private func restoreDefaultLists() {
        let previousSelection = selectedCustomFolderID
        store.restoreDefaultFolders()

        if let previousSelection,
           store.customFolders.contains(where: { $0.id == previousSelection })
        {
            selectedCustomFolderID = previousSelection
            selectedFolder = .smartFolder(CustomSmartFolder.smartFolderID(for: previousSelection))
            return
        }

        if let firstID = store.customFolders.first?.id {
            selectedCustomFolderID = firstID
            selectedFolder = .smartFolder(CustomSmartFolder.smartFolderID(for: firstID))
        } else {
            selectedCustomFolderID = nil
            selectedFolder = .all
        }
    }

    private func deleteSelectedFolder() {
        guard let selectedCustomFolderID else {
            return
        }

        store.removeFolder(id: selectedCustomFolderID)

        if case let .smartFolder(id) = selectedFolder,
           id == CustomSmartFolder.smartFolderID(for: selectedCustomFolderID)
        {
            selectedFolder = .all
        }
    }

    private func deleteFolders(at offsets: IndexSet) {
        let ids: [UUID] = offsets.compactMap { offset in
            guard offset >= 0, offset < store.customFolders.count else {
                return nil
            }
            return store.customFolders[offset].id
        }

        for id in ids {
            store.removeFolder(id: id)
            if case let .smartFolder(selectedID) = selectedFolder,
               selectedID == CustomSmartFolder.smartFolderID(for: id)
            {
                selectedFolder = .all
            }
        }
    }

    private func ensureSelectionIsValid() {
        if let selectedCustomFolderID,
           store.customFolders.contains(where: { $0.id == selectedCustomFolderID })
        {
            return
        }
        selectedCustomFolderID = store.customFolders.first?.id
    }

    private func applyPreferredSelectionIfNeeded() {
        guard !didApplyInitialSelection else {
            return
        }
        didApplyInitialSelection = true

        if let initialSelectedCustomFolderID,
           store.customFolders.contains(where: { $0.id == initialSelectedCustomFolderID })
        {
            selectedCustomFolderID = initialSelectedCustomFolderID
            return
        }

        if case let .smartFolder(id) = selectedFolder,
           let customID = CustomSmartFolder.customFolderID(from: id),
           store.customFolders.contains(where: { $0.id == customID })
        {
            selectedCustomFolderID = customID
            return
        }
    }
}

private struct SmartFolderEditor: View {
    @Binding var folder: CustomSmartFolder
    let onDelete: () -> Void

    var body: some View {
        Form {
            Section("List Name") {
                TextField("Name", text: $folder.name)
            }

            Section("Appearance") {
                Picker("Icon", selection: $folder.iconSystemName) {
                    ForEach(Self.availableIcons, id: \.self) { icon in
                        Label(iconTitle(for: icon), systemImage: icon)
                            .tag(icon)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Criteria") {
                Picker("Added Date", selection: $folder.addedDateFilter) {
                    ForEach(AddedDateFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)

                TextField("Hostnames (comma separated)", text: hostnamesBinding)

                TextField("Keywords (comma separated)", text: keywordsBinding)

                Text("A match requires all non-empty criteria: hostname filter, keyword filter, and date filter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Delete Smart List", role: .destructive) {
                    onDelete()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(folder.displayName)
    }

    private var hostnamesBinding: Binding<String> {
        Binding(
            get: { folder.hostnames.joined(separator: ", ") },
            set: { newValue in
                folder.hostnames = parseCSV(newValue).map(normalizeHostname)
            }
        )
    }

    private var keywordsBinding: Binding<String> {
        Binding(
            get: { folder.keywords.joined(separator: ", ") },
            set: { newValue in
                folder.keywords = parseCSV(newValue)
            }
        )
    }

    private func parseCSV(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func normalizeHostname(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ""
        }

        if let parsedURL = URL(string: trimmed), let host = parsedURL.host {
            return host.lowercased()
        }

        if let parsedURL = URL(string: "https://\(trimmed)"), let host = parsedURL.host {
            return host.lowercased()
        }

        return trimmed.lowercased()
    }

    private static let availableIcons: [String] = [
        "line.3.horizontal.decrease.circle.fill",
        "clock.fill",
        "play.rectangle.fill",
        "doc.fill",
        "book.fill",
        "newspaper.fill",
        "bookmark.fill",
        "graduationcap.fill",
        "bolt.fill",
        "tray.full.fill",
        "wrench.and.screwdriver.fill",
        "folder.fill",
    ]

    private func iconTitle(for systemImage: String) -> String {
        switch systemImage {
        case "line.3.horizontal.decrease.circle.fill":
            return "Filter"
        case "clock.fill":
            return "Recent"
        case "play.rectangle.fill":
            return "Video"
        case "doc.fill":
            return "Document"
        case "book.fill":
            return "Book"
        case "newspaper.fill":
            return "News"
        case "bookmark.fill":
            return "Bookmark"
        case "graduationcap.fill":
            return "Learning"
        case "bolt.fill":
            return "Quick"
        case "tray.full.fill":
            return "Inbox"
        case "wrench.and.screwdriver.fill":
            return "Tools"
        case "folder.fill":
            return "Folder"
        default:
            return "Icon"
        }
    }
}

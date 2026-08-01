import SwiftUI

struct SmartFolderManagerView: View {
    var store: SmartFolderStore

    @State private var selectedCustomFolderID: UUID?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
        .frame(width: 640, height: 420)
        .navigationTitle("Smart Lists")
        .onAppear {
            applyPendingEditSelection()
            ensureSelectionIsValid()
        }
        .onChange(of: store.pendingEditFolderID) {
            applyPendingEditSelection()
        }
        .onChange(of: store.customFolders.map(\.id)) {
            ensureSelectionIsValid()
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selectedCustomFolderID) {
                ForEach(store.customFolders) { folder in
                    HStack(spacing: 8) {
                        SmartFolderIconTile(systemImage: folder.iconSystemName)
                        Text(folder.displayName)
                            .lineLimit(1)
                    }
                    .tag(folder.id as UUID?)
                }
            }

            Divider()

            HStack(spacing: 4) {
                Button {
                    addFolder()
                } label: {
                    Label("Add Smart List", systemImage: "plus")
                        .labelStyle(.iconOnly)
                        .frame(width: 20, height: 20)
                }
                .help("Add a smart list")

                Button {
                    deleteSelectedFolder()
                } label: {
                    Label("Delete Smart List", systemImage: "minus")
                        .labelStyle(.iconOnly)
                        .frame(width: 20, height: 20)
                }
                .disabled(selectedCustomFolderID == nil)
                .help("Delete the selected smart list")

                Spacer()

                Menu {
                    Button("Restore Default Lists") {
                        restoreDefaultLists()
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                        .labelStyle(.iconOnly)
                }
                .menuIndicator(.hidden)
                .fixedSize()
                .help("More options")
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .frame(width: 200)
    }

    @ViewBuilder
    private var detail: some View {
        if let folderBinding = selectedFolderBinding {
            SmartFolderEditor(folder: folderBinding)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                Text("Select or create a smart list")
                    .font(.headline)
                Text("Smart lists can match hostnames, keywords, and added-date ranges.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        selectedCustomFolderID = store.addFolder()
    }

    private func restoreDefaultLists() {
        let previousSelection = selectedCustomFolderID
        store.restoreDefaultFolders()

        if let previousSelection,
           store.customFolders.contains(where: { $0.id == previousSelection })
        {
            selectedCustomFolderID = previousSelection
        } else {
            selectedCustomFolderID = store.customFolders.first?.id
        }
    }

    private func deleteSelectedFolder() {
        guard let selectedCustomFolderID else {
            return
        }

        store.removeFolder(id: selectedCustomFolderID)
    }

    private func ensureSelectionIsValid() {
        if let selectedCustomFolderID,
           store.customFolders.contains(where: { $0.id == selectedCustomFolderID })
        {
            return
        }
        selectedCustomFolderID = store.customFolders.first?.id
    }

    private func applyPendingEditSelection() {
        guard let pendingID = store.pendingEditFolderID else {
            return
        }

        if store.customFolders.contains(where: { $0.id == pendingID }) {
            selectedCustomFolderID = pendingID
        }
        store.pendingEditFolderID = nil
    }
}

private struct SmartFolderEditor: View {
    @Binding var folder: CustomSmartFolder

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
        }
        .formStyle(.grouped)
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

import SwiftUI

struct SettingsView: View {
    var store: SmartFolderStore
    var accessManager: BookmarkAccessManager

    private enum SettingsTab: Hashable {
        case general
        case smartLists
        case advanced
    }

    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(accessManager: accessManager)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(SettingsTab.general)

            SmartFolderManagerView(store: store)
                .tabItem {
                    Label("Smart Lists", systemImage: "line.3.horizontal.decrease.circle")
                }
                .tag(SettingsTab.smartLists)

            AdvancedSettingsView(accessManager: accessManager)
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }
                .tag(SettingsTab.advanced)
        }
        .onAppear {
            if store.pendingEditFolderID != nil {
                selectedTab = .smartLists
            }
        }
        .onChange(of: store.pendingEditFolderID) {
            if store.pendingEditFolderID != nil {
                selectedTab = .smartLists
            }
        }
    }
}

private struct GeneralSettingsView: View {
    var accessManager: BookmarkAccessManager

    var body: some View {
        Form {
            Section("Safari Bookmarks") {
                LabeledContent("File") {
                    Text(filePathDescription)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                }

                if isDemoDataModeEnabled {
                    Text("Running with demo data — file access is disabled.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Button("Change File\u{2026}") {
                            accessManager.promptUserToSelectFile()
                        }

                        Button("Back Up\u{2026}") {
                            if case let .ready(url) = accessManager.state {
                                BookmarksBackup.promptAndSave(bookmarksPlistURL: url)
                            }
                        }
                        .disabled(!accessManager.state.isReady)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 640, height: 180)
    }

    private var filePathDescription: String {
        guard case let .ready(url) = accessManager.state else {
            return "Not selected"
        }

        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        if path.hasPrefix(homePath) {
            return "~" + path.dropFirst(homePath.count)
        }
        return path
    }
}

private struct AdvancedSettingsView: View {
    var accessManager: BookmarkAccessManager

    @AppStorage(AppSettingsKeys.isDeletionEnabled) private var isDeletionEnabled = false
    @State private var isShowingEnableConfirmation = false

    var body: some View {
        Form {
            Section("Deleting Items") {
                Toggle("Allow deleting items", isOn: deletionToggleBinding)

                Text(
                    "Adds a Delete option to items in your reading list. " +
                        "Deleted items are removed from Safari's Reading List on all your devices, " +
                        "and this app can't restore them — so it's worth keeping a recent backup."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 640, height: 180)
        .alert("Turn On Deleting?", isPresented: $isShowingEnableConfirmation) {
            if accessManager.state.isReady {
                Button("Back Up and Turn On") {
                    if case let .ready(url) = accessManager.state,
                       BookmarksBackup.promptAndSave(bookmarksPlistURL: url)
                    {
                        isDeletionEnabled = true
                    }
                }
            }

            Button("I Have a Backup") {
                isDeletionEnabled = true
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Deleting removes items from Safari's Reading List on all your devices, " +
                    "and this app can't undo it. Make sure you have a recent backup of your " +
                    "bookmarks file first — it only takes a second."
            )
        }
    }

    private var deletionToggleBinding: Binding<Bool> {
        Binding(
            get: { isDeletionEnabled },
            set: { newValue in
                if newValue {
                    isShowingEnableConfirmation = true
                } else {
                    isDeletionEnabled = false
                }
            }
        )
    }
}

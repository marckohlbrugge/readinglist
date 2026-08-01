import AppKit
import SwiftUI

@main
struct ReadingListApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var accessManager = BookmarkAccessManager()
    @State private var smartFolderStore = SmartFolderStore()

    private let isDemoMode = isDemoDataModeEnabled

    init() {
        FaviconPipelineConfiguration.configureSharedPipeline()
    }

    var body: some Scene {
        WindowGroup {
            if isDemoMode {
                DemoContentWrapper(smartFolderStore: smartFolderStore)
            } else {
                accessGatedView
                    .task {
                        accessManager.resolveAccess()
                    }
            }
        }
        .defaultSize(width: 1100, height: 720)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .textEditing) {
                Button("Find...") {
                    ToolbarSearchFieldFocus.focusInActiveWindow()
                }
                .keyboardShortcut("f", modifiers: [.command])
            }
            CommandGroup(after: .saveItem) {
                Button("Back Up Bookmarks\u{2026}") {
                    if case let .ready(url) = accessManager.state {
                        BookmarksBackup.promptAndSave(bookmarksPlistURL: url)
                    }
                }
                .disabled(!accessManager.state.isReady)
            }
        }

        Settings {
            SettingsView(store: smartFolderStore, accessManager: accessManager)
        }
        .windowResizability(.contentSize)
    }

    @ViewBuilder
    private var accessGatedView: some View {
        switch accessManager.state {
        case .checking:
            ProgressView("Checking access\u{2026}")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .needsPermission, .failed:
            BookmarkAccessView(accessManager: accessManager)
        case let .ready(url):
            MainContentWrapper(bookmarksPlistURL: url, smartFolderStore: smartFolderStore)
                .id(url)
        }
    }
}

let isDemoDataModeEnabled: Bool = {
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("--demo-data") {
        return true
    }

    let environment = ProcessInfo.processInfo.environment
    guard let rawFlag = environment["READING_LIST_DEMO"]?.lowercased() else {
        return false
    }

    return ["1", "true", "yes", "on"].contains(rawFlag)
}()

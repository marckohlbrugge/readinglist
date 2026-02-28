import AppKit
import SwiftUI

@main
struct ReadLaterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var accessManager = BookmarkAccessManager()

    private let isDemoMode = isDemoDataModeEnabled

    init() {
        FaviconPipelineConfiguration.configureSharedPipeline()
    }

    var body: some Scene {
        WindowGroup {
            if isDemoMode {
                DemoContentWrapper()
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
        }
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
            MainContentWrapper(bookmarksPlistURL: url)
        }
    }
}

private struct MainContentWrapper: View {
    let bookmarksPlistURL: URL

    @StateObject private var smartFolderStore = SmartFolderStore()
    @StateObject private var viewModel: ReadingListViewModel

    init(bookmarksPlistURL: URL) {
        self.bookmarksPlistURL = bookmarksPlistURL
        let store = SmartFolderStore()
        _smartFolderStore = StateObject(wrappedValue: store)
        let service = SafariReadingListService(bookmarksPlistURL: bookmarksPlistURL)
        _viewModel = StateObject(
            wrappedValue: ReadingListViewModel(service: service, smartFolderStore: store)
        )
    }

    var body: some View {
        ContentView(viewModel: viewModel, smartFolderStore: smartFolderStore)
            .task {
                viewModel.reload()
            }
    }
}

private struct DemoContentWrapper: View {
    @StateObject private var smartFolderStore: SmartFolderStore
    @StateObject private var viewModel: ReadingListViewModel

    init() {
        let store = SmartFolderStore()
        _smartFolderStore = StateObject(wrappedValue: store)
        _viewModel = StateObject(
            wrappedValue: ReadingListViewModel(
                smartFolderStore: store,
                demoItems: DemoReadingListData.makeItems()
            )
        )
    }

    var body: some View {
        ContentView(viewModel: viewModel, smartFolderStore: smartFolderStore)
            .task {
                viewModel.reload()
            }
    }
}

private let isDemoDataModeEnabled: Bool = {
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

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.applicationIconImage = AppIconFactory.makeAppIcon()

        // Ensure the first app window becomes key when launched from terminal.
        DispatchQueue.main.async {
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
                window.titleVisibility = .hidden
                window.title = ""
            }
        }
    }
}

private enum ToolbarSearchFieldFocus {
    @MainActor
    static func focusInActiveWindow() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
            return
        }
        guard let toolbar = window.toolbar else {
            return
        }
        guard let searchItem = toolbar.items.compactMap({ $0 as? NSSearchToolbarItem }).first else {
            return
        }

        window.makeFirstResponder(searchItem.searchField)
    }
}

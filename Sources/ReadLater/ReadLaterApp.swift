import AppKit
import SwiftUI

@main
struct ReadLaterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var smartFolderStore: SmartFolderStore
    @StateObject private var viewModel: ReadingListViewModel

    init() {
        FaviconPipelineConfiguration.configureSharedPipeline()

        let store = SmartFolderStore()
        _smartFolderStore = StateObject(wrappedValue: store)
        let demoItems = Self.isDemoDataModeEnabled ? DemoReadingListData.makeItems() : nil
        _viewModel = StateObject(
            wrappedValue: ReadingListViewModel(
                smartFolderStore: store,
                demoItems: demoItems
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel, smartFolderStore: smartFolderStore)
                .task {
                    viewModel.reload()
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

    private static var isDemoDataModeEnabled: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--demo-data") {
            return true
        }

        let environment = ProcessInfo.processInfo.environment
        guard let rawFlag = environment["READING_LIST_DEMO"]?.lowercased() else {
            return false
        }

        return ["1", "true", "yes", "on"].contains(rawFlag)
    }
}

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

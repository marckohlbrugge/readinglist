import AppKit

enum ToolbarSearchFieldFocus {
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

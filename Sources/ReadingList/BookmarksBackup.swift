import AppKit

@MainActor
enum BookmarksBackup {
    static func promptAndSave(bookmarksPlistURL: URL) {
        let timestamp = Date().formatted(
            .iso8601.year().month().day().dateSeparator(.dash)
        )
        let panel = NSSavePanel()
        panel.title = "Back Up Bookmarks"
        panel.nameFieldStringValue = "Bookmarks.plist.backup.\(timestamp)"
        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let destination = panel.url else { return }

        do {
            let data = try Data(contentsOf: bookmarksPlistURL)
            try data.write(to: destination, options: .atomic)
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }
}

import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class BookmarkAccessManager: ObservableObject {
    enum State: Equatable {
        case checking
        case needsPermission
        case ready(URL)
        case failed(String)
    }

    @Published var state: State = .checking

    private static let bookmarkDataKey = "SafariBookmarksPlistBookmarkData"
    private var accessedURL: URL?

    func resolveAccess() {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkDataKey) else {
            state = .needsPermission
            return
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                if let refreshedData = try? url.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                ) {
                    UserDefaults.standard.set(refreshedData, forKey: Self.bookmarkDataKey)
                }
            }

            guard url.startAccessingSecurityScopedResource() else {
                state = .needsPermission
                return
            }

            accessedURL = url
            state = .ready(url)
        } catch {
            state = .needsPermission
        }
    }

    func promptUserToSelectFile() {
        let panel = NSOpenPanel()
        panel.title = "Select Safari Bookmarks.plist"
        panel.message = "Navigate to ~/Library/Safari/ and select Bookmarks.plist"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType.propertyList]
        panel.treatsFilePackagesAsDirectories = true

        let safariDir = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Safari", directoryHint: .isDirectory)
        panel.directoryURL = safariDir

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            return
        }

        if let validationError = validateBookmarksPlist(at: url) {
            state = .failed(validationError)
            return
        }

        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: Self.bookmarkDataKey)

            guard url.startAccessingSecurityScopedResource() else {
                state = .failed("Could not access the selected file. Please try again.")
                return
            }

            accessedURL = url
            state = .ready(url)
        } catch {
            state = .failed("Failed to save file access: \(error.localizedDescription)")
        }
    }

    private func validateBookmarksPlist(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else {
            return "Could not read the selected file."
        }

        var format = PropertyListSerialization.PropertyListFormat.binary
        guard let plist = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: &format
        ) as? [String: Any] else {
            return "The selected file is not a valid property list."
        }

        guard containsReadingList(in: plist) else {
            return "The selected file does not appear to be Safari's Bookmarks.plist — no reading list data was found."
        }

        return nil
    }

    private func containsReadingList(in node: [String: Any]) -> Bool {
        if let title = node["Title"] as? String, title == "com.apple.ReadingList" {
            return true
        }
        if let children = node["Children"] as? [[String: Any]] {
            return children.contains(where: containsReadingList)
        }
        return false
    }

    deinit {
        if let url = accessedURL {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

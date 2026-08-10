# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Reading List is a native macOS app (Swift 6, SwiftUI) for browsing Safari's Reading List. It reads and writes `~/Library/Safari/Bookmarks.plist` directly—there is no public Apple API for this. The app is built with Swift Package Manager (not Xcode project files).

## Build & Run

```bash
swift build                          # compile
swift test                           # run tests (Swift Testing)
swift run "Reading List"             # run normally
swift run "Reading List" --demo-data # run with fake data (no plist access)
```

The product name is `"Reading List"` (with a space); the SPM target is `ReadingList`.

## Architecture

All source is in `Sources/ReadingList/`. Key layers:

- **SafariReadingListService** — reads/writes Safari's `Bookmarks.plist` (binary plist parsing, no Apple API). Handles fetch, mark-read, mark-unread, and delete. This is a `Sendable` struct; heavy work runs on detached tasks.
- **BookmarkAccessManager** — manages App Sandbox security-scoped bookmark access to the plist. Uses `NSOpenPanel` file picker on first launch; persists access via `UserDefaults` bookmark data.
- **ReadingListViewModel** — `@MainActor @Observable` class driving the UI. Owns all items plus the UI state (folder selection, search query, read-status filter `Unread` / `All` / `Viewed`, sort order `Newest First` / `Oldest First`, pagination, selected item) and recomputes derived data via `didSet` observers. Status filter and sort order persist to `UserDefaults`.
- **BookmarksFileMonitor** — DispatchSource-based watcher on `Bookmarks.plist` that auto-reloads the view model when Safari (or anything else) changes the file; re-arms after atomic replaces.
- **SmartFolderStore** — persists custom smart folders to `~/Library/Application Support/ReadingList/custom-smart-folders.json`. Seeds default folders (Recently Added, Videos, PDFs) on first run.
- **SettingsView** — standard tabbed Settings scene (⌘,): General (bookmarks file, backup) and Smart Lists (SmartFolderManagerView). The sidebar "Edit Smart List" context menu opens it via `openSettings` with `SmartFolderStore.pendingEditFolderID`.
- **SmartFolders** — defines `SmartFolder`, `CustomSmartFolder`, `FolderSelection`, and `AddedDateFilter`. Smart folders match items by hostname set, keyword list, and date filter.
- **ContentView** — three-column `NavigationSplitView`: sidebar (smart lists + domain folders), item list (with pagination at 250-item pages), and web preview pane.
- **FaviconStore** — uses Nuke/NukeUI for favicon loading via Google's favicon service, with a 100 MB disk cache.
- **UpdateChecker** — daily check against the GitHub releases API; shows an "Update Available" toolbar button linking to the release page. No auto-install. Skipped in demo mode and dev builds (no bundle version).

## Key Conventions

- Swift 6 strict concurrency; `@MainActor` on view models and stores, `Sendable` on services and models.
- macOS 14+ minimum deployment target.
- Demo mode (`--demo-data` flag or `READING_LIST_DEMO=1` env var) uses `DemoReadingListData` — no file system access.
- Writes (read-status changes and item deletion) go directly to Safari's `Bookmarks.plist` (atomic write). Deletion is opt-in via Settings → Advanced (`AppSettingsKeys.isDeletionEnabled`, off by default) and prompts the user to back up first when enabling.
- `ReadingListItem.id` is a composite of URL + dateAdded timestamp to handle duplicate URLs.

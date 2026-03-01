# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Reading List is a native macOS app (Swift 6, SwiftUI) for browsing Safari's Reading List. It reads and writes `~/Library/Safari/Bookmarks.plist` directly—there is no public Apple API for this. The app is built with Swift Package Manager (not Xcode project files).

## Build & Run

```bash
swift build                          # compile
swift run "Reading List"             # run normally
swift run "Reading List" --demo-data # run with fake data (no plist access)
```

The product name is `"Reading List"` (with a space); the SPM target is `ReadLater`.

## Architecture

All source is in `Sources/ReadLater/`. Key layers:

- **SafariReadingListService** — reads/writes Safari's `Bookmarks.plist` (binary plist parsing, no Apple API). Handles fetch, mark-read, mark-unread. This is a `Sendable` struct; heavy work runs on detached tasks.
- **BookmarkAccessManager** — manages App Sandbox security-scoped bookmark access to the plist. Uses `NSOpenPanel` file picker on first launch; persists access via `UserDefaults` bookmark data.
- **ReadingListViewModel** — `@MainActor ObservableObject` driving the UI. Holds all items, computes filtered/displayed items by folder selection, search query, and read-status filter.
- **SmartFolderStore** — persists custom smart folders to `~/Library/Application Support/ReadLater/custom-smart-folders.json`. Seeds default folders (Recently Added, Videos, PDFs) on first run.
- **SmartFolders** — defines `SmartFolder`, `CustomSmartFolder`, `FolderSelection`, and `AddedDateFilter`. Smart folders match items by hostname set, keyword list, and date filter.
- **ContentView** — three-column `NavigationSplitView`: sidebar (smart lists + domain folders), item list (with pagination at 250-item pages), and web preview pane.
- **FaviconStore** — uses Nuke/NukeUI for favicon loading via Google's favicon service, with a 100 MB disk cache.

## Key Conventions

- Swift 6 strict concurrency; `@MainActor` on view models and stores, `Sendable` on services and models.
- macOS 13+ minimum deployment target.
- Demo mode (`--demo-data` flag or `READING_LIST_DEMO=1` env var) uses `DemoReadingListData` — no file system access.
- Read-status writes go directly to Safari's `Bookmarks.plist` (atomic write). This is the only write operation.
- `ReadingListItem.id` is a composite of URL + dateAdded timestamp to handle duplicate URLs.

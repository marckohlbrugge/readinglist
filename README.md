# Reading List (Safari Reading List Viewer)

A focused macOS app for browsing Safari Reading List by [Marc Köhlbrugge](https://x.com/marckohlbrugge).

![Reading List screenshot](file:///Users/marc/Desktop/CleanShot%202026-02-28%20at%2016.44.24@2x.png)

Safari makes it very easy to save links for later on macOS and iOS, but there is no great dedicated app experience for browsing a large Reading List later.

This project is meant to be that missing macOS companion: a focused app for rediscovering your saved Safari Reading List items.

## Design inspiration

The UI is partly inspired by NetNewsWire and follows traditional macOS design patterns with native controls.

## What it does

- Imports Safari Reading List data from:
  - `~/Library/Safari/Bookmarks.plist`
- Lets you browse links by:
  - search (title, URL, hostname, preview text)
  - website/domain grouping
  - smart lists
- Includes default smart lists such as:
  - `Recently Added`
  - `Videos` (YouTube, Vimeo, and other video hosts)
  - `PDFs`
- Supports custom smart lists with editable:
  - name
  - icon
  - hostnames
  - keywords
  - added-date filter
- Supports read status:
  - `Unread` / `All` / `Viewed` filtering
  - explicit `Mark as Read` / `Mark as Unread` actions
- Shows favicons in sidebar and list rows
- Includes a built-in preview pane and quick actions to open links in Safari
- Includes right-click context menus for common actions (open, copy link, mark read/unread, etc.)

## Safety and data notes

This app is still under active development.

Apple does not provide a public Reading List API for this use case, so the app reads Safari's bookmark plist directly.  
Path: `~/Library/Safari/Bookmarks.plist`

When you use `Mark as Read` / `Mark as Unread` (explicit action only), the app writes to that file by updating Reading List metadata.

I try to be careful and avoid touching anything else, and it has worked well in real use, but you should still treat this as "use at your own risk."

Before using write actions, consider making a backup:

```bash
cp ~/Library/Safari/Bookmarks.plist ~/Library/Safari/Bookmarks.plist.backup.$(date +%Y%m%d-%H%M%S)
```

## Demo mode (safe for screenshots)

You can run the app with fake sample data (including emoji-rich titles) for screenshots and demos:

```bash
swift run "Reading List" --demo-data
```

In demo mode, the app does not read from or write to Safari's `Bookmarks.plist`.

## Build and run

1. Open this folder in Xcode and run the `Reading List` executable product.
2. Or run from Terminal:

```bash
swift run "Reading List"
```

If `swift` commands fail locally, accept the Xcode command line license first:

```bash
sudo xcodebuild -license
```

## Project status

This is currently a fast-moving source project.  
I may publish a packaged version later (for example App Store or direct download), but for now the intended way to use it is to build from source yourself.

## Contributions and support

This project is shared as-is while it is being actively built, and should be considered beta software.

- I am currently not accepting pull requests.
- I may review issues, but I am not committing to act on them.
- Some issues may be closed without a comment.
- If you strongly believe something should be addressed, you are still welcome to open an issue.
- I currently have no plans to provide formal support.

## License

This project is source-available under the terms in `LICENSE`.

- Personal, non-commercial use and modification are allowed.
- Redistribution is not allowed without written permission.
- Republishing in app stores or other download channels is not allowed without written permission.

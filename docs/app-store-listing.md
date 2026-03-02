# App Store Listing

## App Name
Reading List — The Missing App

## Subtitle (30 characters max)
Browse your Safari Read Later

## Description

Reading List gives you a dedicated app for Safari's Read Later list — something Apple never built.

Browse all your saved articles in a three-column interface with a sidebar, item list, and built-in web preview. Search across titles, URLs, and preview text. Filter to show only unread items. Mark articles as read or unread right from the app.

Smart Lists help you stay organized:
- Recently Added — links saved in the last 7 days
- Videos — YouTube, Vimeo, and other video links
- PDFs — saved documents and papers
- Create your own Smart Lists by filtering on website, keywords, or date

Your saved links are also automatically grouped by website, so you can quickly find everything from a specific source.

Reading List works directly with Safari's bookmarks file. You choose the file, and the app remembers your choice. No syncing, no accounts, no cloud services. Your data stays on your Mac.

## Keywords (100 characters max, comma-separated)
safari,reading list,read later,bookmarks,articles,reader,save for later,browse,unread

## What's New (for v1.0)
Initial release.

## App Review Notes

This app reads and writes Safari's Reading List stored in ~/Library/Safari/Bookmarks.plist. There is no public Apple API for accessing Safari's Reading List, so the app reads the plist file directly.

File access is granted explicitly by the user via NSOpenPanel on first launch. The app persists this access using security-scoped bookmarks per Apple's sandboxing guidelines. No private APIs or frameworks are used.

The only write operation is toggling read/unread status on individual items. The app prompts users to create a backup of their bookmarks file during onboarding before any modifications are made.

To test:
1. Open the app — it will ask you to select a bookmarks file
2. Navigate to ~/Library/Safari/ and select Bookmarks.plist
3. If your Reading List is empty, add a few pages in Safari first (Share > Add to Reading List)
4. Browse, search, and filter your reading list items
5. Try marking an item as read/unread and verify the change is reflected in Safari

## Support URL
(required — you need a URL, e.g. a GitHub repo, simple webpage, or email link like mailto:support@killbridge.com)

## Privacy Policy URL
(required for App Store — you need a privacy policy page stating the app doesn't collect or transmit any personal data)

## Category
Utilities

## Copyright
2026 Killbridge Ventures Pte. Ltd.

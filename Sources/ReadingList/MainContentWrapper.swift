import SwiftUI

struct MainContentWrapper: View {
    let bookmarksPlistURL: URL

    @State private var smartFolderStore: SmartFolderStore
    @State private var viewModel: ReadingListViewModel
    @State private var isShowingBackupPrompt = false

    private static let didOfferBackupKey = "ReadingList.didOfferInitialBackup"

    init(bookmarksPlistURL: URL) {
        self.bookmarksPlistURL = bookmarksPlistURL
        let store = SmartFolderStore()
        _smartFolderStore = State(initialValue: store)
        let service = SafariReadingListService(bookmarksPlistURL: bookmarksPlistURL)
        _viewModel = State(
            initialValue: ReadingListViewModel(service: service, smartFolderStore: store)
        )
    }

    var body: some View {
        ContentView(viewModel: viewModel, smartFolderStore: smartFolderStore)
            .task {
                viewModel.reload()
            }
            .task {
                if !UserDefaults.standard.bool(forKey: Self.didOfferBackupKey) {
                    UserDefaults.standard.set(true, forKey: Self.didOfferBackupKey)
                    isShowingBackupPrompt = true
                }
            }
            .alert(
                "Back up your bookmarks?",
                isPresented: $isShowingBackupPrompt
            ) {
                Button("Back Up\u{2026}") {
                    BookmarksBackup.promptAndSave(bookmarksPlistURL: bookmarksPlistURL)
                }
                .keyboardShortcut(.defaultAction)
                Button("Skip", role: .cancel) {}
            } message: {
                Text("This app can modify Safari's Bookmarks.plist when you mark items as read. We recommend saving a backup first. You can always create one later from File > Back Up Bookmarks.")
            }
    }
}

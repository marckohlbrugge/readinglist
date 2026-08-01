import SwiftUI

struct MainContentWrapper: View {
    let bookmarksPlistURL: URL
    let smartFolderStore: SmartFolderStore

    @State private var viewModel: ReadingListViewModel
    @State private var isShowingBackupPrompt = false

    private static let didOfferBackupKey = "ReadingList.didOfferInitialBackup"

    init(bookmarksPlistURL: URL, smartFolderStore: SmartFolderStore) {
        self.bookmarksPlistURL = bookmarksPlistURL
        self.smartFolderStore = smartFolderStore
        let service = SafariReadingListService(bookmarksPlistURL: bookmarksPlistURL)
        _viewModel = State(
            initialValue: ReadingListViewModel(service: service, smartFolderStore: smartFolderStore)
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

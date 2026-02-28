import SwiftUI

struct BookmarkAccessView: View {
    @ObservedObject var accessManager: BookmarkAccessManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Access to Safari Reading List")
                .font(.title2.weight(.semibold))

            Text("This app needs access to your Safari Bookmarks.plist file to display your reading list. Select the file once and you won't be asked again.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)

            Button("Select Bookmarks.plist\u{2026}") {
                accessManager.promptUserToSelectFile()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if case let .failed(message) = accessManager.state {
                Text(message)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            Text("The file is usually located at:\n~/Library/Safari/Bookmarks.plist")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

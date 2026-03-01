import SwiftUI

struct BookmarkAccessView: View {
    @ObservedObject var accessManager: BookmarkAccessManager

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "eyeglasses")
                    .font(.system(size: 56, weight: .thin))
                    .foregroundStyle(.primary)

                VStack(spacing: 8) {
                    Text("Welcome to Reading List")
                        .font(.largeTitle.weight(.semibold))

                    Text("Your Safari reading list, beautifully organized.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    stepRow(
                        number: 1,
                        title: "Select your bookmarks file",
                        detail: "We'll open a file picker pointed at the right folder."
                    )
                    stepRow(
                        number: 2,
                        title: "Create a backup",
                        detail: "We'll offer to save a backup copy before anything changes."
                    )
                    stepRow(
                        number: 3,
                        title: "Browse your reading list",
                        detail: "Search, filter, and rediscover your saved links."
                    )
                }
                .padding(20)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                .frame(maxWidth: 420)

                Button("Get Started") {
                    accessManager.promptUserToSelectFile()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if case let .failed(message) = accessManager.state {
                    Text(message)
                        .foregroundStyle(.red)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }
            }

            Spacer()

            Text("Reading List only accesses the file you select. Changes are limited to read/unread status.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func stepRow(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.accentColor, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

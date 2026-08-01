import SwiftUI

struct ReadingListRow: View {
    let item: ReadingListItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if !item.isViewed {
                UnreadDotBadge()
                    .padding(.top, 5)
            } else {
                Color.clear
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)
            }

            FaviconImage(hostname: item.hostname, size: 36)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(summaryText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                HStack(spacing: 8) {
                    Text(displayHostname)
                    Spacer(minLength: 8)
                    if let dateAdded = item.dateAdded {
                        Text(dateAdded.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .frame(minHeight: 96, alignment: .topLeading)
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    private var summaryText: String {
        if let preview = item.previewText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !preview.isEmpty
        {
            return preview
        }
        return item.url.absoluteString
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
    }

    private var displayHostname: String {
        item.hostname.hasPrefix("www.")
            ? String(item.hostname.dropFirst(4))
            : item.hostname
    }
}

struct UnreadDotBadge: View {
    var body: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 8, height: 8)
            .accessibilityLabel("Unread")
    }
}

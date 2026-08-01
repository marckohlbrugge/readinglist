import SwiftUI

enum SmartFolderIconPalette {
    static func tint(for systemImage: String) -> Color {
        switch systemImage {
        case "line.3.horizontal.decrease.circle.fill":
            return .blue
        case "clock.fill":
            return .orange
        case "play.rectangle.fill":
            return .red
        case "doc.fill":
            return .indigo
        case "book.fill":
            return .brown
        case "newspaper.fill":
            return .cyan
        case "bookmark.fill":
            return .pink
        case "graduationcap.fill":
            return .purple
        case "bolt.fill":
            return .yellow
        case "tray.full.fill":
            return .teal
        case "wrench.and.screwdriver.fill":
            return .gray
        case "folder.fill":
            return .blue
        default:
            return .blue
        }
    }
}

/// System Settings-style colored tile with a white symbol.
struct SmartFolderIconTile: View {
    let systemImage: String
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                SmartFolderIconPalette.tint(for: systemImage).gradient,
                in: RoundedRectangle(cornerRadius: size * 0.24)
            )
    }
}

import SwiftUI

/// The web preview plus reader mode's loading and "not available" states.
struct ArticlePreviewView: View {
    let url: URL
    let isReaderModeEnabled: Bool
    @State private var readerState = ReaderModeState.off
    @State private var isShowingUnavailableNotice = false

    var body: some View {
        WebPreviewView(
            url: url,
            isReaderModeEnabled: isReaderModeEnabled,
            onReaderStateChange: { readerState = $0 }
        )
        // Hide the cluttered page while its article is being extracted.
        .opacity(readerState == .extracting ? 0 : 1)
        .overlay {
            if readerState == .extracting {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .overlay(alignment: .top) {
            if isShowingUnavailableNotice {
                Text("Reader isn't available for this page")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 12)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isShowingUnavailableNotice)
        .onChange(of: readerState) { _, state in
            isShowingUnavailableNotice = state == .unavailable
        }
        .task(id: isShowingUnavailableNotice) {
            guard isShowingUnavailableNotice else {
                return
            }
            try? await Task.sleep(for: .seconds(3))
            isShowingUnavailableNotice = false
        }
    }
}

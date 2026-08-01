import Foundation
import FoundationModels

@main
struct Probe {
    static func main() async {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            print("FoundationModels: AVAILABLE")
        case let .unavailable(reason):
            print("FoundationModels: UNAVAILABLE — \(reason)")
        }

        let plistURL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Safari/Bookmarks.plist")
        do {
            let data = try Data(contentsOf: plistURL)
            print("Bookmarks.plist: readable, \(data.count / 1_000_000) MB")
        } catch {
            print("Bookmarks.plist: NOT readable — \(error.localizedDescription)")
        }

        if case .available = model.availability {
            let session = LanguageModelSession()
            do {
                let start = Date()
                let response = try await session.respond(to: "Reply with exactly one word: ready")
                let elapsed = Date().timeIntervalSince(start)
                print("Model sanity check (\(String(format: "%.1f", elapsed))s): \(response.content)")
            } catch {
                print("Model call failed: \(error)")
            }
        }
    }
}

import Foundation
import Observation

/// Checks the GitHub releases feed for a newer version of the app.
/// This never downloads or installs anything — it only surfaces a
/// link to the release page when an update is available.
@MainActor
@Observable
final class UpdateChecker {
    struct AvailableUpdate: Equatable, Sendable {
        let version: String
        let releaseURL: URL
    }

    private(set) var availableUpdate: AvailableUpdate?

    @ObservationIgnored private var checkTask: Task<Void, Never>?

    private nonisolated static let latestReleaseAPIURL =
        URL(string: "https://api.github.com/repos/marckohlbrugge/readinglist/releases/latest")!
    private nonisolated static let checkInterval: Duration = .seconds(24 * 60 * 60)

    /// Starts a daily update check. Does nothing in development builds,
    /// where the bundle has no version string.
    func startPeriodicChecks() {
        guard checkTask == nil, let installedVersion = Self.installedVersion else {
            return
        }

        checkTask = Task { [weak self] in
            while !Task.isCancelled {
                if let update = await Self.fetchAvailableUpdate(newerThan: installedVersion) {
                    guard let self else { return }
                    self.availableUpdate = update
                }
                try? await Task.sleep(for: Self.checkInterval)
            }
        }
    }

    deinit {
        checkTask?.cancel()
    }

    nonisolated static var installedVersion: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    private nonisolated static func fetchAvailableUpdate(
        newerThan installedVersion: String
    ) async -> AvailableUpdate? {
        struct LatestReleasePayload: Decodable {
            let tagName: String
            let htmlURL: URL

            enum CodingKeys: String, CodingKey {
                case tagName = "tag_name"
                case htmlURL = "html_url"
            }
        }

        var request = URLRequest(url: latestReleaseAPIURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            (response as? HTTPURLResponse)?.statusCode == 200,
            let payload = try? JSONDecoder().decode(LatestReleasePayload.self, from: data)
        else {
            return nil
        }

        let latestVersion = normalizedVersion(payload.tagName)
        guard isVersion(latestVersion, newerThan: installedVersion) else {
            return nil
        }

        return AvailableUpdate(version: latestVersion, releaseURL: payload.htmlURL)
    }

    nonisolated static func normalizedVersion(_ tag: String) -> String {
        tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    nonisolated static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let candidateComponents = versionComponents(candidate)
        let currentComponents = versionComponents(current)

        for index in 0 ..< max(candidateComponents.count, currentComponents.count) {
            let lhs = index < candidateComponents.count ? candidateComponents[index] : 0
            let rhs = index < currentComponents.count ? currentComponents[index] : 0
            if lhs != rhs {
                return lhs > rhs
            }
        }

        return false
    }

    private nonisolated static func versionComponents(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0) ?? 0 }
    }
}

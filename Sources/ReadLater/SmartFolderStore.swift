import Foundation

@MainActor
final class SmartFolderStore: ObservableObject {
    @Published var customFolders: [CustomSmartFolder] = [] {
        didSet {
            guard !isLoadingFromDisk else { return }
            saveToDisk()
        }
    }

    private let storageURL: URL
    private var isLoadingFromDisk = false
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private static let migratedLegacyDateDefaultsKey = "ReadLater.didMigrateLegacyDateDefaults.v2"
    private static let seededEditableDefaultsKey = "ReadLater.didSeedEditableDefaultLists.v1"

    init(storageURL: URL? = nil) {
        self.storageURL = storageURL ?? Self.defaultStorageURL()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        decoder = JSONDecoder()

        loadFromDisk()
        migrateLegacyDateDefaultsIfNeeded()
        seedEditableDefaultFoldersIfNeeded()
    }

    var builtInFolders: [SmartFolder] {
        SmartFolderConfig.builtIn
    }

    var customSmartFolders: [SmartFolder] {
        customFolders.map(\.smartFolder)
    }

    var allFolders: [SmartFolder] {
        builtInFolders + customSmartFolders
    }

    @discardableResult
    func addFolder() -> UUID {
        let folder = CustomSmartFolder()
        customFolders.append(folder)
        return folder.id
    }

    func removeFolder(id: UUID) {
        customFolders.removeAll { $0.id == id }
    }

    func restoreDefaultFolders() {
        let defaultIDs = Self.defaultEditableFolderIDs
        let nonDefaults = customFolders.filter { !defaultIDs.contains($0.id) }
        customFolders = Self.defaultEditableFolders + nonDefaults
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: storageURL), !data.isEmpty else {
            return
        }

        guard let decoded = try? decoder.decode([CustomSmartFolder].self, from: data) else {
            return
        }

        isLoadingFromDisk = true
        customFolders = decoded
        isLoadingFromDisk = false
    }

    private func saveToDisk() {
        let directoryURL = storageURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        guard let data = try? encoder.encode(customFolders) else {
            return
        }

        try? data.write(to: storageURL, options: [.atomic])
    }

    private func migrateLegacyDateDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.migratedLegacyDateDefaultsKey) else {
            return
        }

        // Remove older seeded time-based defaults that used to be custom folders.
        customFolders.removeAll { folder in
            Self.removedLegacyDefaultIDs.contains(folder.id)
        }

        defaults.set(true, forKey: Self.migratedLegacyDateDefaultsKey)
    }

    private func seedEditableDefaultFoldersIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.seededEditableDefaultsKey) else {
            return
        }

        let existingIDs = Set(customFolders.map(\.id))
        let missingDefaults = Self.defaultEditableFolders.filter { folder in
            !existingIDs.contains(folder.id)
        }

        if !missingDefaults.isEmpty {
            customFolders.insert(contentsOf: missingDefaults, at: 0)
        }

        defaults.set(true, forKey: Self.seededEditableDefaultsKey)
    }

    private static func defaultStorageURL() -> URL {
        let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support", directoryHint: .isDirectory)

        return applicationSupportURL
            .appending(path: "ReadLater", directoryHint: .isDirectory)
            .appending(path: "custom-smart-folders.json", directoryHint: .notDirectory)
    }

    private static var removedLegacyDefaultIDs: Set<UUID> {
        [
            stableUUID("11111111-1111-4111-8111-111111111111"),
            stableUUID("22222222-2222-4222-8222-222222222222"),
            stableUUID("33333333-3333-4333-8333-333333333333"),
        ]
    }

    private static func stableUUID(_ raw: String) -> UUID {
        UUID(uuidString: raw) ?? UUID()
    }

    private static var defaultEditableFolderIDs: Set<UUID> {
        Set(defaultEditableFolders.map(\.id))
    }

    private static var defaultEditableFolders: [CustomSmartFolder] {
        [
            CustomSmartFolder(
                id: stableUUID("50e6f84d-cd44-4be4-8a18-2a6c35d86465"),
                name: "Recently Added",
                iconSystemName: "clock.fill",
                addedDateFilter: .last7Days
            ),
            CustomSmartFolder(
                id: stableUUID("25092ce7-7f92-41bb-8af6-a43d7be8d5d7"),
                name: "Videos",
                iconSystemName: "play.rectangle.fill",
                hostnames: [
                    "youtube.com",
                    "youtu.be",
                    "youtube-nocookie.com",
                    "vimeo.com",
                    "dailymotion.com",
                    "twitch.tv",
                    "loom.com",
                    "streamable.com",
                    "tiktok.com",
                    "bilibili.com",
                    "rumble.com",
                ]
            ),
            CustomSmartFolder(
                id: stableUUID("7d0682fd-33fa-4df1-95ad-1e360a5c41b6"),
                name: "PDFs",
                iconSystemName: "doc.fill",
                keywords: [
                    ".pdf",
                    "format=pdf",
                    "application/pdf",
                ]
            ),
        ]
    }
}

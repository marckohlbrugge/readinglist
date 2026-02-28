import Foundation

enum AddedDateFilter: String, CaseIterable, Codable, Identifiable, Sendable {
    case any
    case today
    case last7Days
    case last30Days

    var id: Self { self }

    var title: String {
        switch self {
        case .any:
            return "Any Date"
        case .today:
            return "Today"
        case .last7Days:
            return "Last 7 Days"
        case .last30Days:
            return "Last 30 Days"
        }
    }

    func matches(
        dateAdded: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let dateAdded else {
            return self == .any
        }

        switch self {
        case .any:
            return true
        case .today:
            return calendar.isDate(dateAdded, inSameDayAs: now)
        case .last7Days:
            guard let start = calendar.date(byAdding: .day, value: -7, to: now) else {
                return false
            }
            return dateAdded >= start
        case .last30Days:
            guard let start = calendar.date(byAdding: .day, value: -30, to: now) else {
                return false
            }
            return dateAdded >= start
        }
    }
}

struct SmartFolder: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let systemImage: String
    let hostnames: Set<String>
    let keywords: [String]
    let addedDateFilter: AddedDateFilter
    let isBuiltIn: Bool

    init(
        id: String,
        name: String,
        systemImage: String,
        hostnames: Set<String> = [],
        keywords: [String] = [],
        addedDateFilter: AddedDateFilter = .any,
        isBuiltIn: Bool
    ) {
        self.id = id
        self.name = name
        self.systemImage = systemImage
        self.hostnames = Set(hostnames.map { Self.normalize(hostname: $0) }.filter { !$0.isEmpty })
        self.keywords = keywords
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        self.addedDateFilter = addedDateFilter
        self.isBuiltIn = isBuiltIn
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled List" : trimmed
    }

    func matches(item: ReadingListItem) -> Bool {
        guard addedDateFilter.matches(dateAdded: item.dateAdded) else {
            return false
        }

        if !hostnames.isEmpty {
            let host = item.hostname.lowercased()
            let hostMatches = hostnames.contains { candidate in
                host == candidate || host.hasSuffix(".\(candidate)")
            }
            guard hostMatches else {
                return false
            }
        }

        if !keywords.isEmpty {
            let haystack = [
                item.title,
                item.url.absoluteString,
                item.hostname,
                item.previewText ?? "",
            ].joined(separator: "\n").lowercased()

            let keywordMatches = keywords.contains { haystack.contains($0) }
            guard keywordMatches else {
                return false
            }
        }

        return true
    }

    private static func normalize(hostname: String) -> String {
        hostname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct CustomSmartFolder: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var iconSystemName: String
    var hostnames: [String]
    var keywords: [String]
    var addedDateFilter: AddedDateFilter

    init(
        id: UUID = UUID(),
        name: String = "New List",
        iconSystemName: String = Self.defaultSystemImage,
        hostnames: [String] = [],
        keywords: [String] = [],
        addedDateFilter: AddedDateFilter = .any
    ) {
        self.id = id
        self.name = name
        self.iconSystemName = iconSystemName
        self.hostnames = hostnames
        self.keywords = keywords
        self.addedDateFilter = addedDateFilter
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled List" : trimmed
    }

    var smartFolder: SmartFolder {
        SmartFolder(
            id: Self.smartFolderID(for: id),
            name: displayName,
            systemImage: iconSystemName,
            hostnames: Set(hostnames),
            keywords: keywords,
            addedDateFilter: addedDateFilter,
            isBuiltIn: false
        )
    }

    static let defaultSystemImage = "line.3.horizontal.decrease.circle.fill"

    static func smartFolderID(for id: UUID) -> String {
        "custom-\(id.uuidString.lowercased())"
    }

    static func customFolderID(from smartFolderID: String) -> UUID? {
        let prefix = "custom-"
        guard smartFolderID.hasPrefix(prefix) else {
            return nil
        }
        return UUID(uuidString: String(smartFolderID.dropFirst(prefix.count)))
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case iconSystemName
        case hostnames
        case keywords
        case addedDateFilter
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "New List"
        iconSystemName = try container.decodeIfPresent(String.self, forKey: .iconSystemName)
            ?? Self.defaultSystemImage
        hostnames = try container.decodeIfPresent([String].self, forKey: .hostnames) ?? []
        keywords = try container.decodeIfPresent([String].self, forKey: .keywords) ?? []
        addedDateFilter = try container.decodeIfPresent(AddedDateFilter.self, forKey: .addedDateFilter) ?? .any
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(iconSystemName, forKey: .iconSystemName)
        try container.encode(hostnames, forKey: .hostnames)
        try container.encode(keywords, forKey: .keywords)
        try container.encode(addedDateFilter, forKey: .addedDateFilter)
    }
}

enum FolderSelection: Hashable, Sendable {
    case all
    case smartFolder(String)
    case domain(String)

    func title(using smartFolders: [SmartFolder]) -> String {
        switch self {
        case .all:
            return "All Links"
        case let .smartFolder(id):
            return smartFolders.first(where: { $0.id == id })?.displayName ?? "Smart List"
        case let .domain(host):
            return host
        }
    }
}

enum SmartFolderConfig {
    static let builtIn: [SmartFolder] = []
}

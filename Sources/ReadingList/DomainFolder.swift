import Foundation

struct DomainFolder: Identifiable, Sendable {
    let hostname: String
    let count: Int

    var id: String { hostname }
}

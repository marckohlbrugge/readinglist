import Foundation
@testable import ReadingList
import Testing

@Suite("UpdateChecker")
struct UpdateCheckerTests {
    @Test func normalizedVersionStripsLeadingV() {
        #expect(UpdateChecker.normalizedVersion("v1.2.0") == "1.2.0")
        #expect(UpdateChecker.normalizedVersion("1.2.0") == "1.2.0")
    }

    @Test func newerVersionsAreDetected() {
        #expect(UpdateChecker.isVersion("1.2.0", newerThan: "1.1.0"))
        #expect(UpdateChecker.isVersion("2.0.0", newerThan: "1.9.9"))
        #expect(UpdateChecker.isVersion("1.0.10", newerThan: "1.0.9"))
        #expect(UpdateChecker.isVersion("1.1", newerThan: "1.0.5"))
    }

    @Test func equalAndOlderVersionsAreNotUpdates() {
        #expect(!UpdateChecker.isVersion("1.2.0", newerThan: "1.2.0"))
        #expect(!UpdateChecker.isVersion("1.2", newerThan: "1.2.0"))
        #expect(!UpdateChecker.isVersion("1.1.9", newerThan: "1.2.0"))
        #expect(!UpdateChecker.isVersion("0.9.0", newerThan: "1.0.0"))
    }
}

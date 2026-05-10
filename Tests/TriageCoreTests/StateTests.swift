import Foundation
import Testing
@testable import TriageCore

@Suite("State")
struct StateTests {

    private func tempURL(suffix: String = ".json") -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("triage-state-test-\(UUID().uuidString)\(suffix)")
    }

    // MARK: - Round-trip

    @Test func saveAndLoad_roundTrip() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let original = State(
            fallbackBrowserBundleID: "net.imput.helium",
            capturedAt: Date(timeIntervalSince1970: 1_777_777_777)
        )
        try original.save(to: url)
        let loaded = try State.load(from: url)
        #expect(loaded == original)
    }

    // MARK: - Disk format

    @Test func save_producesPlanCompatibleJSON() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let captured = ISO8601DateFormatter().date(from: "2026-05-08T14:32:00Z")!
        try State(
            fallbackBrowserBundleID: "net.imput.helium",
            capturedAt: captured
        ).save(to: url)

        let json = try String(contentsOf: url, encoding: .utf8)
        // snake_case field names per the plan spec
        #expect(json.contains("\"fallback_browser_bundle_id\""))
        #expect(json.contains("\"captured_at\""))
        // ISO-8601 date
        #expect(json.contains("\"2026-05-08T14:32:00Z\""))
        // human-readable bundle ID
        #expect(json.contains("\"net.imput.helium\""))
    }

    // MARK: - Parent directory creation

    @Test func save_createsMissingParentDirectories() throws {
        let baseDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("triage-state-mkdir-\(UUID().uuidString)")
        let nestedURL = baseDir
            .appendingPathComponent("a/b/c/fallback-browser.json")
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let state = State(fallbackBrowserBundleID: "com.apple.Safari")
        try state.save(to: nestedURL)
        #expect(FileManager.default.fileExists(atPath: nestedURL.path))
    }

    @Test func save_isAtomic_overwritesExistingFile() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let first = State(fallbackBrowserBundleID: "net.imput.helium")
        try first.save(to: url)

        let second = State(fallbackBrowserBundleID: "com.apple.Safari")
        try second.save(to: url)

        let loaded = try State.load(from: url)
        #expect(loaded.fallbackBrowserBundleID == "com.apple.Safari")
    }

    // MARK: - Errors

    @Test func load_missingFile_throwsIOError() {
        let bogusURL = URL(fileURLWithPath: "/nonexistent/triage-\(UUID().uuidString).json")
        #expect(throws: StateError.self) {
            try State.load(from: bogusURL)
        }
    }

    @Test func load_invalidJSON_throwsParseError() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try "not json {".write(to: url, atomically: true, encoding: .utf8)

        do {
            _ = try State.load(from: url)
            Issue.record("expected throw")
        } catch let StateError.parseError(message) {
            #expect(!message.isEmpty)
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    @Test func load_missingRequiredField_throwsParseError() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        // captured_at missing
        try """
        { "fallback_browser_bundle_id": "net.imput.helium" }
        """.write(to: url, atomically: true, encoding: .utf8)

        #expect(throws: StateError.self) {
            try State.load(from: url)
        }
    }

    // MARK: - Default URL

    @Test func defaultURL_pointsAtConfigDirectory() {
        let url = State.defaultURL
        #expect(url.path.hasSuffix("/.config/triage/fallback-browser.json"))
    }
}

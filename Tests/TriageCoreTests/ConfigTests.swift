import Foundation
import Testing
@testable import TriageCore

@Suite("Config")
struct ConfigTests {

    // MARK: - Happy-path parsing

    @Test func parse_minimalValid() throws {
        let yaml = """
        browsers:
          helium:
            bundle_id: net.imput.helium
        rules:
          - host: example.com
            browser: helium
        """
        let config = try Config.parse(yaml: yaml)
        #expect(config.browsers["helium"]?.bundleID == "net.imput.helium")
        #expect(config.browsers["helium"]?.profile == nil)
        #expect(config.rules.count == 1)
        #expect(config.rules[0].host == "example.com")
        #expect(config.rules[0].browser == "helium")
    }

    @Test func parse_browserWithProfile() throws {
        let yaml = """
        browsers:
          chrome_dev:
            bundle_id: com.google.Chrome
            profile: "Jose Manuel [Dev]"
        rules: []
        """
        let config = try Config.parse(yaml: yaml)
        let browser = try #require(config.browsers["chrome_dev"])
        #expect(browser.bundleID == "com.google.Chrome")
        #expect(browser.profile == "Jose Manuel [Dev]")
    }

    @Test func parse_snakeCaseFieldsMapped() throws {
        let yaml = """
        browsers:
          chrome:
            bundle_id: com.google.Chrome
        rules:
          - host: github.com
            source_app: Slack
            browser: chrome
        """
        let config = try Config.parse(yaml: yaml)
        #expect(config.rules[0].sourceApp == "Slack")
    }

    @Test func parse_emptyRules() throws {
        let yaml = """
        browsers:
          helium:
            bundle_id: net.imput.helium
        rules: []
        """
        let config = try Config.parse(yaml: yaml)
        #expect(config.rules.isEmpty)
        #expect(config.browsers.count == 1)
    }

    @Test func parse_catchAllRule_validates() throws {
        // A rule with no host/path/source_app is a valid catch-all (matches anything).
        let yaml = """
        browsers:
          helium:
            bundle_id: net.imput.helium
        rules:
          - browser: helium
        """
        let config = try Config.parse(yaml: yaml)
        #expect(config.rules[0].host == nil)
        #expect(config.rules[0].path == nil)
        #expect(config.rules[0].sourceApp == nil)
    }

    // MARK: - Validation errors

    @Test func validate_unknownBrowserReference() {
        let yaml = """
        browsers:
          helium:
            bundle_id: net.imput.helium
        rules:
          - host: example.com
            browser: chrome_work
        """
        #expect(throws: ConfigError.self) {
            try Config.parse(yaml: yaml)
        }
    }

    @Test func validate_unknownBrowser_carriesIndexAndName() throws {
        let yaml = """
        browsers:
          helium:
            bundle_id: net.imput.helium
        rules:
          - host: a.com
            browser: helium
          - host: b.com
            browser: missing
        """
        do {
            _ = try Config.parse(yaml: yaml)
            Issue.record("expected ConfigError to be thrown")
        } catch let ConfigError.unknownBrowserReference(ruleIndex, browserName) {
            #expect(ruleIndex == 1)
            #expect(browserName == "missing")
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    // MARK: - Parse errors

    @Test func parse_invalidYAML_throws() {
        #expect(throws: ConfigError.self) {
            try Config.parse(yaml: "this is not: : valid: yaml: [")
        }
    }

    @Test func parse_browserMissingBundleID_throws() {
        // bundle_id is required (non-optional in the Browser struct).
        let yaml = """
        browsers:
          helium: {}
        rules: []
        """
        #expect(throws: ConfigError.self) {
            try Config.parse(yaml: yaml)
        }
    }

    // MARK: - File I/O wrapper

    @Test func load_readsFromDisk() throws {
        let yaml = """
        browsers:
          helium:
            bundle_id: net.imput.helium
        rules: []
        """
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("triage-config-test-\(UUID().uuidString).yaml")
        try yaml.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let config = try Config.load(from: tempURL)
        #expect(config.browsers["helium"]?.bundleID == "net.imput.helium")
    }

    @Test func load_missingFile_throws() {
        let bogusURL = URL(fileURLWithPath: "/nonexistent/path/triage-\(UUID().uuidString).yaml")
        #expect(throws: ConfigError.self) {
            try Config.load(from: bogusURL)
        }
    }

    // MARK: - Realistic full example from the plan

    @Test func parse_planExampleYAML() throws {
        let yaml = """
        browsers:
          helium:
            bundle_id: net.imput.helium
          chrome_personal:
            bundle_id: com.google.Chrome
            profile: "Jose Manuel"
          chrome_dev:
            bundle_id: com.google.Chrome
            profile: "Jose Manuel [Dev]"
          chrome_3bits:
            bundle_id: com.google.Chrome
            profile: "3bitslost"

        rules:
          - host: "*.acme.io"
            browser: helium
          - host: "*.globex.com"
            browser: helium
          - host: gitlab.com
            path: "/acme/*"
            browser: helium
          - host: github.com
            path: "/globex/*"
            browser: helium
          - host: github.com
            path: "/3bitslost-team/*"
            browser: chrome_3bits
          - source_app: Slack
            browser: helium
        """
        let config = try Config.parse(yaml: yaml)
        #expect(config.browsers.count == 4)
        #expect(config.rules.count == 6)
        #expect(config.browsers["chrome_3bits"]?.profile == "3bitslost")
        #expect(config.rules.last?.sourceApp == "Slack")
    }
}

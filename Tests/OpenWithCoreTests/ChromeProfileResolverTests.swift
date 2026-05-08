import Foundation
import Testing
@testable import OpenWithCore

@Suite("ChromeProfileResolver")
struct ChromeProfileResolverTests {

    // MARK: - Parsing

    @Test func parse_singleProfile() throws {
        let json = """
        {
          "profile": {
            "info_cache": {
              "Default": { "name": "Jose Manuel" }
            }
          }
        }
        """
        let resolver = try ChromeProfileResolver.parse(localStateJSON: json)
        #expect(resolver.nameToDirectory == ["Jose Manuel": "Default"])
        #expect(resolver.duplicates.isEmpty)
    }

    @Test func parse_userActualProfileSet() throws {
        // Mirrors what the user actually has on disk (verified via Phase 0 spike).
        let json = """
        {
          "profile": {
            "info_cache": {
              "Default":   { "name": "Jose Manuel" },
              "Profile 4": { "name": "Jose Manuel [Dev]" },
              "Profile 5": { "name": "Donde la locura" },
              "Profile 8": { "name": "3bitslost" },
              "Profile 9": { "name": "aoiTo" }
            }
          }
        }
        """
        let resolver = try ChromeProfileResolver.parse(localStateJSON: json)
        #expect(resolver.directoryName(for: "Jose Manuel [Dev]") == "Profile 4")
        #expect(resolver.directoryName(for: "3bitslost") == "Profile 8")
        #expect(resolver.directoryName(for: "Donde la locura") == "Profile 5")
    }

    @Test func parse_extraFieldsInJSON_areIgnored() throws {
        // Real Chrome Local State has dozens of unrelated fields. We only care
        // about profile.info_cache.<dir>.name.
        let json = """
        {
          "browser": { "enabled_labs_experiments": [] },
          "profile": {
            "info_cache": {
              "Default": {
                "name": "Jose Manuel",
                "user_name": "x@y.com",
                "avatar_icon": "chrome://theme/IDR_PROFILE_AVATAR_0",
                "is_using_default_name": false
              }
            },
            "last_used": "Default"
          },
          "uninstall_metrics": { "installation_date2": "1234567890" }
        }
        """
        let resolver = try ChromeProfileResolver.parse(localStateJSON: json)
        #expect(resolver.nameToDirectory == ["Jose Manuel": "Default"])
    }

    // MARK: - Lookup semantics

    @Test func lookup_passthroughForUnknownName() throws {
        let resolver = try ChromeProfileResolver.parse(localStateJSON: """
        { "profile": { "info_cache": { "Default": { "name": "Jose Manuel" } } } }
        """)
        // User wrote a name that doesn't exist as a display name → treat as literal directory.
        #expect(resolver.directoryName(for: "Profile 99") == "Profile 99")
        #expect(resolver.directoryName(for: "anything else") == "anything else")
    }

    @Test func lookup_passthroughForLiteralDirectoryName() throws {
        let resolver = try ChromeProfileResolver.parse(localStateJSON: """
        {
          "profile": {
            "info_cache": {
              "Default":   { "name": "Jose Manuel" },
              "Profile 4": { "name": "Jose Manuel [Dev]" }
            }
          }
        }
        """)
        // User can specify "Profile 4" directly even though "Profile 4" isn't a display name.
        #expect(resolver.directoryName(for: "Profile 4") == "Profile 4")
        #expect(resolver.directoryName(for: "Default") == "Default")
    }

    // MARK: - Duplicates

    @Test func parse_duplicateDisplayNames_firstByDirectoryWins() throws {
        let json = """
        {
          "profile": {
            "info_cache": {
              "Default":   { "name": "Work" },
              "Profile 4": { "name": "Work" },
              "Profile 7": { "name": "Personal" }
            }
          }
        }
        """
        let resolver = try ChromeProfileResolver.parse(localStateJSON: json)
        // "Default" sorts before "Profile 4", so Default wins.
        #expect(resolver.directoryName(for: "Work") == "Default")
        #expect(resolver.duplicates == ["Work"])
        #expect(resolver.directoryName(for: "Personal") == "Profile 7")
    }

    // MARK: - Empty / missing sections

    @Test func parse_missingProfileSection_returnsEmptyResolver() throws {
        let resolver = try ChromeProfileResolver.parse(localStateJSON: "{}")
        #expect(resolver.nameToDirectory.isEmpty)
        // Passthrough still works.
        #expect(resolver.directoryName(for: "Default") == "Default")
    }

    @Test func parse_emptyInfoCache_returnsEmptyResolver() throws {
        let json = """
        { "profile": { "info_cache": {} } }
        """
        let resolver = try ChromeProfileResolver.parse(localStateJSON: json)
        #expect(resolver.nameToDirectory.isEmpty)
    }

    @Test func empty_passthroughBehavior() {
        // The `.empty` static is what the caller falls back to when Local State
        // can't be read (Chrome never installed, file unreadable, etc.).
        let resolver = ChromeProfileResolver.empty
        #expect(resolver.directoryName(for: "Profile 4") == "Profile 4")
        #expect(resolver.directoryName(for: "Default") == "Default")
        #expect(resolver.directoryName(for: "anything") == "anything")
    }

    // MARK: - Errors

    @Test func parse_invalidJSON_throws() {
        #expect(throws: ChromeProfileError.self) {
            try ChromeProfileResolver.parse(localStateJSON: "not json {")
        }
    }

    // MARK: - File I/O

    @Test func load_readsFromDisk() throws {
        let json = """
        { "profile": { "info_cache": { "Default": { "name": "Jose Manuel" } } } }
        """
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("openwith-localstate-test-\(UUID().uuidString).json")
        try json.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let resolver = try ChromeProfileResolver.load(from: tempURL)
        #expect(resolver.directoryName(for: "Jose Manuel") == "Default")
    }

    @Test func load_missingFile_throws() {
        let bogusURL = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).json")
        #expect(throws: ChromeProfileError.self) {
            try ChromeProfileResolver.load(from: bogusURL)
        }
    }
}

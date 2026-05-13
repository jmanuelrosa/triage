import Foundation
import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp` so the menu code reads naturally
/// and the failure modes are centralised in one place. The legacy
/// `LSSharedFileList` / login-item helper-app dance is intentionally not
/// supported — Triage's `LSMinimumSystemVersion` is 13.0, which matches the
/// modern API.
enum LoginItem {

    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    static var isEnabled: Bool {
        status == .enabled
    }

    static func enable() throws {
        try SMAppService.mainApp.register()
    }

    static func disable() throws {
        try SMAppService.mainApp.unregister()
    }
}

// openwith — Phase 0 POC
//
// Goal: confirm that an LSUIElement / .accessory macOS app can be set as the
// system default http/https handler, receive kAEGetURL events, and observe the
// source app via NSWorkspace without ever stealing frontmost focus.
//
// This is throwaway code. No rule engine, no config, no browser launching —
// just log every URL we receive plus the surrounding workspace state.

import AppKit
import OSLog

private let log = Logger(subsystem: "openwith.poc", category: "url-handler")

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Register here, NOT in applicationDidFinishLaunching: when macOS cold-launches
    // us in response to a URL click, the kAEGetURL event is delivered between
    // willFinishLaunching and didFinishLaunching. Registering in `Did` drops the
    // first URL.
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("launched, pid=\(getpid(), privacy: .public)")
    }

    @objc func handleURLEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent reply: NSAppleEventDescriptor
    ) {
        let url = event
            .paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?
            .stringValue ?? "<no url>"

        // The source app is encoded in the Apple Event itself, not the workspace.
        // 'spid' = keySenderPIDAttr — the PID of the process that originated the
        // URL open request. This survives even if macOS activates us to handle it.
        let senderPIDKey = AEKeyword(0x73706964) // 'spid'
        let senderPID = event
            .attributeDescriptor(forKeyword: senderPIDKey)?
            .int32Value ?? 0
        let sender = senderPID != 0
            ? NSRunningApplication(processIdentifier: senderPID)
            : nil

        let workspace = NSWorkspace.shared
        let frontmost = workspace.frontmostApplication

        log.info("""
        url=\(url, privacy: .public)
          sender (AE)    = \(sender?.localizedName ?? "?", privacy: .public) [\(sender?.bundleIdentifier ?? "?", privacy: .public)] pid=\(senderPID, privacy: .public)
          frontmost (WS) = \(frontmost?.localizedName ?? "?", privacy: .public) [\(frontmost?.bundleIdentifier ?? "?", privacy: .public)]
        """)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

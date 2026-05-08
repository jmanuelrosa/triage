import AppKit
import OSLog

private let log = Logger(subsystem: "com.jmrosamoncayo.openwith", category: "app")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let urlHandler = URLHandler()

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
        log.info("openwith launched, pid=\(getpid(), privacy: .public)")
    }

    @objc func handleURLEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent reply: NSAppleEventDescriptor
    ) {
        guard let url = event
            .paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?
            .stringValue
        else {
            log.error("kAEGetURL had no URL")
            return
        }

        // 'spid' = keySenderPIDAttr — the PID of the originating process.
        // Resolves to the user-visible source app (Slack, Notion, …) instead
        // of ourselves, even though macOS activates us to handle the event.
        let senderPID = event
            .attributeDescriptor(forKeyword: AEKeyword(0x73706964))?
            .int32Value ?? 0

        urlHandler.handle(url: url, senderPID: senderPID)
    }
}

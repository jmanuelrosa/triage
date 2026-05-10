import Foundation
import OSLog
import TriageCore

private let log = Logger(subsystem: "com.jmrosamoncayo.triage", category: "config-watcher")

/// Watches `~/.config/triage/config.yaml` for edits and reloads it on change,
/// invoking `onChange` on the main queue with a success or failure result.
///
/// Handles "atomic save" (editor writes a tmp file, then renames over the
/// original) by reopening the path after each event — a long-lived FD would
/// point at the now-unlinked old inode after such a save and miss subsequent
/// edits.
///
/// Events are debounced by 100 ms so a burst of writes during a single save
/// produces a single reload (and avoids racing partial YAML).
final class ConfigWatcher {

    private let url: URL
    private let onChange: (Result<Config, Error>) -> Void
    private let queue = DispatchQueue(label: "com.jmrosamoncayo.triage.config-watcher")
    private var source: DispatchSourceFileSystemObject?
    private var pendingReload: DispatchWorkItem?

    init(
        url: URL = Config.defaultURL,
        onChange: @escaping (Result<Config, Error>) -> Void
    ) {
        self.url = url
        self.onChange = onChange
    }

    deinit {
        source?.cancel()
    }

    /// Begin watching. No-op if the file is absent — call `restart()` after
    /// creating the file (e.g. when the menu's *Open Config File* writes the
    /// template).
    func start() {
        queue.async { [weak self] in self?.openAndWatch() }
    }

    func restart() { start() }

    private func openAndWatch() {
        cancelSource()
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            log.info("config not at \(self.url.path, privacy: .public) — watcher idle")
            return
        }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: queue
        )
        src.setEventHandler { [weak self] in
            guard let self else { return }
            let events = src.data
            if events.contains(.delete) || events.contains(.rename) {
                self.openAndWatch()
            }
            self.scheduleReload()
        }
        src.setCancelHandler { close(fd) }
        source = src
        src.resume()
        log.info("watching \(self.url.path, privacy: .public)")
    }

    private func cancelSource() {
        source?.cancel()
        source = nil
    }

    private func scheduleReload() {
        pendingReload?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.reload() }
        pendingReload = work
        queue.asyncAfter(deadline: .now() + .milliseconds(100), execute: work)
    }

    private func reload() {
        let result: Result<Config, Error>
        do {
            result = .success(try Config.load(from: url))
        } catch {
            result = .failure(error)
        }
        DispatchQueue.main.async { [onChange] in onChange(result) }
    }
}

import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Resolves the current working directory associated with a URL-open request,
/// via one of two signals:
///
/// 1. The Apple Event sender PID. Works when the AE sender resolves to
///    `/usr/bin/open` and `open`'s parent is still alive (terminal / SDK
///    invocation that doesn't detach `open`).
/// 2. The PID listening on the URL's TCP port. Works for loopback URLs from
///    dev servers (Vite/Next/CRA via the `open` npm package), where `open`
///    is detached + unref'd and exits before the AE arrives — the sender PID
///    is dead, but the dev-server listener is alive for the whole session.
///
/// Both methods return `nil` on any failure. The matcher treats `nil` as
/// "no cwd rule can match" and falls through. The contract is "best-effort,
/// strict-fail."
public protocol CwdResolving {
    /// Resolved cwd as an absolute path, or `nil` if the URL was not
    /// terminal-launched or the cwd could not be read.
    func resolveCwd(senderPID: pid_t) -> String?

    /// Resolved cwd by inspecting the process listening on `port`, or `nil`
    /// if no listener was found, the listener is on the Docker denylist, or
    /// its cwd could not be read. Intended as the second-chance lookup for
    /// loopback URLs when sender-PID resolution fails.
    func resolveCwd(listeningOnPort port: UInt16) -> String?
}

public extension CwdResolving {
    /// Default no-op: conformers that only implement the sender-PID path get
    /// the port path for free as "always nil," so URLHandler can call both
    /// uniformly. `SystemCwdResolver` overrides this with a real lookup.
    func resolveCwd(listeningOnPort port: UInt16) -> String? { nil }
}

/// Production implementation backed by `libproc` and `sysctl`. See the
/// individual method docs for the per-signal pipeline.
public struct SystemCwdResolver: CwdResolving {
    public init() {}

    /// The only sender path we react to. macOS routes `open(1)` invocations
    /// (and everything that shells out through them: `gh`, `npm`, language
    /// SDK `webbrowser` helpers, …) through this binary.
    private static let openBinaryPath = "/usr/bin/open"

    /// Pipeline:
    /// 1. `proc_pidpath(senderPID)` — confirm the sender is `/usr/bin/open`.
    ///    Any other executable path → not terminal-launched → `nil`. This
    ///    also doubles as a liveness check: if `open` has already exited
    ///    (race lost) `proc_pidpath` returns 0 → `nil`.
    /// 2. `sysctl(KERN_PROC_PID, senderPID)` → `kp_eproc.e_ppid` — the PID of
    ///    whoever ran `open`. Single-level walk, no shell-finding heuristic.
    /// 3. `proc_pidinfo(parentPID, PROC_PIDVNODEPATHINFO)` — the parent's cwd.
    public func resolveCwd(senderPID: pid_t) -> String? {
        guard senderPID > 0 else { return nil }
        guard let senderPath = Self.executablePath(for: senderPID) else { return nil }
        guard senderPath == Self.openBinaryPath else { return nil }
        guard let parentPID = Self.parentPID(of: senderPID), parentPID > 0 else { return nil }
        return Self.workingDirectory(of: parentPID)
    }

    /// Pipeline:
    /// 1. Walk every running PID's open FDs (`proc_listallpids` →
    ///    `proc_pidinfo(PROC_PIDLISTFDS)`); find one with a TCP socket in
    ///    `LISTEN` state whose local port equals `port`.
    /// 2. Read that PID's executable path; reject it if it looks like Docker
    ///    (the listener is the daemon, not the project — its cwd is useless).
    /// 3. Read its cwd via `proc_pidinfo(PROC_PIDVNODEPATHINFO)` — same helper
    ///    as the sender-PID path.
    ///
    /// Any step failing returns `nil` (strict-fail, same as the sender path).
    public func resolveCwd(listeningOnPort port: UInt16) -> String? {
        guard port > 0 else { return nil }
        guard let pid = Self.pidListeningOnTCPPort(port) else { return nil }
        if let exe = Self.executablePath(for: pid), Self.isDockerExecutable(exe) {
            return nil
        }
        return Self.workingDirectory(of: pid)
    }

    // MARK: - Darwin syscall wrappers

    private static func executablePath(for pid: pid_t) -> String? {
        // libproc.h defines PROC_PIDPATHINFO_MAXSIZE as (4 * MAXPATHLEN), but
        // Swift's Darwin module on Xcode 26 doesn't expose it. MAXPATHLEN is
        // available and the 4× multiplier mirrors the C constant for paranoid
        // headroom against pathological paths.
        let bufferSize = Int(MAXPATHLEN) * 4
        var buffer = [CChar](repeating: 0, count: bufferSize)
        let bytes = proc_pidpath(pid, &buffer, UInt32(bufferSize))
        guard bytes > 0 else { return nil }
        return String(cString: buffer)
    }

    private static func parentPID(of pid: pid_t) -> pid_t? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        let result = mib.withUnsafeMutableBufferPointer { mibPtr -> Int32 in
            sysctl(mibPtr.baseAddress, UInt32(mibPtr.count), &info, &size, nil, 0)
        }
        guard result == 0, size > 0 else { return nil }
        return info.kp_eproc.e_ppid
    }

    private static func workingDirectory(of pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let expectedSize = MemoryLayout<proc_vnodepathinfo>.size
        let result = proc_pidinfo(
            pid,
            PROC_PIDVNODEPATHINFO,
            0,
            &info,
            Int32(expectedSize)
        )
        guard result == Int32(expectedSize) else { return nil }

        // pvi_cdir.vip_path is `char[MAXPATHLEN]` imported as a homogeneous
        // tuple of CChar. Bind to a CChar pointer to read it as a C string.
        let cwd = withUnsafePointer(to: &info.pvi_cdir.vip_path) { tuplePtr -> String in
            tuplePtr.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) {
                String(cString: $0)
            }
        }
        return cwd.isEmpty ? nil : cwd
    }

    // MARK: - Port-listener walk

    /// Two-pass `proc_listallpids` (size, then populate). The extra slack
    /// guards against PIDs spawning between the two calls.
    private static func pidListeningOnTCPPort(_ targetPort: UInt16) -> pid_t? {
        let probeSize = proc_listallpids(nil, 0)
        guard probeSize > 0 else { return nil }
        let probeCount = Int(probeSize) / MemoryLayout<pid_t>.stride
        var pids = [pid_t](repeating: 0, count: probeCount + 32)
        let bufferBytes = Int32(pids.count * MemoryLayout<pid_t>.stride)
        let writtenBytes = proc_listallpids(&pids, bufferBytes)
        guard writtenBytes > 0 else { return nil }
        let writtenCount = Int(writtenBytes) / MemoryLayout<pid_t>.stride

        for index in 0..<writtenCount where pids[index] > 0 {
            if processIsListeningOnTCPPort(pid: pids[index], port: targetPort) {
                return pids[index]
            }
        }
        return nil
    }

    /// Enumerates the PID's FDs and looks for a TCP socket in LISTEN whose
    /// local port matches. Skips silently on any per-PID failure (perm,
    /// dead, etc.) — those are not our process to inspect.
    private static func processIsListeningOnTCPPort(pid: pid_t, port: UInt16) -> Bool {
        let probeSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard probeSize > 0 else { return false }
        let fdCount = Int(probeSize) / MemoryLayout<proc_fdinfo>.stride
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: fdCount)
        let writtenBytes = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &fds, probeSize)
        guard writtenBytes > 0 else { return false }
        let writtenCount = Int(writtenBytes) / MemoryLayout<proc_fdinfo>.stride

        for index in 0..<writtenCount {
            let fd = fds[index]
            // `proc_fdtype` is `uint32_t`; macro is bridged as Int — go via Int
            // to dodge differing import widths across SDK versions.
            guard Int(fd.proc_fdtype) == Int(PROX_FDTYPE_SOCKET) else { continue }
            if socketFDIsListeningOnTCPPort(pid: pid, fd: fd.proc_fd, port: port) {
                return true
            }
        }
        return false
    }

    private static func socketFDIsListeningOnTCPPort(pid: pid_t, fd: Int32, port: UInt16) -> Bool {
        var info = socket_fdinfo()
        let infoSize = Int32(MemoryLayout<socket_fdinfo>.size)
        let result = proc_pidfdinfo(pid, fd, PROC_PIDFDSOCKETINFO, &info, infoSize)
        guard result == infoSize else { return false }
        // `soi_kind` and `tcpsi_state` are C `int`; constants are bridged as
        // Int (enum cases) or Int32 (macros) depending on SDK — coerce both
        // sides to Int to compare safely.
        guard Int(info.psi.soi_kind) == Int(SOCKINFO_TCP) else { return false }

        let tcp = info.psi.soi_proto.pri_tcp
        guard Int(tcp.tcpsi_state) == Int(TSI_S_LISTEN) else { return false }

        // `insi_lport` is a C `int` holding the port in network byte order in
        // its low 16 bits. Truncate, then swap.
        let netPort = UInt16(truncatingIfNeeded: tcp.tcpsi_ini.insi_lport)
        let hostPort = UInt16(bigEndian: netPort)
        return hostPort == port
    }

    // MARK: - Docker denylist

    /// Docker publishes container ports by having `com.docker.backend`
    /// (or `vpnkit`) listen on the host port and proxy. Its cwd is `/` or
    /// Docker's working dir — meaningless for routing the project. Treat
    /// any listener whose executable path matches these prefixes as if no
    /// listener was found.
    private static let dockerExecutablePrefixes: [String] = [
        "/Applications/Docker.app/",
        "/usr/local/bin/docker",
        "/opt/homebrew/bin/docker",
        "/Library/Application Support/com.docker.",
    ]

    private static func isDockerExecutable(_ path: String) -> Bool {
        dockerExecutablePrefixes.contains { path.hasPrefix($0) }
    }
}

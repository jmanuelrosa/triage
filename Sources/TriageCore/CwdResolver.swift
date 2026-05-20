import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Resolves the current working directory of the process that invoked `open`
/// for a URL. Only meaningful when the AE sender resolves to `/usr/bin/open`;
/// every other case returns `nil` (and rules with `cwd:` will not match).
///
/// Returning `nil` is the safe default for every failure: race lost
/// (`/usr/bin/open` already exited), parent process unreachable, sandbox
/// restriction, anything else. The contract is "best-effort, strict-fail."
public protocol CwdResolving {
    /// Resolved cwd as an absolute path, or `nil` if the URL was not
    /// terminal-launched or the cwd could not be read.
    func resolveCwd(senderPID: pid_t) -> String?
}

/// Production implementation: walks one level up the process tree from the
/// `/usr/bin/open` invocation and reads the parent's cwd via `proc_pidinfo`.
///
/// Pipeline:
/// 1. `proc_pidpath(senderPID)` — confirm the sender is `/usr/bin/open`.
///    Any other executable path → not terminal-launched → `nil`.
/// 2. `sysctl(KERN_PROC_PID, senderPID)` → `kp_eproc.e_ppid` — the PID of
///    whoever ran `open`. Single-level walk, no shell-finding heuristic.
/// 3. `proc_pidinfo(parentPID, PROC_PIDVNODEPATHINFO)` — the parent's cwd.
///
/// Step 1 doubles as the gate: if `/usr/bin/open` has already exited by the
/// time we look it up (race lost), `proc_pidpath` fails and we return `nil`,
/// which the matcher treats as "no cwd-rule can match" — falls through.
public struct SystemCwdResolver: CwdResolving {
    public init() {}

    /// The only sender path we react to. macOS routes `open(1)` invocations
    /// (and everything that shells out through them: `gh`, `npm`, language
    /// SDK `webbrowser` helpers, …) through this binary.
    private static let openBinaryPath = "/usr/bin/open"

    public func resolveCwd(senderPID: pid_t) -> String? {
        guard senderPID > 0 else { return nil }
        guard let senderPath = Self.executablePath(for: senderPID) else { return nil }
        guard senderPath == Self.openBinaryPath else { return nil }
        guard let parentPID = Self.parentPID(of: senderPID), parentPID > 0 else { return nil }
        return Self.workingDirectory(of: parentPID)
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
}

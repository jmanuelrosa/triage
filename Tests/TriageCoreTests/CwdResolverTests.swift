import Foundation
import Testing
@testable import TriageCore
#if canImport(Darwin)
import Darwin
#endif

@Suite("CwdResolver")
struct CwdResolverTests {

    // MARK: - SystemCwdResolver sender-PID path (regression guard)

    /// Negative / zero PIDs come straight back as nil — the protocol is
    /// "best-effort, strict-fail" and a bad PID is a fail.
    @Test func systemResolver_invalidPID_returnsNil() {
        let resolver = SystemCwdResolver()
        #expect(resolver.resolveCwd(senderPID: 0) == nil)
        #expect(resolver.resolveCwd(senderPID: -1) == nil)
    }

    /// A live PID that isn't `/usr/bin/open` must return nil. The test
    /// binary itself satisfies this: it's running, but it's a test
    /// executable, not `open`.
    @Test func systemResolver_nonOpenSender_returnsNil() {
        let resolver = SystemCwdResolver()
        let selfPID = ProcessInfo.processInfo.processIdentifier
        #expect(resolver.resolveCwd(senderPID: selfPID) == nil)
    }

    /// A PID that almost certainly doesn't exist (very high number) must
    /// also fall through cleanly to nil — proc_pidpath fails and we
    /// return early.
    @Test func systemResolver_nonexistentPID_returnsNil() {
        let resolver = SystemCwdResolver()
        // pid_t max on macOS is typically 99999; pick something well above.
        #expect(resolver.resolveCwd(senderPID: 9_999_999) == nil)
    }

    // MARK: - SystemCwdResolver port-listener path

    /// Port 0 is reserved; resolver must short-circuit without scanning.
    @Test func systemResolver_invalidPort_returnsNil() {
        let resolver = SystemCwdResolver()
        #expect(resolver.resolveCwd(listeningOnPort: 0) == nil)
    }

    /// Bind and immediately close a TCP listener: the resolver should not
    /// find any listener on the now-free port and must return nil.
    @Test func systemResolver_unusedPort_returnsNil() throws {
        let handle = try TCPListenerHandle.bind(family: AF_INET)
        let port = handle.port
        handle.close()

        let resolver = SystemCwdResolver()
        #expect(resolver.resolveCwd(listeningOnPort: port) == nil)
    }

    /// IPv4 self-bound: end-to-end exercises proc_listallpids →
    /// proc_pidfdinfo → proc_pidinfo(PROC_PIDVNODEPATHINFO). Expect the
    /// test binary's own cwd back.
    @Test func systemResolver_selfBoundIPv4Port_returnsTestCwd() throws {
        let handle = try TCPListenerHandle.bind(family: AF_INET)
        defer { handle.close() }

        let resolver = SystemCwdResolver()
        let resolved = resolver.resolveCwd(listeningOnPort: handle.port)
        #expect(resolved == FileManager.default.currentDirectoryPath)
    }

    /// IPv6 self-bound: same path, dual-stack guard.
    @Test func systemResolver_selfBoundIPv6Port_returnsTestCwd() throws {
        let handle = try TCPListenerHandle.bind(family: AF_INET6)
        defer { handle.close() }

        let resolver = SystemCwdResolver()
        let resolved = resolver.resolveCwd(listeningOnPort: handle.port)
        #expect(resolved == FileManager.default.currentDirectoryPath)
    }

    // MARK: - Protocol contract via mock

    /// Wiring sanity check: a Rule with `cwd:` matches when the sender-PID
    /// resolver returns a value; doesn't match when it returns nil. Pins the
    /// sender-PID integration point that URLHandler relies on.
    @Test func mockResolver_senderPath_drivesRuleMatcher() {
        let resolved = MockCwdResolver(senderResult: "/Users/foo/work/proj")
        let unresolved = MockCwdResolver(senderResult: nil)

        let rule = Rule(cwd: "/Users/foo/work/*", browser: "work")

        let resolvedContext = MatchContext(
            host: nil, path: "/",
            cwd: resolved.resolveCwd(senderPID: 1234)
        )
        let unresolvedContext = MatchContext(
            host: nil, path: "/",
            cwd: unresolved.resolveCwd(senderPID: 1234)
        )

        #expect(RuleMatcher.firstMatch(rules: [rule], for: resolvedContext) == rule)
        #expect(RuleMatcher.firstMatch(rules: [rule], for: unresolvedContext) == nil)
    }

    /// Sender-PID resolution fails but the port-listener fallback fires —
    /// simulating URLHandler's two-step orchestration for a loopback URL.
    @Test func mockResolver_portPath_drivesRuleMatcher() {
        let resolver = MockCwdResolver(
            senderResult: nil,
            portResult: "/Users/foo/work/proj"
        )

        let rule = Rule(cwd: "/Users/foo/work/*", browser: "work")

        // URLHandler-shaped fallback: sender first, then port.
        let cwd = resolver.resolveCwd(senderPID: 1234)
            ?? resolver.resolveCwd(listeningOnPort: 3000)

        let context = MatchContext(host: "localhost", path: "/", cwd: cwd)
        #expect(RuleMatcher.firstMatch(rules: [rule], for: context) == rule)
    }
}

// MARK: - Mock

/// Minimal mock so URLHandler-level wiring can be exercised without
/// hitting `proc_pidinfo`. Lives next to the tests to keep production
/// surface area small.
private struct MockCwdResolver: CwdResolving {
    let senderResult: String?
    let portResult: String?

    init(senderResult: String? = nil, portResult: String? = nil) {
        self.senderResult = senderResult
        self.portResult = portResult
    }

    func resolveCwd(senderPID: pid_t) -> String? { senderResult }
    func resolveCwd(listeningOnPort port: UInt16) -> String? { portResult }
}

// MARK: - Test listener helper

/// BSD-socket-backed TCP listener bound to an ephemeral port on loopback.
/// Used by the port-listener tests to exercise the real syscall pipeline
/// against the test process itself.
private struct TCPListenerHandle {
    let fd: Int32
    let port: UInt16

    static func bind(family: Int32) throws -> TCPListenerHandle {
        let fd = socket(family, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(.EBADF) }

        var one: Int32 = 1
        _ = setsockopt(
            fd, SOL_SOCKET, SO_REUSEADDR,
            &one, socklen_t(MemoryLayout<Int32>.size)
        )

        let bindOK: Bool
        switch family {
        case AF_INET:
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_addr.s_addr = UInt32(0x7f00_0001).bigEndian  // 127.0.0.1
            addr.sin_port = 0
            bindOK = withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    Darwin.bind(
                        fd, sa,
                        socklen_t(MemoryLayout<sockaddr_in>.size)
                    ) == 0
                }
            }
        case AF_INET6:
            var addr = sockaddr_in6()
            addr.sin6_family = sa_family_t(AF_INET6)
            addr.sin6_port = 0
            // ::1 — fill in6_addr via inet_pton; in6addr_loopback isn't
            // exposed reliably to Swift.
            var loopback = in6_addr()
            _ = "::1".withCString { cstr in
                inet_pton(AF_INET6, cstr, &loopback)
            }
            addr.sin6_addr = loopback
            bindOK = withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    Darwin.bind(
                        fd, sa,
                        socklen_t(MemoryLayout<sockaddr_in6>.size)
                    ) == 0
                }
            }
        default:
            Darwin.close(fd)
            throw POSIXError(.EAFNOSUPPORT)
        }

        guard bindOK, Darwin.listen(fd, 1) == 0 else {
            Darwin.close(fd)
            throw POSIXError(.EADDRINUSE)
        }

        // Read back the assigned port via getsockname.
        var storage = sockaddr_storage()
        var size = socklen_t(MemoryLayout<sockaddr_storage>.size)
        let gotName = withUnsafeMutablePointer(to: &storage) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                getsockname(fd, sa, &size) == 0
            }
        }
        guard gotName else {
            Darwin.close(fd)
            throw POSIXError(.ENOTSOCK)
        }

        let port: UInt16
        switch family {
        case AF_INET:
            port = withUnsafePointer(to: &storage) {
                $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { addr in
                    UInt16(bigEndian: addr.pointee.sin_port)
                }
            }
        case AF_INET6:
            port = withUnsafePointer(to: &storage) {
                $0.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { addr in
                    UInt16(bigEndian: addr.pointee.sin6_port)
                }
            }
        default:
            Darwin.close(fd)
            throw POSIXError(.EAFNOSUPPORT)
        }

        return TCPListenerHandle(fd: fd, port: port)
    }

    func close() {
        Darwin.close(fd)
    }
}

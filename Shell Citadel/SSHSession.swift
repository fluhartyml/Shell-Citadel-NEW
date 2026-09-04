//
//  SSHSession.swift
//  Shell Citadel
//
//  Roadmap step 1: talks to the Mac.
//
//  The bar for this step is exactly what Michael set for the old app, and it is a
//  behavioural bar, not a compiling one: `who am i` typed on the phone comes back with
//  the real answer, and `cd` sticks between commands.
//

import Foundation
import Citadel
import NIOCore

enum SSHError: LocalizedError {
    case notConnected
    case cannotResolve(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            "Not connected."
        case .cannotResolve(let name):
            // ⚠️ SAY WHICH FAILURE THIS IS. A single "could not reach the server" for
            // every possible cause is what turned one stale IP address into an hour of
            // guessing on 2026-09-04.
            "\(name) could not be looked up. On cellular, or behind a VPN that captures DNS, a .local name will not resolve."
        }
    }
}

actor SSHSession {
    private var client: SSHClient?
    private var trust: HostKeyTrust?

    /// Where the shell currently is. Tracked here rather than assumed, so `cd` sticks.
    private(set) var workingDirectory = ""

    /// The address the last successful connection actually used, so the caller can
    /// remember it for when the name stops resolving.
    private(set) var addressUsed: String?

    var isConnected: Bool { client != nil }

    /// True when this host was seen for the first time, so the UI can say so rather
    /// than letting a blind first trust pass silently.
    var trustedOnFirstUse: Bool { trust?.didTrustOnFirstUse ?? false }

    // MARK: - Connect

    /// Connects by NAME first, then by the last address that worked.
    func connect(to connection: Connection, password: String) async throws {
        await close()

        var candidates = [connection.host]
        if connection.hostIsName, let fallback = connection.lastKnownAddress, !fallback.isEmpty {
            candidates.append(fallback)
        }

        var lastError: Error?
        for address in candidates {
            do {
                await MainActor.run {
                    Diagnostics.shared.connectionChanged("connecting to \(address)")
                }
                let trust = HostKeyTrust(host: address)
                let client = try await SSHClient.connect(
                    host: address,
                    port: connection.port,
                    authenticationMethod: .passwordBased(username: connection.username, password: password),
                    hostKeyValidator: .custom(trust),
                    reconnect: .never
                )
                self.client = client
                self.trust = trust
                self.addressUsed = address
                self.workingDirectory = ""
                await MainActor.run {
                    Diagnostics.shared.connectionChanged("connected via \(address)")
                }
                return
            } catch {
                lastError = error
                await MainActor.run {
                    // Which candidate failed, and why. The whole point of 0.3.
                    Diagnostics.shared.record(.connection, "\(address) failed: \(error.localizedDescription)")
                }
            }
        }

        let reason = lastError?.localizedDescription ?? "unknown"
        await MainActor.run { Diagnostics.shared.failed(.connection, reason) }
        throw lastError ?? SSHError.notConnected
    }

    func close() async {
        if client != nil {
            await MainActor.run { Diagnostics.shared.connectionChanged("closed") }
        }
        client = nil
        trust = nil
    }

    /// Drops the session without trying to talk to a far end that is already gone.
    /// Called when a send fails: at that point the connection is not coming back on its
    /// own, and pretending otherwise leaves a "Connected" header with no way back.
    func markDisconnected() {
        client = nil
        trust = nil
        Task { @MainActor in Diagnostics.shared.connectionChanged("disconnected") }
    }

    // MARK: - Run

    /// Runs a command with the working directory carried across calls, so `cd` sticks.
    func runTrackingDirectory(_ command: String) async throws -> String {
        let prefix = workingDirectory.isEmpty ? "" : "cd \(Self.shellQuoted(workingDirectory)) && "
        // The marker separates the command's own output from the pwd probe, so a command
        // that happens to print a path cannot be mistaken for the new directory.
        let marker = "__SHELL_CITADEL_PWD__"
        let output = try await run("\(prefix)\(command); printf '\\n%s\\n' \(Self.shellQuoted(marker)); pwd")

        guard let range = output.range(of: marker, options: .backwards) else { return output }
        let body = String(output[output.startIndex..<range.lowerBound])
        let pwd = String(output[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !pwd.isEmpty { workingDirectory = pwd }
        return body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func run(_ command: String) async throws -> String {
        guard let client else { throw SSHError.notConnected }

        // ⚠️ COLLECTED BY HAND rather than with executeCommand(), because that throws on
        // a non-zero exit AND DISCARDS THE OUTPUT — leaving "CommandFailed error 1" on
        // screen when the Mac actually said "command not found". A failed command's own
        // message is the most useful thing there is; losing it to an exit code is the
        // opposite of helping.
        var collected = ""
        let stream = try await client.executeCommandStream(command)
        do {
            for try await chunk in stream {
                switch chunk {
                case .stdout(let buffer), .stderr(let buffer):
                    var reader = buffer
                    collected += reader.readString(length: reader.readableBytes) ?? ""
                }
            }
        } catch {
            let text = collected.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { throw error }
            return text
        }
        return collected.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Single-quote for the remote shell, escaping any quote inside.
    static func shellQuoted(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

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
    case tmuxNotFound
    case noSuchSession(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            "Not connected."
        case .tmuxNotFound:
            "tmux is not installed on that machine, and tmux mode needs it. Terminal mode does not \u{2014} switch modes in the connection settings, or install tmux there."
        case .noSuchSession(let name):
            "No tmux session named \(name) is running there. Run tmux ls on that machine to see which sessions exist."
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

    // MARK: - Step 5  —  handing a message to the Claude session

    private var cachedTmuxPath: String?

    /// ⚠️ AN SSH EXEC CHANNEL IS NOT A LOGIN SHELL, so it gets a minimal PATH that does
    /// NOT include Homebrew's /opt/homebrew/bin. Plain `tmux` is therefore "command not
    /// found", which Citadel reports as `CommandFailed error 1` — a string that tells
    /// nobody anything. Found the hard way on a real phone. Resolved once per connection.
    private func tmuxExecutable() async throws -> String {
        if let cachedTmuxPath { return cachedTmuxPath }
        let probe = "for p in /opt/homebrew/bin/tmux /usr/local/bin/tmux /usr/bin/tmux /bin/tmux; do [ -x \"$p\" ] && echo \"$p\" && exit 0; done; command -v tmux 2>/dev/null || true"
        let found = (try? await run(probe))?
            .split(separator: "\n").first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        guard !found.isEmpty else { throw SSHError.tmuxNotFound }
        let quoted = Self.shellQuoted(found)
        cachedTmuxPath = quoted
        return quoted
    }

    /// Delivers a line into the running tmux session.
    ///
    /// ⚠️ A PASTE BUFFER, NOT `send-keys -l`. This looks like a detail and is not.
    /// `send-keys -l` types the text LITERALLY, one character at a time, at roughly three
    /// characters a second over SSH. Michael sent a sentence from the porch on
    /// 2026-08-25, watched nothing arrive for minutes, and reported "My terminals looked
    /// like they got stuck." Nothing was stuck — it was still typing, and he could no
    /// longer remember what he had written. `set-buffer` + `paste-buffer` hands the whole
    /// string over in ONE operation: measured at 0.065s for 783 characters against
    /// roughly four minutes typed.
    ///
    /// ⚠️ `-p` IS LOAD-BEARING: IT IS BRACKETED PASTE, AND WITHOUT IT THE FRONT OF A LONG
    /// MESSAGE IS LOST. A 455-character line arrived on the Mac missing its first
    /// eighteen characters while all seventeen repeats at the end survived. Measured, not
    /// guessed: the same command against a throwaway session running `cat > file` gave
    /// 455 bytes in and 456 out, front intact — so tmux delivers it perfectly and the
    /// loss is in the RECEIVING program. Without `-p`, paste-buffer replays the buffer as
    /// ordinary keystrokes, and a TUI expecting the bracketed-paste markers drops the
    /// leading characters before its input handling settles.
    ///
    /// The buffer name is deliberately odd so it can never clobber one he is using
    /// himself, and `-d` deletes it the moment it has been pasted. The Enter that submits
    /// stays a separate, deliberate key.
    func sendToSession(_ text: String, session sessionName: String, tag: String) async throws {
        guard client != nil else { throw SSHError.notConnected }
        let tmux = try await tmuxExecutable()
        let session = Self.shellQuoted(sessionName)

        // Check the session exists first, so a typo produces a sentence rather than an
        // exit code.
        let check = try? await run("\(tmux) has-session -t \(session) && echo OK")
        guard check?.contains("OK") == true else {
            throw SSHError.noSuchSession(sessionName)
        }

        // ⚠️ THE STAMP IS FOR CLAUDE, NOT FOR HIM. His words: "I don't need to see the
        // time stamps you do." A long turn means several of his messages arrive together,
        // and without a sent-time Claude cannot tell which are current and which were
        // overtaken minutes ago. The source tag matters for the same reason: more than
        // one app types into this session, and without it Claude cannot tell which.
        let stamped = "[\(Self.sentStamp()) \(tag)] \(text)"
        let body = Self.shellQuoted(stamped)
        let buffer = "shell-citadel-msg"
        _ = try await run("""
            \(tmux) set-buffer -b \(buffer) -- \(body) \
              && \(tmux) paste-buffer -d -p -b \(buffer) -t \(session) \
              && \(tmux) send-keys -t \(session) Enter
            """)
        await MainActor.run { Diagnostics.shared.record(.connection, "delivered \(stamped.count) chars to tmux \(sessionName)") }
    }

    static func sentStamp(at date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    // MARK: - Step 5  —  the reply channel

    /// Sentences Claude has chosen to say, one line at a time, as they are written.
    ///
    /// ⚠️ THE PASSIVE QUEUE. `startingAtByte` resumes from where this device last read,
    /// so locking the screen or walking out of range costs nothing — the Mac's file kept
    /// everything and the reconnect fills the gap in order. `0` means start at the end,
    /// which is right for a first connection: replaying months of an old session at
    /// someone is worse than showing them nothing.
    ///
    /// `-F` rather than `-f` follows the file across rotation and recreation instead of
    /// holding a dead handle.
    func replyLines(path rawPath: String, startingAtByte startOffset: Int = 0) async throws -> AsyncThrowingStream<ReplyChunk, Error> {
        guard let client else { throw SSHError.notConnected }
        let path = Self.remotePath(rawPath)
        // `tail -c +N` is 1-based: +1 is the whole file, so N is (bytes read) + 1.
        let follow = startOffset > 0 ? "tail -c +\(startOffset + 1) -F \(path)" : "tail -n 0 -F \(path)"
        let raw = try await client.executeCommandStream(
            "mkdir -p \"$(dirname \(path))\" && touch \(path) && \(follow)",
            inShell: true
        )

        return AsyncThrowingStream { continuation in
            Task {
                // stdout arrives in arbitrary chunks, not neatly per line, so partial
                // lines are held back until their newline shows up. Speaking half a
                // sentence aloud would be worse than speaking it a moment later.
                var pending = ""
                // The mark only ever advances over COMPLETE lines. Whatever is still in
                // `pending` when a connection dies is left uncounted on purpose, so that
                // sentence is re-read whole next time rather than resumed mid-word.
                var consumed = startOffset
                do {
                    for try await chunk in raw {
                        guard case .stdout(let outBuffer) = chunk else { continue }
                        var reader = outBuffer
                        guard let text = reader.readString(length: reader.readableBytes) else { continue }
                        pending += text
                        while let newline = pending.firstIndex(of: "\n") {
                            let line = String(pending[pending.startIndex..<newline])
                            pending = String(pending[pending.index(after: newline)...])
                            // Counted whether or not it is shown: blank separator lines
                            // occupy bytes too, and skipping them in the count would walk
                            // the mark backwards a little on every message.
                            consumed += line.utf8.count + 1
                            let trimmed = line.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty {
                                continuation.yield(ReplyChunk(text: trimmed, offsetAfter: consumed))
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Quote a path that may begin with `~`, leaving the tilde outside the quotes so the
    /// remote shell still expands it.
    static func remotePath(_ path: String) -> String {
        if path.hasPrefix("~/") {
            return "~/" + shellQuoted(String(path.dropFirst(2)))
        }
        return shellQuoted(path)
    }

    // MARK: - Upload

    /// Writes bytes to a folder in the far end's home directory and returns the path.
    ///
    /// ⚠️ CONTAINMENT, HIS RULE. Michael, 2026-08-27: "that way the pictures and videos
    /// stay within shell citadel and dont leave its sandbox." These photographs are of
    /// medical documents, the inside of his house, his equipment. Nothing is written to
    /// the photo library — the moment an image lands there it syncs to iCloud and it has
    /// left. The bytes exist in memory, go up this wire, and are dropped.
    func upload(_ data: Data, named filename: String, toFolder folder: String) async throws -> String {
        guard let client else { throw SSHError.notConnected }

        // Make the folder first. `mkdir -p` is idempotent, so a second send costs
        // nothing and a first send on a clean Mac does not fail.
        _ = try await run("mkdir -p \(Self.shellQuoted(folder))")
        let home = try await run("printf %s \"$HOME\"")
        let directory = folder.hasPrefix("/") ? folder : "\(home)/\(folder)"
        let remotePath = "\(directory)/\(filename)"

        let sftp = try await client.openSFTP()
        do {
            var buffer = ByteBufferAllocator().buffer(capacity: data.count)
            buffer.writeBytes(data)
            try await sftp.withFile(filePath: remotePath,
                                    flags: [.create, .write, .truncate]) { file in
                try await file.write(buffer)
            }
            try await sftp.close()
        } catch {
            // Close even on failure. An SFTP channel left open survives as long as the
            // connection does, and the connection is meant to last all day.
            try? await sftp.close()
            await MainActor.run { Diagnostics.shared.failed(.connection, "upload failed: \(error.localizedDescription)") }
            throw error
        }

        await MainActor.run { Diagnostics.shared.record(.connection, "uploaded \(data.count) bytes to \(remotePath)") }
        return remotePath
    }

    /// Single-quote for the remote shell, escaping any quote inside.
    static func shellQuoted(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

/// One line from the reply channel, with how far into the file it ends.
struct ReplyChunk: Sendable {
    let text: String
    let offsetAfter: Int
}

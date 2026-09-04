//
//  Connection.swift
//  Shell Citadel
//
//  Where to connect, and how to still find it when the address has moved.
//

import Foundation

/// One saved destination.
struct Connection: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()

    /// A friendly label for the list. Not used to connect.
    var name = "My Mac"

    /// ⚠️ THE ADDRESS IS A NAME BY DEFAULT, AND THAT IS DELIBERATE.
    ///
    /// Michael, 2026-09-04, asked whether his Mac should get a fixed IP:
    /// "sounds like an engineering issue, i would as a layman say use
    ///  his Mac's .local name."
    ///
    /// He is right, and the layman answer is the better engineering one. A Bonjour
    /// name follows the machine, so the address changing stops mattering — nothing to
    /// configure on his router and nothing for him to remember. On 2026-09-04 his
    /// Mac moved from one address to .63 overnight and every saved connection broke;
    /// a name would have survived that untouched.
    var host = ""

    var port = 22
    var username = ""

    /// ⚠️ THE SECOND PATH. A `.local` name is resolved by mDNS, which does not work
    /// over cellular and can be swallowed by a VPN profile that captures DNS. So the
    /// name alone is not enough either — on the same morning, `.local` failed and the
    /// app said "could not reach the server", which is also what it says for a dead
    /// host, a wrong port and a blocked network.
    ///
    /// Every successful connection records the address it actually reached, and a
    /// failure to RESOLVE the name falls back to it. Two independent paths, nothing
    /// for him to configure, and neither one's failure is silent.
    var lastKnownAddress: String?

    // MARK: - Step 5 — reaching the Claude session

    /// Which mode this connection runs in.
    ///
    /// ⚠️ THE TWO ARE NOT THE SAME APP WITH A SETTING. `.shell` is a terminal: you type
    /// a command, the Mac answers. `.claude` is a CONVERSATION: what you type is handed
    /// into a running session, and what comes back is what Claude chose to SAY.
    enum Mode: String, Codable, CaseIterable, Sendable {
        case shell
        case claude

        var title: String {
            switch self {
            case .shell: "Terminal"
            case .claude: "Claude"
            }
        }
    }

    var mode: Mode = .shell

    /// The tmux session to hand messages to. Neutral by default — a stranger's first run
    /// should not arrive pre-filled with someone else's session name.
    var tmuxSession = "claude"

    /// A file the far end appends plain sentences to, read as the reply channel.
    ///
    /// ⚠️ WHY A SIDE FILE AND NOT THE TERMINAL. Claude Code inside tmux emits a terminal
    /// STREAM — escape codes, spinners, redraws. Speaking that aloud is gibberish and
    /// parsing it back into sentences is a losing game. So this app never reads the
    /// terminal: it types into the session, and it reads a channel Claude writes
    /// deliberately. A consequence worth stating plainly: it does not see command
    /// output, it sees what Claude chose to say. That is the design, not a gap.
    var replyPath = "~/session-output.txt"

    /// True when the host is a name rather than a literal address, which is the only
    /// case where the fallback means anything.
    var hostIsName: Bool {
        // Not a full IP parse — just "does this look like digits and dots".
        !host.isEmpty && host.contains(where: { $0.isLetter })
    }
}

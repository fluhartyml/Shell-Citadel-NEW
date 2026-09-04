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
    /// a command, the machine answers. `.tmux` hands what you type to a program already
    /// running in a tmux session, and reads its replies from a file that program writes.
    /// ⚠️ CALLED "tmux", NOT "Claude". His correction, 2026-09-04: "all users have tmux
    /// but not claude running in tmux."
    ///
    /// I had argued for "Claude" from his own rule that a label should name the
    /// CONSEQUENCE rather than the mechanism. That rule assumes the consequence is shared
    /// by whoever reads the label — and here it is not. "tmux" is a consequence for every
    /// user; "Claude" is a consequence for exactly one.
    enum Mode: String, Codable, CaseIterable, Sendable {
        case shell
        case tmux

        var title: String {
            switch self {
            case .shell: "Terminal"
            case .tmux: "tmux"
            }
        }
    }

    var mode: Mode = .shell

    /// The tmux session to hand messages to.
    ///
    /// ⚠️ `main` IS THE DEFAULT BECAUSE IT IS TMUX'S OWN. This read `claude` until he
    /// caught it, 2026-09-04: "all users have tmux but not claude running in tmux."
    /// A default is a recommendation to every user who reads it, and one that names his
    /// particular workflow is a recommendation nobody else can act on.
    var tmuxSession = "main"

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

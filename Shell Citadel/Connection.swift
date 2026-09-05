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
    ///
    /// ⚠️ EMPTY BY DEFAULT, AND THAT IS THE FIX. This was "My Mac" until 2026-09-04:
    /// "Dont suggest my mac instead suggest server or leave blank and use the address."
    /// The far end could be a Pi, a NAS, a VPS — anything with SSH — so a default that
    /// names one kind of machine is wrong for everyone it is wrong for, and invisible
    /// to the one person it happens to fit. Empty, and `title` falls back to the
    /// address, which is always true by construction.
    var name = ""

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

        /// ⚠️ THE OLD APP'S WORDS, RESTORED. 2026-09-04: "Mode section should have
        /// direct or attach to session." Better than "tmux" for the same reason "tmux"
        /// beat "Claude" — it says what the mode DOES without requiring you to know
        /// what is on the far end. Someone who has never heard of tmux can still tell
        /// which of these two they want.
        var title: String {
            switch self {
            case .shell: "Direct"
            case .tmux: "Attach to session"
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

    /// Where a Direct session begins.
    ///
    /// ⚠️ DIRECT MODE ONLY, AND THE REASON IS NOT A PREFERENCE. In Attach mode you are
    /// joining a session that is already running and already has a working directory.
    /// The only way to move it would be to type a `cd` into that session — which lands
    /// in the conversation as a command, in front of whoever is reading it. So this
    /// setting is not merely unused in Attach mode; it cannot exist there.
    ///
    /// Empty means "wherever the login lands", which is what a shell does anyway.
    var startFolder = ""

    /// Whether each message is prefixed with the time and the source tag.
    ///
    /// ⚠️ ATTACH MODE ONLY. A timestamp typed into a plain shell is garbage on the
    /// command line — it was removed from the old app for exactly that reason, so that
    /// Shell Citadel could still be "a purely dum terminal" (his words, 2026-09-04).
    ///
    /// It is kept as a toggle rather than always-on because Attach mode means "hand my
    /// typing to a long-running program", and that program might be a build, a REPL or
    /// a game server that wants the bytes untouched. The toggle is the only way out for
    /// them that does not mean abandoning the mode.
    ///
    /// ⚠️ OFF BY DEFAULT PER HIS FIX LIST, item 17 — which means a connection that was
    /// relying on stamps has to be switched on once. That is deliberate: a default is a
    /// recommendation to every user, and most of them are not talking to something that
    /// reads timestamps.
    var stampMessages = false

    /// Which voice reads this connection's output aloud. nil means the system voice.
    ///
    /// ⚠️ PER CONNECTION, AND THAT IS THE ENTIRE POINT. His idea, 2026-09-04: assign a
    /// different voice to each connection "so you could tell a different terminal tab was
    /// talking" — the voice becomes the tab's identity, and he knows which machine is
    /// speaking without looking at the screen. That is worth more to him than it sounds:
    /// he listens to this app from another room.
    ///
    /// ⚠️ nil BY DEFAULT, AND IT STAYS THAT WAY UNLESS HE PICKS. He has corrected the
    /// same mistake twice — never override the voice he set in his own OS settings. A
    /// per-connection voice is a CHOICE he makes here; the absence of a choice is not a
    /// licence to choose for him.
    var voiceIdentifier: String?

    /// True when the host is a name rather than a literal address, which is the only
    /// case where the fallback means anything.
    var hostIsName: Bool {
        // Not a full IP parse — just "does this look like digits and dots".
        !host.isEmpty && host.contains(where: { $0.isLetter })
    }

    /// A copy with the two fields that must be exact made exact.
    ///
    /// ⚠️ THE TWO FIELDS ARE NOT TREATED THE SAME, AND THAT IS THE WHOLE POINT.
    /// His rule, 2026-09-04: "it should parse the user name case sensitive and not save
    /// space bars, and save host names in lower case using legal charaters."
    ///
    /// He is describing SSH's own asymmetry, correctly:
    ///
    ///  • THE ACCOUNT'S CASE IS PRESERVED, THOUGH NOT FOR THE REASON THIS FILE FIRST
    ///    CLAIMED. I wrote that `MichaelFluharty` and `michaelfluharty` were different
    ///    accounts and that only one existed. He pushed back — "i thought M F always
    ///    worked, its just passwords that are case sensitive" — and he was right.
    ///    Checked against the live directory on 2026-09-04: `dscl . -read
    ///    /Users/MichaelFluharty` RESOLVES, because macOS looks accounts up
    ///    case-insensitively. A missing letter does not resolve, and that — a dropped
    ///    `l` in `michaelfuharty` — was the actual failure I had blamed on capitals.
    ///
    ///    The case is still preserved, for a reason that does survive: the far end is
    ///    often NOT a Mac. Linux accounts really are case sensitive, and this app is
    ///    deliberately agnostic about what it connects to. Preserving what he typed is
    ///    correct everywhere; lowercasing it would be correct only where it does not
    ///    matter.
    ///
    ///    His rule for what this function is actually for: the account "just cant
    ///    contain illegal characters, space bar is one."
    ///
    ///  • THE HOST IS NOT. DNS and mDNS are case insensitive, so `My-Mac.local` and
    ///    `my-mac.local` are the same machine. Lowercasing removes a difference that
    ///    cannot matter, which stops the same host being saved twice looking different,
    ///    and neuters the iOS keyboard's habit of capitalising the first letter.
    ///
    /// ⚠️ SPACES COME OUT OF BOTH, AND THAT IS FROM A REAL FAILURE. AutoFill overwrote
    /// his account with the display name stored beside the password — "michael fluharty",
    /// with a space — and sshd rejects that outright. A space in either field is never
    /// what anyone meant, and it is invisible on screen at the end of a line.
    func normalised() -> Connection {
        var copy = self

        // ⚠️ CASE PRESERVED. EVERYTHING UNIX CANNOT ACCEPT REMOVED.
        //
        // His rule, 2026-09-04: "i want the autosave not to allow typos it knows 100%
        // are typos (like errant spaces or illegal charaters as per unix)."
        //
        // The bar is his: 100% certain. A unix account name lives in a colon-delimited
        // line in /etc/passwd, so a colon is structurally impossible; a slash would make
        // it a path; whitespace and control characters cannot appear at all; and the
        // rest of what is stripped here are shell metacharacters that no account name
        // has ever legitimately contained. Removing those is not a guess about intent —
        // there is no intent they could serve.
        //
        // ⚠️ WHAT IS NOT STRIPPED MATTERS AS MUCH. Capitals stay, because the account is
        // case sensitive and some systems really do have them. Dots, hyphens and
        // underscores stay, because they are legal and common. This tidies what cannot
        // be right; it never improves what merely looks unusual.
        copy.username = username
            .filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_" }

        // A name cannot begin with a hyphen — every command that takes it would read it
        // as a flag.
        while copy.username.hasPrefix("-") { copy.username.removeFirst() }

        // Lowercased, and reduced to what is legal in a host name: letters, digits,
        // hyphen and dot. Anything else was a typo, a stray quote, or a keyboard being
        // clever, and none of those resolve.
        copy.host = host
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." }

        copy.name = name.trimmingCharacters(in: .whitespaces)
        copy.tmuxSession = tmuxSession.filter { !$0.isWhitespace }
        copy.startFolder = startFolder.trimmingCharacters(in: .whitespaces)
        copy.replyPath = replyPath.trimmingCharacters(in: .whitespaces)
        return copy
    }

    /// What to call this connection anywhere one is listed.
    ///
    /// ⚠️ NEVER EMPTY. With no name the address is the honest label, and with neither
    /// there is nothing to show but a placeholder — so this never returns "" and no
    /// caller has to handle that case.
    var title: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        if !host.isEmpty { return host }
        return "New connection"
    }
}

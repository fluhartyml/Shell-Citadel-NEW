//
//  DemoMode.swift
//  Shell Citadel
//
//  THE PROBLEM THIS SOLVES IS NOT A USER PROBLEM.
//
//  An App Review reviewer opens Shell Citadel, is shown a form asking for an address, an
//  account and a password, and has none of those. They have no machine of their own with
//  Remote Login switched on. So they see a form that does nothing, and an app that does
//  nothing is rejected as non-functional. This is an ordinary way SSH clients get turned
//  down and it has nothing to do with whether the app is any good.
//
//  Michael, 2026-08-27: "maybe a demo mode so we (or i) dont forget."
//  And on 2026-09-04, on why it had to come back into the rebuild: "that was a guard so
//  the app wouldnt get rejected."
//
//  WHY A MODE AND NOT REVIEW NOTES. Review notes are the other answer and they are worse
//  for one specific reason: they have to be written again, correctly, on every single
//  submission, by a man doing this alone who will do it on tired evenings. A mode is
//  written once and is still there in two years. His words are the whole argument —
//  "so we (or i) dont forget."
//
//  ── TWO RULES THIS FILE MUST NEVER BREAK ──────────────────────────────────────────
//
//  1. IT MUST NEVER LOOK LIKE A REAL CONNECTION. Not to a reviewer, not to a curious
//     user, not to Michael glancing at his own phone. Simulating a connection and
//     letting someone believe it is real is itself a rejection reason, and it would be
//     dishonest even if it were not. The banner is always on screen and never
//     dismissible.
//
//  2. NOTHING HERE MAY TOUCH THE NETWORK. No SSHSession, no sockets, no upload. The
//     demo is a script and a text field. If this file ever imports Citadel, something
//     has gone wrong.
//
//  ⚠️ THE SCRIPT WAS REWRITTEN FOR THIS APP, NOT COPIED FROM THE OLD ONE. The old script
//  walked through tabs, a connections list, `screen -S work` and a "Spoken text" setting
//  — none of which exist here yet. A demonstration that shows features the app does not
//  have is worse than no demonstration: a reviewer who looks for them and cannot find
//  them has been misled by the app itself. Every beat below is something this build
//  actually does.
//

import Foundation

enum DemoMode {

    /// Always visible while the demo is running. Deliberately blunt.
    ///
    /// Michael's wording, 2026-08-27: "maybe it obviously shows 'simulated connection...'
    /// or similar in any connection screen?" — and his word is the better one. "Demo"
    /// describes what WE are doing; "simulated connection" describes what the reader is
    /// looking at, which is the thing they must not be misled about.
    static let banner = "SIMULATED \u{2014} not connected, nothing is being sent"

    /// Shown wherever connection state is displayed.
    ///
    /// ⚠️ IT SAYS BOTH THINGS ON PURPOSE, AND THE SECOND HALF IS THE IMPORTANT ONE.
    ///
    /// The first attempt read "Simulated connection", and Michael took it apart in one
    /// sentence, 2026-08-27: "'simulated connection' would include connected and
    /// disconnected quite literally wouldnt it?"
    ///
    /// He is right. That phrase is a MODE label sitting in a STATE slot — it describes
    /// what kind of session this is, in the exact place that otherwise answers "am I
    /// connected?". And it is equally true whether the simulation is pretending to be up
    /// or pretending to be down, so it reports nothing about the only question that spot
    /// exists to answer.
    static let statusLabel = "Simulated \u{00B7} not connected"

    struct Beat {
        let kind: TranscriptLine.Kind
        let text: String
        /// Seconds to wait BEFORE this line appears.
        let delay: Double
    }

    /// ⚠️ EVERY BEAT IS SOMETHING THIS BUILD ACTUALLY DOES. If a feature is removed, its
    /// beat comes out the same day.
    static let script: [Beat] = [
        .init(kind: .status,
              text: "This is a demonstration. Nothing is connected and nothing is being sent. It walks through the setup once, so the steps are here when you need them.",
              delay: 0.3),

        .init(kind: .status,
              text: "On the machine you want to reach, switch on its SSH server. On a Mac that is System Settings, General, Sharing, Remote Login. It does not have to be a Mac \u{2014} anything running SSH works.",
              delay: 1.8),

        .init(kind: .status,
              text: "Then open Connection settings and fill in three things: the address, your account name, and your password.",
              delay: 1.6),

        .init(kind: .output,
              text: "Address    my-computer.local\nAccount    my-account\nPassword   \u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}",
              delay: 1.4),

        .init(kind: .status,
              text: "A name ending in .local follows the machine, so it keeps working when the address changes. The password goes into this device's Keychain and is never asked for again.",
              delay: 1.8),

        .init(kind: .status,
              text: "Both the account and the password are case sensitive, and the account is the short name \u{2014} the one the home folder is named after, not the full name on the login screen.",
              delay: 1.7),

        .init(kind: .status, text: "Connected.", delay: 1.2),

        .init(kind: .command, text: "$ who am i", delay: 1.3),
        .init(kind: .output, text: "my-account   ttys004   Sep  4 16:12", delay: 0.9),

        .init(kind: .command, text: "$ df -h /", delay: 1.4),
        .init(kind: .output,
              text: "Filesystem       Size   Used  Avail Capacity  Mounted on\n/dev/disk3s3s1  926Gi   12Gi  181Gi     7%    /",
              delay: 1.0),

        .init(kind: .status,
              text: "The working folder is remembered between commands, so cd sticks the way it does in any terminal.",
              delay: 1.4),

        .init(kind: .status,
              text: "That is Direct mode. The other mode, Attach to session, hands what you type to a program already running on that machine and reads its replies from a file that program writes.",
              delay: 1.8),

        .init(kind: .status,
              text: "The session belongs to the machine, not to this app \u{2014} so it keeps running when you close the app, lose signal, or walk into another room. Coming back picks up where you left off, and nothing written while you were away is skipped.",
              delay: 1.9),

        .init(kind: .status,
              text: "The plus beside the box sends a photo, a camera shot, or a scanned document. It goes straight to the machine and the path comes back \u{2014} nothing is uploaded anywhere else.",
              delay: 1.8),

        .init(kind: .output, text: "~/Uploads/scan-2026-09-04-161240.pdf", delay: 1.1),

        .init(kind: .status,
              text: "The microphone button lets you speak instead of type. Your words appear before they are sent, a pause sends them, and saying \u{201C}scratch that\u{201D} takes the last one back.",
              delay: 1.8),

        .init(kind: .status,
              text: "The speaker button reads new output aloud. The microphone goes deaf before the speaking starts, so the app never hears its own voice and send it back to you.",
              delay: 1.8),

        .init(kind: .status,
              text: "End of demonstration. Everything above was scripted and nothing left this device. Open Connection settings to reach a machine of your own.",
              delay: 1.7),
    ]

    /// What anything typed during the demo gets back.
    ///
    /// ⚠️ IT ANSWERS, AND THE ANSWER IS THAT NOTHING HAPPENED. Silence would read as a
    /// hung app, which is the very thing this mode exists to disprove.
    static func reply(to typed: String) -> String {
        "Nothing is connected, so that was not sent anywhere. Open Connection settings to add your own machine and use Shell Citadel for real."
    }
}

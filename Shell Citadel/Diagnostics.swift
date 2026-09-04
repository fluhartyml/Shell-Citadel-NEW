//
//  Diagnostics.swift
//  Shell Citadel
//
//  Step 0.3 of the roadmap, and the last of the floor.
//
//  ⚠️ WHY THIS EXISTS AT ALL, BEFORE THE APP DOES ANYTHING.
//
//  Every bug the previous Shell Citadel died with was a STATE question that nothing
//  could answer: which field holds the keyboard, is the microphone actually listening,
//  why did that connection fail, what redrew the composer while he was typing. Each one
//  was diagnosed by guessing, and on 2026-09-04 five consecutive guesses missed — three
//  of them expensive enough to roll the whole app back to older builds that had never
//  contained the cause.
//
//  Michael, asked whether he wanted this on screen or written where Claude could read
//  it: "you are the engineer not me." So: both, with the written record primary. He
//  should never have to describe a symptom or read a log out loud.
//
//  ⚠️ WHAT THIS IS NOT. It is not `print()`. Console output vanishes when the app is not
//  attached to Xcode, which is exactly when he is using it — on a phone, in another
//  room, on a device that has been unplugged for days. A record that only exists while a
//  developer is watching is a record that is never there when it matters.
//
//  ⚠️ NOTHING PRIVATE GOES IN HERE. No passwords, no host keys, no command text, no
//  transcript. This app's spine is that his data goes to his Mac and nowhere else, and a
//  diagnostic record is the classic place that promise gets broken by accident. Record
//  STATE and CAUSES — "auth failed, wrong password" — never the password.
//

import Foundation
import Observation

/// One recorded moment in the app's life.
struct DiagnosticEntry: Identifiable, Sendable {
    let id = UUID()
    let at: Date
    let area: Diagnostics.Area
    let message: String

    /// `08:42:17.331  focus  composer took the keyboard`
    var line: String {
        let t = DiagnosticEntry.stamp.string(from: at)
        return "\(t)  \(area.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0))  \(message)"
    }

    /// Milliseconds matter here. The old caret bug was a ~2 second periodic revert, and
    /// the period is what identified it — a record without sub-second resolution would
    /// have shown the same five lines with no rhythm in them.
    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}

/// The app's memory of what it has been doing.
///
/// Deliberately tiny and deliberately always-on. A diagnostic facility that has to be
/// switched on before it is useful is off at the moment the bug happens.
@Observable
final class Diagnostics {

    /// The areas worth recording, chosen from what actually went wrong before.
    enum Area: String, Sendable, CaseIterable {
        case focus       // who holds the keyboard — the bug that ended the last app
        case mic         // listening or not
        case speech      // speaking or not; half duplex depends on knowing both
        case connection  // connecting, connected, closed, and WHY
        case app         // launch, foreground, background
    }

    static let shared = Diagnostics()

    /// The rolling record. Newest last.
    ///
    /// 500 entries is minutes of ordinary use and a few seconds of a tight loop — and a
    /// tight loop is precisely the shape of the bug this is for, so the cap must not be
    /// so small that a runaway erases its own beginning.
    private(set) var entries: [DiagnosticEntry] = []
    private let cap = 500

    // MARK: - Live state, for the About screen

    /// What currently holds the keyboard, in words. "composer", "none", "settings.host".
    private(set) var focusOwner = "none"

    private(set) var isListening = false
    private(set) var isSpeaking = false
    private(set) var connection = "not connected"

    /// The last failure, kept separately because it is the first thing anyone asks for
    /// and it must survive being pushed out of the rolling record.
    private(set) var lastError: String?

    private init() {
        record(.app, "launched · build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?") · commit \(BuildStamp.commit)")
    }

    // MARK: - Recording

    func record(_ area: Area, _ message: String) {
        let entry = DiagnosticEntry(at: Date(), area: area, message: message)
        entries.append(entry)
        if entries.count > cap { entries.removeFirst(entries.count - cap) }
    }

    /// Focus changes are recorded with the OWNER, not just "changed", because the whole
    /// question in the old app was *who* took it.
    func focusChanged(to owner: String) {
        guard owner != focusOwner else { return }
        record(.focus, "\(focusOwner) -> \(owner)")
        focusOwner = owner
    }

    func micChanged(listening: Bool) {
        guard listening != isListening else { return }
        isListening = listening
        record(.mic, listening ? "listening" : "stopped")
    }

    func speechChanged(speaking: Bool) {
        guard speaking != isSpeaking else { return }
        isSpeaking = speaking
        record(.speech, speaking ? "speaking" : "finished")
    }

    func connectionChanged(_ state: String) {
        guard state != connection else { return }
        connection = state
        record(.connection, state)
    }

    /// Say the real reason. "Could not reach the server" for every possible cause is what
    /// turned one wrong IP address into an hour of guessing on 2026-09-04.
    func failed(_ area: Area, _ reason: String) {
        lastError = reason
        record(area, "FAILED: \(reason)")
    }

    // MARK: - Handing it over

    /// The whole record as text, ready to be written to the Mac or put on a pasteboard.
    var report: String {
        var out = ["Shell Citadel diagnostics",
                   "build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?") · commit \(BuildStamp.commit) · built \(BuildStamp.built)",
                   "focus: \(focusOwner) · mic: \(isListening ? "on" : "off") · speech: \(isSpeaking ? "on" : "off") · connection: \(connection)"]
        if let lastError { out.append("last error: \(lastError)") }
        out.append("")
        out.append(contentsOf: entries.map(\.line))
        return out.joined(separator: "\n")
    }
}

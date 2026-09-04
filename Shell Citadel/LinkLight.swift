//
//  LinkLight.swift
//  Shell Citadel
//
//  A traffic light for the link, and a clock for the wait.
//
//  Michael, 2026-08-27: "Something simple like a red nosignal yellow some interference
//  and green for all is functional" — and again on 2026-09-04, with the states he
//  actually wants: "red disconnected light bulb, green connected lightbulb, and yellow
//  waiting for a response lightbulb with animated count up."
//
//  ⚠️ WHY A HEARTBEAT AND NOT A FLAG. The app has a boolean set when the handshake
//  succeeds and cleared when something throws. That is not the same as "the link works
//  now", and the gap between them is exactly where sessions get lost:
//
//    A TCP socket does not announce its own death. When the phone locks, or wifi hands
//    off between rooms, or cellular drops for a moment, the socket is gone and NEITHER
//    END KNOWS. Nothing throws. The flag stays true. The next thing he types goes into a
//    pipe with no other end, and he finds out by waiting for a reply never coming.
//
//  So green cannot mean "nothing has gone wrong yet" — that is the state that lies to
//  him. Green means VERIFIED RECENTLY, which requires traffic of our own.
//
//  ⚠️ WHY NOT MEASURE THE REPLY CHANNEL INSTEAD. It is the obvious idea and it is wrong.
//  The reply file is a long-lived stream and silence on it is the NORMAL case — the far
//  end simply is not talking. A quiet stream and a dead stream look identical from here,
//  which is the very confusion this exists to end.
//
//  ⚠️ WHAT YELLOW MAY AND MAY NOT CLAIM. His reason for asking, in his own words:
//  "because you take forever to respond." The app has NO WAY to know whether the far end
//  is thinking, stuck, or dead. All it knows is that a message went out at time T and
//  nothing has come back.
//
//  So it must never say "Claude is typing". That is a claim about the far end this side
//  cannot support, and a confident animation over a dead session is the false-green this
//  project keeps hunting down. It says it is WAITING, and it shows the clock. The
//  elapsed number is the honest part: forty seconds reads as thinking, four minutes
//  reads as go and look. That answers his real question — is it locked up? — better than
//  a spinner, which spins just as smoothly either way.
//
//  COST. One `printf` every ten seconds: open an exec channel, write two bytes, close.
//  Chosen over `true` so there is output proving the round trip completed rather than
//  merely opened.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class LinkLight {

    enum Quality {
        /// Disconnected, or the link failed its last check.
        case red
        /// Connected, and a message is out with no reply yet.
        case yellow
        /// Connected and verified inside the last interval.
        case green

        var color: Color {
            switch self {
            case .red: .red
            case .yellow: .yellow
            case .green: .green
            }
        }

        /// ⚠️ EVERY ONE OF THESE SAYS WHAT IT MEANS FOR HIM, not what the app is doing.
        /// "No signal" is a fact about the app; "nothing you send will arrive" is the
        /// consequence, and the consequence is the part worth reading.
        var summary: String {
            switch self {
            case .red: "No signal \u{2014} nothing you send will arrive."
            case .yellow: "Sent. Waiting for a reply."
            case .green: "Connected, checked in the last few seconds."
            }
        }
    }

    private(set) var quality: Quality = .red

    /// When the outstanding message was sent, or nil if nothing is outstanding.
    ///
    /// ⚠️ A DATE, NOT A COUNTER. Nothing in this object ticks. The view derives the
    /// elapsed seconds from this when it draws — see WaitingClock — so there is no timer
    /// here waking the app up or invalidating anything.
    private(set) var waitingSince: Date?

    /// Milliseconds for the last successful round trip, if there was one.
    private(set) var roundTrip: Int?

    private var missed = 0
    private var beat: Task<Void, Never>?
    private let interval: Duration = .seconds(10)

    // MARK: - The beat

    func start(pinging session: SSHSession) {
        stop()
        quality = .green
        missed = 0
        beat = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pulse(session)
                try? await Task.sleep(for: self?.interval ?? .seconds(10))
            }
        }
    }

    func stop() {
        beat?.cancel()
        beat = nil
        waitingSince = nil
        roundTrip = nil
    }

    func markDown() {
        stop()
        quality = .red
        Diagnostics.shared.connectionChanged("link down")
    }

    /// A message has gone out and its answer has not arrived.
    func didSend() {
        waitingSince = Date()
        if quality == .green { quality = .yellow }
    }

    /// Something came back on the reply channel.
    func didReceive() {
        waitingSince = nil
        if quality == .yellow { quality = .green }
    }

    private func pulse(_ session: SSHSession) async {
        let started = Date()
        let answer = try? await session.run("printf ok")
        guard answer?.contains("ok") == true else {
            missed += 1
            // ⚠️ TWO MISSES, NOT ONE. A single dropped beat is ordinary on wifi handing
            // off between rooms, and going red for it would make the light cry wolf
            // until he stopped reading it.
            if missed >= 2 { markDown() }
            return
        }
        missed = 0
        roundTrip = Int(Date().timeIntervalSince(started) * 1000)
        // ⚠️ A GOOD BEAT DOES NOT CLEAR A WAIT. The link being alive and the far end
        // having answered are different facts, and collapsing them is how a green light
        // ends up sitting over a question nobody replied to.
        if waitingSince == nil { quality = .green }
    }
}

/// The light itself, plus the clock when there is something to wait for.
struct LinkLightView: View {
    let light: LinkLight

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(light.quality.color)
                .font(.footnote)

            if let since = light.waitingSince {
                WaitingClock(since: since)
            }
        }
        .accessibilityLabel(light.quality.summary)
        .help(light.quality.summary)
    }
}

/// Seconds since the message went out, counting up.
///
/// ⚠️ TimelineView, AND THE REASON IS A BUG THAT COST A DAY. The old app drew its
/// waiting indicator from a Timer that invalidated a view containing the terminal. That
/// redraw is what let `TerminalKeyInput` call `becomeFirstResponder()` twice a second and
/// take the keyboard away from whatever he was typing into — the cursor that appeared and
/// vanished.
///
/// The key catcher is gone and the composer is the only view that ever takes focus, so
/// that specific bug cannot return. This is belt as well: a TimelineView redraws ITSELF
/// on the schedule and nothing above it, so the ticking cannot reach the composer at all.
private struct WaitingClock: View {
    let since: Date

    var body: some View {
        TimelineView(.periodic(from: since, by: 1)) { context in
            let elapsed = Int(context.date.timeIntervalSince(since))
            Text(label(for: elapsed))
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    /// ⚠️ IT NEVER SAYS THE FAR END IS TYPING. This side cannot know that. It reports
    /// the one thing it does know — how long the wait has been — and lets him judge it.
    private func label(for seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

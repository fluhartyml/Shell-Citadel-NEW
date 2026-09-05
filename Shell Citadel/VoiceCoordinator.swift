//
//  VoiceCoordinator.swift
//  Shell Citadel
//
//  ⚠️ HALF DUPLEX. THE MICROPHONE IS DEAF WHILE THE APP IS TALKING, AND THIS FILE IS THE
//  ONLY PLACE THAT DECIDES IT.
//
//  ── WHY IT IS ITS OWN FILE, AND WHY IT IS HERE BEFORE THE MICROPHONE IS ───────────
//  In the old app the speaker and the microphone each managed themselves, and the rule
//  that they must not both be live was a promise rather than a mechanism. It failed
//  twice, in the same shape, months apart:
//
//    • 2026-08-31: the phone spoke, heard itself, transcribed itself and SENT it. His
//      own reply came back as his next message, word for word. A conversation with
//      nobody in it.
//    • 2026-09-04: it happened again, through AIRPODS, while he was cleaning. My replies
//      arrived twice as his messages — "That's my own text coming back again."
//
//  ⚠️ AIRPODS DO NOT PREVENT THIS, and that is the trap. A headset feels like it should
//  isolate the speaker from the microphone, and it mostly does — until it does not, and
//  then the loop is silent, invisible and looks exactly like the user talking.
//
//  ── WHAT THIS ENFORCES ────────────────────────────────────────────────────────────
//  One owner of the audio path at a time, decided in one place, the same way one view
//  owns the keyboard (step 0.2). Speaking ALWAYS wins over listening: the app stops
//  listening BEFORE the first word, not after the last one, because "after" is exactly
//  the window in which it hears itself.
//
//  ── WHAT IT PUTS BACK, AND WHAT IT STILL WILL NOT ─────────────────────────────────
//  ⚠️ THIS SECTION USED TO SAY IT NEVER RESUMES LISTENING, and that sentence caused a
//  bug he found on 2026-09-05: "i press the mic to unmute it, it says listening, then
//  toggles mute back on."
//
//  The sequence was: he taps unmute → the mic opens → the app announces "Listening" →
//  `willSpeak()` closes the mic for the announcement → speech ends → nothing reopens it.
//  **The preamble killed the thing it was announcing**, every time, and the icon flipping
//  back to muted was the app correctly reporting a mic it had closed itself.
//
//  The distinction that was missing: WHO closed it.
//
//    • The USER muted → it stays muted. Unchanged, and still the rule. Re-arming a
//      microphone the user turned off is exactly the thing that must never be inferred.
//    • THIS FILE closed it to speak → this file opens it again. That is not inferring a
//      preference; it is returning something it borrowed a second ago without asking.
//
//  It reopens after a short grace rather than instantly, because the moment right after
//  the last word is precisely when the room still carries it — see the two loops above.
//

import Foundation
import Observation

@MainActor
@Observable
final class VoiceCoordinator {
    static let shared = VoiceCoordinator()

    /// What currently owns the audio path.
    enum Owner: String {
        case idle
        case speaking
        case listening
    }

    private(set) var owner: Owner = .idle

    /// Set by whoever turns the microphone on, so the coordinator can put it back the
    /// way the user had it rather than guessing. False means nothing wants the mic.
    private var listenerWantsMic = false

    /// True only when THIS file closed the microphone in order to speak.
    ///
    /// ⚠️ THE WHOLE FIX HANGS ON THIS ONE BOOLEAN. Without it, a mic the app closed and
    /// a mic the user closed are indistinguishable, and the safe-looking choice — leave
    /// it off — silently cancels an unmute he just made.
    private var silencedForSpeech = false

    /// How long to wait after the last word before opening the microphone again.
    ///
    /// ⚠️ NOT ZERO, AND THAT IS THE POINT. The instant after speech ends is exactly when
    /// the room, the AirPods, or a speakerphone still carries it — which is how the app
    /// heard itself twice and sent its own words back as his. Long enough for the tail to
    /// die, short enough that he is not talking into a mic that is not open yet.
    private let graceAfterSpeech: Duration = .milliseconds(600)

    /// Cancels a pending reopen if something changes its mind in the meantime.
    private var reopenTask: Task<Void, Never>?

    private var stopListening: (() -> Void)?
    private var startListening: (() -> Void)?

    private init() {}

    /// Registered once by the microphone, so this file can silence it without importing
    /// speech recognition and without the microphone importing the synthesiser.
    func registerListener(start: @escaping () -> Void, stop: @escaping () -> Void) {
        startListening = start
        stopListening = stop
    }

    // MARK: - The rule

    /// Call BEFORE the first word is spoken, never after.
    func willSpeak() {
        // A reopen from a previous utterance must not fire in the middle of this one.
        reopenTask?.cancel()
        reopenTask = nil

        if owner == .listening {
            listenerWantsMic = true
            silencedForSpeech = true
            stopListening?()
            Diagnostics.shared.record(.mic, "silenced for speech — will reopen after")
        }
        owner = .speaking
        Diagnostics.shared.speechChanged(speaking: true)
    }

    func didFinishSpeaking() {
        owner = .idle
        Diagnostics.shared.speechChanged(speaking: false)

        // ⚠️ ONLY WHAT THIS FILE CLOSED. If the user muted at any point — including
        // while the app was speaking — `didStopListening` has already cleared this, and
        // the microphone stays off.
        guard silencedForSpeech, listenerWantsMic else { return }
        silencedForSpeech = false

        reopenTask = Task { [weak self] in
            try? await Task.sleep(for: self?.graceAfterSpeech ?? .milliseconds(600))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                // Re-checked after the wait rather than before it: he may have muted, or
                // something else may have started speaking, during those 600ms.
                guard self.listenerWantsMic, self.owner == .idle else {
                    Diagnostics.shared.record(.mic, "reopen skipped — state changed during the grace")
                    return
                }
                self.owner = .listening
                self.startListening?()
                Diagnostics.shared.record(.mic, "reopened after speech")
            }
        }
    }

    // MARK: - The microphone's side

    func willListen() {
        owner = .listening
        listenerWantsMic = true
        Diagnostics.shared.micChanged(listening: true)
    }

    /// The user turned the microphone off. That outranks anything this file intended.
    func didStopListening() {
        if owner == .listening { owner = .idle }
        listenerWantsMic = false
        // ⚠️ CANCELS A PENDING REOPEN. Muting during the app's own announcement must not
        // be undone 600ms later by a task that was scheduled before he decided.
        silencedForSpeech = false
        reopenTask?.cancel()
        reopenTask = nil
        Diagnostics.shared.micChanged(listening: false)
    }

    /// True when it is safe to open the microphone at all.
    var canListen: Bool { owner != .speaking }
}

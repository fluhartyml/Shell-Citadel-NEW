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
//  ── WHAT IT DELIBERATELY DOES NOT DO ──────────────────────────────────────────────
//  It does not resume listening automatically when speech ends. Whether the microphone
//  comes back on is the user's state, not the synthesiser's, and quietly re-arming a
//  microphone is the kind of thing that should never be inferred.
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
    /// way the user had it rather than guessing. Nil means nothing wants the mic.
    private var listenerWantsMic = false

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
        if owner == .listening {
            // Remember that the user had the mic on, so nothing is lost — but do not
            // re-arm it automatically. See the note at the top.
            listenerWantsMic = true
            stopListening?()
            Diagnostics.shared.record(.mic, "silenced for speech")
        }
        owner = .speaking
        Diagnostics.shared.speechChanged(speaking: true)
    }

    func didFinishSpeaking() {
        owner = .idle
        Diagnostics.shared.speechChanged(speaking: false)
        if listenerWantsMic {
            Diagnostics.shared.record(.mic, "was on before speech; left off deliberately")
        }
    }

    // MARK: - The microphone's side

    func willListen() {
        owner = .listening
        listenerWantsMic = true
        Diagnostics.shared.micChanged(listening: true)
    }

    func didStopListening() {
        if owner == .listening { owner = .idle }
        listenerWantsMic = false
        Diagnostics.shared.micChanged(listening: false)
    }

    /// True when it is safe to open the microphone at all.
    var canListen: Bool { owner != .speaking }
}

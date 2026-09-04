//
//  SpokenOutput.swift
//  Shell Citadel
//
//  Roadmap step 3 — it reads new output aloud as it arrives.
//
//  Michael, 2026-08-31: "If citadel says everything the server puts on the screen it
//  covers if claude says anything via the terminal and being hands free i can talk back."
//
//  ⭐ WHY IT MATTERS MORE THAN CONVENIENCE. On 2026-08-29 he spent thirty-five minutes
//  alone at 183–208 bpm. At that rate typing is hard and talking is not. A terminal that
//  speaks and listens is the difference between reaching someone and not.
//
//  ⚠️ THIS IS NOT THE SIRI VOICE, AND THE DIFFERENCE IS NOT COSMETIC. Apple does not
//  expose Siri's voices to third-party synthesis. AVSpeechSynthesizer can use any voice
//  the user has DOWNLOADED, including Enhanced and Premium ones, but not Siri's. He
//  spent an afternoon on 2026-08-31 trying to reach one specific voice — do not let a
//  future session tell him this file delivers it.
//
//  ⚠️ NO VOICE OVERRIDE. Use whatever voice the system is set to. His standing rule,
//  after correcting it twice: the voice is his choice in OS settings, not the app's.
//
//  ⚠️ OFF BY DEFAULT. A terminal that starts talking the first time it is opened, in
//  whatever room it was opened in, is a bad surprise. And it is PER-DEVICE — whether the
//  room is quiet is a fact about the device, not about the Mac being talked to. On in bed
//  on the phone; off on the iPad with someone in the room.
//
//  ⚠️ FOREGROUND ONLY, DELIBERATELY. Speaking with the app backgrounded or the screen
//  locked needs the `audio` background mode, which is a claim about the app that App
//  Review reads closely and which changes behaviour for everyone. Not added on a guess.
//

import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class SpokenOutput: NSObject, AVSpeechSynthesizerDelegate {

    static let shared = SpokenOutput()

    private enum Key {
        static let enabled = "spokenOutputEnabled"
    }

    /// Off until he turns it on, per device.
    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Key.enabled)
            if !isEnabled { stop() }
        }
    }

    private(set) var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()

    private override init() {
        isEnabled = UserDefaults.standard.bool(forKey: Key.enabled)
        super.init()
        synthesizer.delegate = self
    }

    /// Speaks a line of new output.
    ///
    /// ⚠️ THE MICROPHONE IS SILENCED BEFORE THE FIRST WORD, not after the last one.
    /// "After" is precisely the window in which the app hears itself, and that loop has
    /// bitten twice — once through a speaker and once through AirPods.
    func speak(_ text: String) {
        guard isEnabled else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        VoiceCoordinator.shared.willSpeak()

        #if os(iOS)
        // Duck other audio rather than stopping it, and mix, so a podcast or a call is
        // interrupted rather than killed.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        let utterance = AVSpeechUtterance(string: trimmed)
        // No voice is set, on purpose. See the note at the top of this file.
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        VoiceCoordinator.shared.didFinishSpeaking()
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            VoiceCoordinator.shared.didFinishSpeaking()
            #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            #endif
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            VoiceCoordinator.shared.didFinishSpeaking()
        }
    }
}

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

    /// Every voice installed for English, for the per-connection picker.
    ///
    /// ⚠️ READ FROM THE DEVICE, NEVER A HARDCODED LIST. What is installed differs by
    /// device and changes when he downloads the Enhanced and Premium voices — which he
    /// has none of yet, checked 2026-09-04. A fixed list would offer voices that are not
    /// there and hide the ones that are.
    static var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { $0.name < $1.name }
    }

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
    /// The voice to use, or nil for whatever the system is set to.
    ///
    /// ⚠️ SET FROM THE CONNECTION, NOT CHOSEN HERE. This object never picks a voice on
    /// its own — nil means AVSpeechSynthesizer uses the system voice, which is the one
    /// he set in his own OS settings and the one he has twice told me not to override.
    var voiceIdentifier: String?

    /// Say one short line in a given voice, so a name in a list becomes a sound.
    ///
    /// ⚠️ HIS IDEA, 2026-09-04: "can it automatically say hello for each tts voice you
    /// select or change to?" Picking from a list of names is otherwise blind — "Ava" and
    /// "Tom" tell you nothing about which one you can follow from another room, which is
    /// the only thing that matters to him about a voice.
    ///
    /// ⚠️ IT SPEAKS EVEN WHEN OUTPUT IS MUTED, AND THAT IS DELIBERATE. Choosing a voice
    /// IS asking to hear it; refusing because the speaker toggle is off would leave the
    /// control silent at the one moment it is being used on purpose. It does not touch
    /// `isEnabled`, so the mute is exactly where he left it afterwards.
    func preview(voiceIdentifier: String?) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: "Hello.")
        if let voiceIdentifier, let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        }
        // The microphone still has to go deaf first, or the sample lands back in the
        // composer as something he said.
        VoiceCoordinator.shared.willSpeak()
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        isSpeaking = true
        synthesizer.speak(utterance)
    }

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

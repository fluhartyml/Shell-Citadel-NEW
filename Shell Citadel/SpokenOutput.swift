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
//  ⚠️ THE VOICE IS PER CONNECTION, AND THE SYSTEM VOICE IS THE DEFAULT — NOT THE RULE.
//
//  This file used to say "NO VOICE OVERRIDE. Use whatever voice the system is set to,"
//  which was his standing rule from the Mac `say` days after correcting it twice. It was
//  superseded on 2026-09-04 by his own design: "the connection card should have tts voice
//  selecters", and a voice per connection so he can hear which tab is talking.
//
//  ⚠️ THE OLD SENTENCE OUTLIVED THE RULE AND COST A DAY OF SILENCE. It sat above a
//  `speakInternal` that quietly refused to set the voice, so build 66 could thread the
//  per-connection voice all the way through and still produce the system voice. He found
//  it from the outside on 2026-09-05: "Arthur selected but the selected voice is not
//  being used."
//
//  What survives of the old rule, and is still true: nil means the system voice, and nil
//  is the default. He is never given a voice he did not choose.
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

    /// Set when a chosen voice could not be used, so the interface can say why.
    private(set) var lastProblem: String?

    /// Every voice installed for English, for the per-connection picker.
    ///
    /// ⚠️ READ FROM THE DEVICE, NEVER A HARDCODED LIST. What is installed differs by
    /// device and changes when he downloads the Enhanced and Premium voices — which he
    /// has none of yet, checked 2026-09-04. A fixed list would offer voices that are not
    /// there and hide the ones that are.
    static var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            // ⚠️ ONLY VOICES THAT CAN ACTUALLY BE REBUILT FROM THEIR IDENTIFIER.
            //
            // `speechVoices()` lists voices the device knows ABOUT, which is not the same
            // as voices it can speak WITH — an undownloaded one is listed and then
            // returns nil from `AVSpeechSynthesisVoice(identifier:)`. Offering it means
            // he picks a name and the system voice comes out, which is exactly what he
            // hit: "i chose author and albert plays", then "now system is playing".
            //
            // A list that contains choices the app cannot honour is worse than a short
            // list. All 52 reconstruct on this Mac; his phone plainly has some that do
            // not, which is why the fault appeared there and not here.
            .filter { AVSpeechSynthesisVoice(identifier: $0.identifier) != nil }
            .sorted { ($0.name, $0.language) < ($1.name, $1.language) }
    }

    /// What to show in the picker.
    ///
    /// ⚠️ THE NAME ALONE IS NOT ENOUGH. Thirteen English names appear TWICE on this
    /// machine — Daniel, Samantha, Reed, Grandma and the rest — differing only by
    /// language or quality. A list with two identical rows cannot be chosen from, and the
    /// one he picks is a coin toss he did not know he was making.
    static func label(for voice: AVSpeechSynthesisVoice) -> String {
        var parts = [voice.name]
        parts.append(voice.language)
        if voice.quality == .premium { parts.append("Premium") }
        else if voice.quality == .enhanced { parts.append("Enhanced") }
        return parts.joined(separator: " \u{00B7} ")
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
    /// ⚠️ THE FALLBACK ONLY. The voice that matters travels WITH each utterance — see
    /// `speak(_:voice:)`. This is one object shared by every tab, so a voice parked here
    /// is the last connection's voice, spoken on behalf of all of them.
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
    /// Say something the APP is telling him, rather than something the far end said.
    ///
    /// ⚠️ IT IGNORES THE OUTPUT MUTE, LIKE `preview` DOES, AND FOR THE SAME REASON. The
    /// speaker toggle means "do not read the machine's output to me". "Listening" is not
    /// the machine's output — it is the app confirming an action he just took, at the one
    /// moment his eyes are not on the screen. Muting the far end must not mute the app's
    /// own acknowledgement.
    func announce(_ sentence: String) {
        let utterance = AVSpeechUtterance(string: sentence)
        if let voiceIdentifier, let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        }
        // ⚠️ THROUGH THE COORDINATOR, OR THIS IS THE ECHO BUG. "Listening" is announced
        // at the exact instant the microphone goes live, so without this the app says a
        // sentence directly into its own open mic and sends it back as something he
        // said. `willSpeak` stops the listener and remembers to restart it afterwards,
        // which is the half-duplex rule the whole audio design rests on.
        VoiceCoordinator.shared.willSpeak()
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func preview(voiceIdentifier: String?) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: "Hello.")
        if let voiceIdentifier {
            guard let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) else {
                // ⚠️ SAY SO RATHER THAN PLAYING SOMETHING ELSE. Falling back to the system
                // voice here is what made the picker look broken instead of unavailable.
                Diagnostics.shared.failed(.app, "voice unavailable: \(voiceIdentifier)")
                lastProblem = "That voice is not installed on this device. It can be added in Settings \u{203A} Accessibility \u{203A} Spoken Content \u{203A} Voices."
                return
            }
            utterance.voice = voice
            lastProblem = nil
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

    /// Say a line in a particular connection's voice.
    ///
    /// ⚠️ THE VOICE IS AN ARGUMENT BECAUSE THERE IS ONE SPEAKER AND SEVERAL TABS.
    ///
    /// It was a property, set when a tab connected. With one terminal that was the same
    /// thing; with tabs it is a bug — the last connection to be made silently became the
    /// voice of every other one. And the entire reason he wanted a voice per connection
    /// is to know which machine is talking while he is in another room, so a shared voice
    /// does not merely lose a preference, it removes the feature.
    func speak(_ text: String, voice: String? = nil) {
        let chosen = voice ?? voiceIdentifier
        speakInternal(text, voiceIdentifier: chosen)
    }

    private func speakInternal(_ text: String, voiceIdentifier: String?) {
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

        // ⚠️ THE VOICE IS APPLIED HERE, AND UNTIL 2026-09-05 IT WAS NOT.
        //
        // `speak(_:voice:)` resolved the connection's voice, handed it to this method,
        // and this method built the utterance without it — under a comment saying no
        // voice was set on purpose. That comment was true of the old rule (never
        // override his system voice) and was left in place when build 66 threaded the
        // per-connection voice through. The parameter was accepted, passed, and dropped.
        //
        // He caught it from the outside, which is the only way it could be caught:
        // "my iphone has Arthur selected but the selected voice is not being used."
        // Nothing failed, nothing warned, and the app spoke in the system voice while
        // the card displayed his choice.
        //
        // Same shape as the hands-free preamble the night before: produced, then
        // consumed by nobody. Worth remembering as a class of bug rather than two bugs.
        if let voiceIdentifier {
            if let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
                utterance.voice = voice
            } else {
                // ⚠️ SAY SO RATHER THAN FALL BACK IN SILENCE. An identifier that no
                // longer resolves — a voice deleted, or a connection synced from a device
                // that has one this device does not — is exactly the case that made the
                // picker look broken instead of unavailable.
                Diagnostics.shared.failed(.app, "voice unavailable, using the system voice: \(voiceIdentifier)")
                lastProblem = "That voice is not installed on this device. It can be added in Settings \u{203A} Accessibility \u{203A} Spoken Content \u{203A} Voices."
            }
        }

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

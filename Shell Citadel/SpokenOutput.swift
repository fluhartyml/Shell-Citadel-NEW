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

    /// How many utterances are still queued or speaking.
    ///
    /// ⚠️ A COUNT, NOT `synthesizer.isSpeaking`, AND THAT DISTINCTION COST A BUILD.
    /// Build 79 guarded the finish handler with `!synthesizer.isSpeaking` to stop the
    /// microphone reopening between sentences. It reads as true INSIDE the callback for
    /// the last utterance too, so the guard swallowed the final finish, the coordinator
    /// was never told speech had ended, and the microphone never came back: he pressed
    /// mic, heard "Listening", and watched the icon stay red with a slash.
    ///
    /// Counting what was handed to the synthesiser answers the real question — is
    /// anything left — without asking an API that is ambiguous at exactly the moment it
    /// matters.
    private var pending = 0

    /// The floor under `pending`.
    ///
    /// ⚠️ EVERY RELEASE OF THE MICROPHONE HANGS OFF ONE COUNTER REACHING ZERO, AND A
    /// COUNTER THAT ONLY GOES UP WHEN SOMETHING GOES WRONG IS A LATCH. Build 84 fixes the
    /// one cause we found — a refused audio session — but the shape of the failure is
    /// worse than the cause: ANY utterance that never reaches a delegate deafens the app
    /// permanently, and a mute cannot clear it because `didStopListening` only resets an
    /// owner of `.listening`, never `.speaking`. A force-quit was the sole recovery.
    ///
    /// So this does not trust the diagnosis. It asks the synthesiser directly: if work is
    /// outstanding and nothing is being spoken, the queue died, and the microphone is
    /// handed back regardless of why.
    ///
    /// ⚠️ TWO CONSECUTIVE OBSERVATIONS, NOT ONE, and that is deliberate. Reopening the mic
    /// while a reply is still being read out is the echo loop of 2026-08-31 and 2026-09-04
    /// — the app hearing itself and sending its own words back as his. A watchdog that is
    /// too eager recreates the worse bug, so it must be certain before it acts.
    private var watchdog: Task<Void, Never>?

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
        // ⛔ GIVE THE MICROPHONE BACK RATHER THAN HOLD IT FOR SPEECH THAT CANNOT HAPPEN.
        // `willSpeak()` has already closed the mic. If the session was refused there is
        // nothing to wait for, and waiting is what latched it shut.
        guard armAudioSession() else {
            lastProblem = "The audio could not be started, so nothing was spoken. Another app or a phone call may be holding it."
            VoiceCoordinator.shared.didFinishSpeaking()
            return
        }
        #endif
        isSpeaking = true
        pending += 1
        synthesizer.speak(utterance)
        armWatchdog()
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
        // ⛔ GIVE THE MICROPHONE BACK RATHER THAN HOLD IT FOR SPEECH THAT CANNOT HAPPEN.
        // `willSpeak()` has already closed the mic. If the session was refused there is
        // nothing to wait for, and waiting is what latched it shut.
        guard armAudioSession() else {
            lastProblem = "The audio could not be started, so nothing was spoken. Another app or a phone call may be holding it."
            VoiceCoordinator.shared.didFinishSpeaking()
            return
        }
        #endif
        isSpeaking = true
        pending += 1
        synthesizer.speak(utterance)
        armWatchdog()
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
        //
        // ⛔ AND IF IT IS REFUSED, STOP HERE. See `announce`.
        guard armAudioSession() else {
            lastProblem = "The audio could not be started, so nothing was spoken. Another app or a phone call may be holding it."
            VoiceCoordinator.shared.didFinishSpeaking()
            return
        }
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
        pending += 1
        synthesizer.speak(utterance)
        armWatchdog()
    }

    func stop() {
        watchdog?.cancel()
        watchdog = nil
        synthesizer.stopSpeaking(at: .immediate)
        pending = 0
        isSpeaking = false
        VoiceCoordinator.shared.didFinishSpeaking()
    }

    // MARK: - The audio session
    //
    // ⚠️ THREE COPIES OF THIS BECAME ONE, AND EVERY FAILURE IS NOW RECORDED. The three
    // call sites each did `try? setCategory(...)` and `try? setActive(true)` — six
    // swallowed errors in the one path where "nothing happened and nothing said why" was
    // the entire symptom. A `try?` on the line that arms the speaker is the reason a
    // silent app looked like an unexplained mystery on 2026-09-01 and again today.

    #if os(iOS)
    /// Arms the session for speech. Records rather than hides a refusal, and now
    /// REPORTS it, because recording a refusal the caller cannot see was half a fix.
    @discardableResult
    private func armAudioSession() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            // Duck other audio rather than stopping it, and mix, so a podcast or a call
            // is interrupted rather than killed.
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        } catch {
            Diagnostics.shared.failed(.app, "audio session category failed: \(error.localizedDescription)")
        }
        do {
            try session.setActive(true)
        } catch {
            // ⚠️ THIS IS THE ONE THAT MATTERS. If activation is refused, the utterance is
            // handed to the synthesiser and goes nowhere — no error, no sound, and the
            // interface showing "speaking".
            //
            // ⚠️ AND UNTIL BUILD 84 IT ALSO DEAFENED THE APP FOR GOOD. The utterance never
            // reached the synthesiser, so no delegate ever fired, so `pending` never came
            // back to zero, so the coordinator was never told speech had ended and the
            // microphone could never reopen. 2026-09-05: the mic badge sat yellow and
            // three taps of unmute only added to a count that could not come down.
            Diagnostics.shared.failed(.app, "audio session activation failed \u{2014} speech will be silent: \(error.localizedDescription)")
            return false
        }
        return true
    }

    /// Hands the audio back to whatever else wanted it.
    private func releaseAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            Diagnostics.shared.failed(.app, "audio session release failed: \(error.localizedDescription)")
        }
    }
    #endif

    // MARK: - The watchdog

    /// Started every time something is handed to the synthesiser; cancelled the moment the
    /// queue drains honestly.
    private func armWatchdog() {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            var stalled = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, let self else { return }
                guard self.pending > 0 else { return }

                if self.synthesizer.isSpeaking {
                    stalled = 0
                    continue
                }

                // Nothing is being spoken and work is still outstanding. Once could be the
                // gap before the queue starts; twice is a queue that is never coming back.
                stalled += 1
                guard stalled >= 2 else { continue }

                Diagnostics.shared.failed(.app, "speech queue stalled with \(self.pending) unfinished \u{2014} returning the microphone")
                self.pending = 0
                self.isSpeaking = false
                VoiceCoordinator.shared.didFinishSpeaking()
                #if os(iOS)
                self.releaseAudioSession()
                #endif
                return
            }
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            // ⚠️ ONLY WHEN THE WHOLE QUEUE IS DONE — the second echo loop, 2026-09-05.
            //
            // A reply is spoken as SEVERAL utterances in a row. This delegate fires after
            // each one, so telling the coordinator "finished" here reopened the microphone
            // BETWEEN sentences, and it heard the next sentence and sent it back as his.
            // He watched his own transcript fill with my words tagged HF.
            pending = max(0, pending - 1)
            guard pending == 0 else { return }

            watchdog?.cancel()
            watchdog = nil
            isSpeaking = false
            VoiceCoordinator.shared.didFinishSpeaking()
            #if os(iOS)
            releaseAudioSession()
            #endif
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            // A cancelled utterance must decrement too, or the count never reaches zero
            // and the microphone stays shut for good.
            pending = max(0, pending - 1)
            guard pending == 0 else { return }
            watchdog?.cancel()
            watchdog = nil
            isSpeaking = false
            VoiceCoordinator.shared.didFinishSpeaking()
        }
    }
}

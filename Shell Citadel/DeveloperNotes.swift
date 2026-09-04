//
//  DeveloperNotes.swift
//  Shell Citadel
//
//  Created 2026-09-04, on the first day of the rebuild.
//
//  ─────────────────────────────────────────────────────────────────────────────
//  WHAT THIS FILE IS
//  ─────────────────────────────────────────────────────────────────────────────
//  The project's own memory. It compiles to nothing and ships nothing — it exists
//  so that the reasoning behind this app lives INSIDE the app, next to the code it
//  explains, where it cannot be lost with a chat session or a summarised context.
//
//  This is the pattern the whole apartment grew out of: DeveloperNotes in-tree
//  first, then the apartment, then "read hello claude". The in-tree note is still
//  the closest one to the work.
//
//  Keep entries newest-LAST, dated, and in Michael's words wherever he said it
//  better than a paraphrase would.
//
//  ─────────────────────────────────────────────────────────────────────────────
//  WHY THIS PROJECT EXISTS — the rebuild, 2026-09-04
//  ─────────────────────────────────────────────────────────────────────────────
//  Michael: "Cita del is so messed up." / "We are going to start over from scratch."
//
//  The previous app is kept, not deleted, at ~/Developer.complex/Shell Citadel.OLD
//  It is the reference, not the foundation. Nothing is copied across without a
//  reason that is written down here.
//
//  What killed it was not one bug. It was that two views both wanted to hold the
//  keyboard, and every attempt to referee them was a guess that could not be
//  checked from the outside. Four rollbacks, three of them to builds that never
//  contained the cause.
//
//  ─────────────────────────────────────────────────────────────────────────────
//  DECISIONS ALREADY MADE — 2026-09-04
//  ─────────────────────────────────────────────────────────────────────────────
//
//  PLATFORMS. Multiplatform: a Mac app and an iOS app. His words: "I want to have
//  this a Mac app and an iOS app."
//
//  BUILD NUMBER. CURRENT_PROJECT_VERSION = `git rev-list --count HEAD`, written by
//  a post-commit hook, and SHOWN IN THE APP with the commit beside it.
//  This is not a preference. The old app reported "1.0 (1)" for every build ever
//  made, so a working iPad and three broken iPhones could not be told apart, and a
//  full day was spent guessing at a difference the app could have stated.
//  Michael: "you need to make sure it happens and you do not get complaicent."
//  Install it BEFORE the first device build — Workshop/Build-Number-Kit/.
//
//  DICTATION PAUSE = 1.5 SECONDS. Measured, twice, independently. He tried 1s
//  (it cut him off mid-sentence), 3s ("way too long"), 2s ("too long"), and landed
//  on "1.5 is a sweet spot" — the same value the old app's 2026-09-02 commit had
//  arrived at. The control is a Stepper, 0.5–5.0, HALF-second steps: anything
//  finer is false precision on how long a person takes to think.
//
//  ─────────────────────────────────────────────────────────────────────────────
//  ⛔ MISTAKES THE OLD APP MADE — do not repeat them here
//  ─────────────────────────────────────────────────────────────────────────────
//
//  1. TWO THINGS OWNING THE KEYBOARD.
//     An invisible UIKeyInput catcher in the terminal called becomeFirstResponder()
//     on every redraw, while a 0.5s timer kept redrawing. With a sheet open it took
//     the keyboard back off his field about twice a second: "i tab the box to type
//     my name it has a cursor once and then it dissapears."
//     ⛔ window?.isKeyWindow DOES NOT DETECT A SHEET — a UIKit sheet is presented
//        inside the same window, so the test can never fail.
//     ⛔ rootViewController?.presentedViewController is also wrong — it is non-nil
//        whenever anything is presented anywhere, which blocked typing entirely.
//     → DESIGN SO THAT ONE THING OWNS FIRST RESPONDER. Do not add a second
//       invisible responder and then try to referee it.
//
//  2. AUTOFILL TAKES THE FIELD.
//     .textContentType(.username) beside .password makes iOS treat the pair as a
//     login form and drive AutoFill, which takes the field over. And AutoFill fills
//     a CREDENTIAL, not a field: tapping it on the password overwrote his user name
//     with the stored display name — "michael fluharty", with a space, which SSH
//     rejects. The convenience cost him the ability to sign in at all.
//
//  3. A FORMATTER-BOUND NUMERIC FIELD REFUSES EDITS.
//     TextField(value:format:) validates on every keystroke, so clearing it leaves
//     it briefly empty — not a number — and the binding writes the old value back.
//     "Port 22 doesnt let you tap it, it wont let you change from 22."
//     → Back numeric fields with a String; parse on the way out.
//
//  4. THE APP HEARD ITSELF.
//     With speech output on and the mic listening, replies were spoken, picked up,
//     and sent back as his own messages — twice in one session. Half duplex (shut
//     the mic before the first spoken word) is a requirement, not a refinement.
//     ⚠️ He listens on AirPods, so the loop is through a headset, not a speaker.
//
//  5. DELETING ONE CONNECTION DELETED ALL THREE.
//     Never diagnosed. Whatever stores connections here must be tested for it.
//
//  6. THE COMPOSER TRUNCATED AT ~24 CHARACTERS.
//     Never diagnosed either. Something redrew the field while he typed.
//     → INSTRUMENT, DO NOT GUESS. Five guesses in a row is what ended the old app.
//
//  ─────────────────────────────────────────────────────────────────────────────
//  ⛔ STANDING RULES FOR WORKING ON THIS APP
//  ─────────────────────────────────────────────────────────────────────────────
//  • LIGHTHOUSE'S TERMINAL IS THE EMERGENCY CHANNEL. Do not touch it, and do not
//    share code between it and this app. Its independence is the whole point:
//    when this app is broken, that one still reaches Claude.
//  • Answer, offer, stop. He gets overwhelmed by long replies and has said he
//    would stop using Claude over it. Say the answer, offer more, then wait.
//  • This Mac's LAN address moves (192.168.1.38 -> .63 overnight, 2026-09-04) and
//    every saved connection broke. Assume the address is wrong before assuming the
//    app is.
//

//  ═════════════════════════════════════════════════════════════════════════════
//  ROAD MAP
//  ═════════════════════════════════════════════════════════════════════════════
//
//  Michael, 2026-09-04: "i want you to have a section devoted to a road map of
//  shell Citadel[l] i want you to use shell citadel.old as a template."
//
//  Source: ~/Developer.complex/Shell Citadel.OLD/ROADMAP.md. That file is the
//  template, not the plan — the OLD app's order was right and its features were
//  wanted. What changed is that they were built onto a foundation that could not
//  hold them, so the sequence is kept and the foundation is not.
//
//  ─────────────────────────────────────────────────────────────────────────────
//  THE METHOD IS HIS, AND IT IS NOT NEGOTIABLE
//  ─────────────────────────────────────────────────────────────────────────────
//  Michael, 2026-08-22: "im loosing interest in this project — but — in order for
//  me to keep interest i want to chunk it into managable pieces."
//
//    • EACH CHUNK ENDS WITH SOMETHING HE CAN HOLD.
//    • NO CHUNK DEPENDS ON FINISHING THE ONE AFTER IT.
//    • ONE AT A TIME. His ruling, 2026-08-30, on the checklist: they get done one
//      at a time, not batched.
//
//  ─────────────────────────────────────────────────────────────────────────────
//  🛑 CHUNK 0 — THE FLOOR. Before any feature. New to this rebuild.
//  ─────────────────────────────────────────────────────────────────────────────
//  Not in the old roadmap, which is exactly why the old app ended the way it did.
//
//    0.1  BUILD NUMBER = COMMIT COUNT, installed and shown in About, BEFORE the
//         first build ever leaves the simulator. Workshop/Build-Number-Kit/.
//         The old app shipped ~95 builds that all called themselves "1.0 (1)".
//    0.2  ONE OWNER OF FIRST RESPONDER, decided and written down here before any
//         text input exists. The old app had two and never recovered.
//    0.3  A WAY TO SEE INSIDE IT. Whatever the app does to focus, audio, or the
//         connection must be observable from outside without guessing.
//         Five consecutive guesses is what ended the old app.
//
//  ─────────────────────────────────────────────────────────────────────────────
//  CHUNKS, CARRIED FORWARD IN HIS ORDER
//  ─────────────────────────────────────────────────────────────────────────────
//
//  1  TALKS TO THE MAC.
//     SSH, runs commands, prints real output, `cd` sticks, settings persist.
//     Done in the old app in nine commits, 2026-08-22. Verified by running
//     `who am i` and `ls` from the phone — that is the bar for "done" here too.
//     ⚠️ Assume the Mac's ADDRESS is wrong before assuming the app is: it moved
//        192.168.1.38 -> .63 overnight on 2026-09-04 and broke every connection.
//
//  2  IT LOOKS LIKE YOURS.
//     Icon built by him in Image Producer. Light + dark, NEVER tinted — his art.
//     Short, visual, makes it a product instead of a test harness.
//
//  2.5 📷 PHOTOS AND SCREENSHOTS, PHONE -> CLAUDE.
//     ⭐ HIS EXPLICIT PRIORITY, above both speech chunks. 2026-08-23: "stt and tts
//     is lower priority than getting a photo or screenshot from my phone to you."
//     Two needs landed on it the same morning: it is the missing EYE for the
//     homelab (Claude cannot see a cable, a label or an amber light), and it is
//     how he reports a bug from the couch with only a phone.
//     UI already decided, 2026-08-25: a "+" beside the predictive text boxes,
//     offering "image or scan" — VisionKit's document scanner gives deskew and
//     edge-crop free, same machinery as his own Snap&ScanKeeper.
//     ⛔ MAP BEFORE CODING — his standing rule. Transport is the easy half. The
//        real questions: where do files land so Claude finds them unprompted, and
//        HOW DOES CLAUDE LEARN ONE ARRIVED.
//     🔒 Privacy is the spine: the file goes to HIS Mac and nowhere else. No
//        service, no upload, no account. That must survive the feature intact.
//
//  3  IT SPEAKS THE ANSWER (TTS). Below 2.5 by his call, 2026-08-23.
//     ⛔ HALF DUPLEX IS PART OF THIS CHUNK, NOT A LATER REFINEMENT. The old app
//        spoke, its own mic heard it, and sent Claude's words back as his — twice
//        in one session, through AirPods. Shut the mic before the first word.
//
//  4  YOU SPEAK TO IT (STT). Back burner by his call, 2026-08-23 — but see HANDS
//     FREE below, which overtook it on 2026-08-31.
//     ✅ SETTLED: send-on-pause = 1.5s, Stepper 0.5–5.0 in HALF-second steps.
//
//  5  IT REACHES THE TMUX SESSION. Done out of order in the old app, 2026-08-22.
//     This is what makes it a Claude terminal rather than a shell.
//
//  6  SHIP IT.
//     🛑 UNITED STATES ONLY. App Store Connect -> Pricing and Availability -> the
//        United States and NOTHING else. 2026-08-27: "please be extra sure when we
//        submitt to app store connect that we only allow the united states be the
//        only region the app is available."
//        WHY IT IS NOT COSMETIC: an SSH client ships strong encryption, which is
//        US export-controlled. Selling only inside the US removes the whole class
//        of problem instead of managing it.
//        ⚠️ The default is EVERY territory, it is silent, and nothing warns you.
//        RE-CHECK AFTER EVERY SUBMISSION — the "add all territories" click is one
//        tap wide with no confirmation.
//        ✅ This is his general rule for all his apps, not a Shell Citadel
//           exception; this app has the encryption reason on top.
//
//  ─────────────────────────────────────────────────────────────────────────────
//  CARRIED-FORWARD ITEMS FROM THE OLD ROADMAP — wanted, not yet placed
//  ─────────────────────────────────────────────────────────────────────────────
//    💓 HEARTBEAT — asked 2026-08-24. Knowing the far end is alive.
//    📍 LOCATION PIN DROP + MAP SNAPSHOT — his idea, 2026-08-28. Location arrives
//       ONLY when he drops a pin; never ambient.
//    📱 THE iPHONE ULTRA REPLACES THE iPAD MINI — his statement, 2026-08-29.
//    📋 CHECKLIST — raised 2026-08-30, never started. One at a time, his ruling.
//    🎙️ HANDS FREE — his goal, stated plainly 2026-08-31: talk and listen with no
//       hands. This is the thing he actually wants the app for, and on 2026-09-04
//       it was the ONE part still working when everything else had failed.
//       ⭐ Treat it as the product, not a feature of it.
//
//  ─────────────────────────────────────────────────────────────────────────────
//  ⚠️ WHAT THE OLD ROADMAP DID NOT SAY, AND SHOULD HAVE
//  ─────────────────────────────────────────────────────────────────────────────
//  Every chunk above was DELIVERED in the old app. It still had to be abandoned.
//  The roadmap tracked features and never tracked whether the thing underneath
//  them still worked — so "hands free" was ticked off while he could not type his
//  own user name into the connection sheet.
//
//  → A CHUNK IS NOT DONE WHILE ANYTHING EARLIER IS BROKEN. Re-run chunk 1's test
//    (`who am i` from the phone) at the end of every chunk. If it fails, that is
//    the work, whatever the roadmap says is next.
//

import Foundation

/// Nothing here ships. See the notes above.
enum DeveloperNotes {}

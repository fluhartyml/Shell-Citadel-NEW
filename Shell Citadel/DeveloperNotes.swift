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
//  🔒 LOCKED — PLATFORMS. Multiplatform: a Mac app and an iOS app. His words: "I want to have
//  this a Mac app and an iOS app."
//
//  🔒 LOCKED — WHAT THE MAC APP IS FOR. Asked 2026-09-04, because macOS already has
//  Terminal and a second Terminal is not worth building. His answer:
//      "the mac app is the same as the iphone app but on the mac. it brings the
//       tabbed terminals and hands free use to a terminal"
//
//  ⭐ READ THAT AGAIN: HANDS FREE IS THE REASON THE MAC APP EXISTS.
//  Terminal.app has tabs. Terminal.app does not let him talk to it and hear it back.
//  So the Mac build is not a port with the phone's features trimmed off — the speech
//  half is the whole point of it, and anything that treats speech as the mobile
//  convenience has the product backwards on both platforms.
//
//  Consequence for the architecture: the terminal, the tabs, the speech in and the
//  speech out are all SHARED, and only the shells around them differ. Build them
//  platform-neutral from the first commit rather than lifting an iOS version later.
//
//  🔒 LOCKED — BUILD NUMBER. CURRENT_PROJECT_VERSION = `git rev-list --count HEAD`, written by
//  a post-commit hook, and SHOWN IN THE APP with the commit beside it.
//  This is not a preference. The old app reported "1.0 (1)" for every build ever
//  made, so a working iPad and three broken iPhones could not be told apart, and a
//  full day was spent guessing at a difference the app could have stated.
//  Michael: "you need to make sure it happens and you do not get complaicent."
//  Install it BEFORE the first device build — Workshop/Build-Number-Kit/.
//
//  🔒 LOCKED — DICTATION PAUSE = 1.5 SECONDS. Measured, twice, independently. He tried 1s
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
//  • This Mac's LAN address moves (one address -> .63 overnight, 2026-09-04) and
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
//  ─────────────────────────────────────────────────────────────────────────────
//  🔑 KEY — read this first, then skip anything marked LOCKED
//  ─────────────────────────────────────────────────────────────────────────────
//  His ask, 2026-09-04: "Put the key and the locked rec q back in so i can review
//  and skip the already locked in decsisions."
//
//    🔒 LOCKED       He has decided it. Do not re-open it, do not re-ask, do not
//                    offer alternatives. SKIP THESE WHEN REVIEWING.
//    ⭐ RECOMMENDED  What Claude thinks is next. A suggestion, not a decision —
//                    exactly one item carries this at a time.
//    ❓ QUESTION     Waiting on HIM. Nothing below it should be built until it is
//                    answered, and Claude must not answer it by assuming.
//    ⬜ OPEN         Wanted, unstarted, nothing blocking it.
//    ✅ DONE         Built AND verified by running it — not by compiling it.
//
//  ⚠️ A marker is a claim. ✅ means he saw it work. Anything Claude has only
//     built and not watched him use is ⬜, however finished it looks.
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
//  🛑 CHUNK 0 — THE FLOOR. ⭐ RECOMMENDED NEXT. New to this rebuild.
//  ─────────────────────────────────────────────────────────────────────────────
//  Not in the old roadmap, which is exactly why the old app ended the way it did.
//
//    0.1  🔒 LOCKED — BUILD NUMBER = COMMIT COUNT, installed and shown in About, BEFORE the
//         first build ever leaves the simulator. Workshop/Build-Number-Kit/.
//         The old app shipped ~95 builds that all called themselves "1.0 (1)".
//    0.2  🔒 LOCKED — ONE OWNER OF FIRST RESPONDER. Decided 2026-09-04, written
//         down BEFORE any text input exists, because the old app decided it by
//         accident and could never undo it.
//
//         THE RULE: THE COMPOSER IS THE ONLY VIEW IN THIS APP THAT EVER CALLS
//         becomeFirstResponder(). Nothing else. Not the terminal, not a hidden
//         catcher, not a tab bar, not a settings field.
//
//         WHAT THAT FORBIDS, EXPLICITLY:
//           ⛔ No invisible UIKeyInput view that exists only to hold the keyboard.
//              That is what TerminalKeyInput was, and it took the caret back off
//              whatever he had tapped on every single redraw — twice a second,
//              because a 0.5s timer kept redrawing the screen.
//           ⛔ No becomeFirstResponder() inside updateUIView or any other function
//              that runs on redraw. Taking focus is a RESPONSE TO AN EVENT — a tap,
//              a sheet closing, a connection opening — never a side effect of
//              drawing.
//           ⛔ No second responder "guarded" so the two can coexist. THE GUARD IS
//              THE TRAP. Two plausible guards were tried on 2026-09-03/04 and both
//              were wrong in ways that could not be seen from outside:
//                • window?.isKeyWindow — a UIKit sheet is presented INSIDE the same
//                  window, so this can never be false while a sheet is up. It let
//                  every theft through, and three rollbacks were spent looking for
//                  a cause that had already been "fixed".
//                • rootViewController?.presentedViewController — non-nil whenever
//                  ANYTHING is presented anywhere, so it blocked the keyboard
//                  permanently: "the keyboard does not work."
//              Both read like "is something on top of me". Neither answers it.
//
//         WHY A RULE INSTEAD OF A BETTER GUARD. A correct guard is possible — ask
//         the view's OWN controller, not the root's. But every guard has to be
//         right in every arrangement the app is ever put into, and it fails
//         SILENTLY and INVISIBLY when it is wrong: the symptom is a cursor that
//         blinks once, which looks identical to a broken text field. One owner
//         cannot have this class of bug at all.
//
//         IF THE TERMINAL LATER NEEDS RAW KEYSTROKES (arrow keys, control codes),
//         it gets them from the composer's own input handling, or from a keyboard
//         shortcut layer that does not hold first responder. Not from a second
//         responder., decided and written down here before any
//         text input exists. The old app had two and never recovered.
//    0.3  🔒 LOCKED — A WAY TO SEE INSIDE IT.
//         Michael, 2026-09-04, when asked which form he wanted: "you are the engineer
//         not me." So this is Claude's call, and it is made.
//
//         THE APP KEEPS A ROLLING RECORD OF ITS OWN STATE and can hand it over:
//           • WHAT IS RECORDED — who owns first responder, whether the mic is
//             listening, whether speech is playing, connection state, and the last
//             error with its real reason. Every entry timestamped.
//           • WHERE IT GOES — written to the Mac over the connection the app already
//             has. He should never have to describe a symptom or read a log aloud.
//           • WHAT HE SEES — a Diagnostics row in About showing the same values live,
//             for when there is no connection to write over. Selectable, like the
//             build number, so it can be read out if it comes to that.
//
//         WHY IT IS CHUNK 0 AND NOT A LATER NICETY. Every one of the old app's
//         unresolved bugs — the caret dying, the 24-character truncation, three
//         connections deleting at once, "Done Done Done" — was a state question that
//         nothing could answer. FIVE CONSECUTIVE GUESSES ENDED THAT APP. The cost of
//         building this is hours; the cost of not building it was the project.
//
//  ─────────────────────────────────────────────────────────────────────────────
//  CHUNKS, CARRIED FORWARD IN HIS ORDER
//  ─────────────────────────────────────────────────────────────────────────────
//
//  1  ⬜ OPEN — TALKS TO THE MAC.
//     SSH, runs commands, prints real output, `cd` sticks, settings persist.
//     Done in the old app in nine commits, 2026-08-22. Verified by running
//     `who am i` and `ls` from the phone — that is the bar for "done" here too.
//     🔒 LOCKED 2026-09-04 — ADDRESS BY NAME, WITH A REMEMBERED IP BEHIND IT.
//        Asked whether the Mac should get a fixed address. His answer: "sounds like an
//        engineering issue, i would as a layman say use his Mac's .local name."
//        ⭐ HE IS RIGHT, and the layman answer is the better engineering one: a Bonjour
//        name follows the machine, so the address moving stops mattering at all. Nothing
//        has to be configured on his router and nothing has to be remembered by him.
//
//        BUT THE NAME ALONE IS NOT ENOUGH, AND TODAY PROVED IT. .local is resolved by
//        mDNS, which does not work over cellular and can be swallowed by a VPN profile
//        that captures DNS. On 2026-09-04 the name failed and the app said "could not
//        reach the server" — the same sentence it says for every other cause.
//
//        SO: connect by NAME first, and if the name does not resolve, fall back to the
//        LAST ADDRESS THAT WORKED, which the app records every time it connects. Two
//        independent paths, no configuration, and the failure of one is invisible to him.
//        ⚠️ AND SAY WHICH ONE IT USED. "Could not reach" that cannot distinguish a DNS
//           failure from a dead host is what made this cost an hour.
//
//  2  ⬜ OPEN — IT LOOKS LIKE YOURS.
//     🔒 LOCKED: his icon, light + dark, NEVER tinted.
//     ⚠️ AND THE TWO FILES BEING IDENTICAL IS DELIBERATE — do not flag it again.
//        AppIcon-1024.png and AppIcon-1024-dark.png are byte-for-byte the same image
//        (sha 4385a033), carried over from Shell Citadel.OLD. Raised with him
//        2026-09-04: "i think that's designed that's OK." The icon reads the same in
//        both appearances by choice. A future session finding this must not "fix" it.
//     Icon built by him in Image Producer. Light + dark, NEVER tinted — his art.
//     Short, visual, makes it a product instead of a test harness.
//
//  2.5 📷 ⬜ OPEN — PHOTOS AND SCREENSHOTS, PHONE -> CLAUDE.
//     ⭐ HIS EXPLICIT PRIORITY, above both speech chunks. 2026-08-23: "stt and tts
//     is lower priority than getting a photo or screenshot from my phone to you."
//     Two needs landed on it the same morning: it is the missing EYE for the
//     homelab (Claude cannot see a cable, a label or an amber light), and it is
//     how he reports a bug from the couch with only a phone.
//     🔒 LOCKED 2026-09-04 — ALL THREE SOURCES: camera, photo library, document scan.
//        And they all port to the Mac. His words: "should all port except the location
//        pin drop." So the Mac gets photos and scanning; LOCATION PIN DROP IS iOS ONLY.
//        ⚠️ On the Mac, "camera" and "scan" both mean CONTINUITY CAMERA — his phone,
//           used from the Mac. That is the same phone in his hand either way, so the
//           feature is real there rather than a stub, but it is a different API path
//           and must not be assumed to fall out of the iOS work for free.
//     🔒 LOCKED — UI decided 2026-08-25: a "+" beside the predictive text boxes,
//     offering "image or scan" — VisionKit's document scanner gives deskew and
//     edge-crop free, same machinery as his own Snap&ScanKeeper.
//     ❓ QUESTION — MAP BEFORE CODING, his standing rule. Transport is the easy half. The
//        real questions: where do files land so Claude finds them unprompted, and
//        HOW DOES CLAUDE LEARN ONE ARRIVED.
//     🔒 Privacy is the spine: the file goes to HIS Mac and nowhere else. No
//        service, no upload, no account. That must survive the feature intact.
//
//  3  ⬜ OPEN — IT SPEAKS THE ANSWER (TTS). Below 2.5 by his call, 2026-08-23.
//     🔒 LOCKED — HALF DUPLEX IS PART OF THIS CHUNK, NOT A LATER REFINEMENT. The old app
//        spoke, its own mic heard it, and sent Claude's words back as his — twice
//        in one session, through AirPods. Shut the mic before the first word.
//
//  4  ⬜ OPEN — YOU SPEAK TO IT (STT). Back burner by his call, 2026-08-23 — but see HANDS
//     FREE below, which overtook it on 2026-08-31.
//     🔒 LOCKED: send-on-pause = 1.5s, Stepper 0.5–5.0 in HALF-second steps.
//
//  5  ⬜ OPEN — IT REACHES THE TMUX SESSION. Done out of order in the old app, 2026-08-22.
//     This is what makes it a Claude terminal rather than a shell.
//
//  6  ⬜ OPEN — SHIP IT.
//     🔒 LOCKED — UNITED STATES ONLY. App Store Connect -> Pricing and Availability -> the
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
//    ❓ 🖥️ THE MAC APP IS THE PHONE APP IN A WINDOW — his observation, 2026-09-04:
//       "the mac app is not really anything like an ipad or phone app." He is right.
//       One connection, a toolbar, a text field at the bottom: that is a phone screen
//       stretched, not a Mac app. What a Mac version wants is the connections in a
//       SIDEBAR, a real resizable window, and keyboard shortcuts.
//       ⚠️ NOT STARTED, AND NOT TO BE STARTED ON A GUESS. He raised it; he has not
//          asked for it. And it is worth remembering WHY the Mac app exists at all
//          (locked above): hands free in a terminal, which Terminal.app cannot do.
//          A sidebar does not serve that — so the ordering is his call, not mine.
//    ⬜ 💓 HEARTBEAT — asked 2026-08-24. Knowing the far end is alive.
//    ⬜ 📍 LOCATION PIN DROP + MAP SNAPSHOT — his idea, 2026-08-28. Location arrives
//       ONLY when he drops a pin; never ambient.
//    ⏸ 📱 THE iPHONE ULTRA — NOT A CONSTRAINT. Michael, 2026-09-04: "i dont have
//       an iphone ultra." The 2026-08-29 note was about a device he might buy, and it
//       was carried in the roadmap as though it were a fact about his hardware.
//       ⚠️ Apple's event is 2026-09-09. If it appears and he buys one, this becomes
//          real; until then BUILD AND TEST AGAINST WHAT HE ACTUALLY HAS:
//          iPhone 11 Pro · iPhone 14 Pro Max · iPhone 16e · iPad Pro 13" M4 · iPad mini 6.
//       → the standing rule this broke: do not build on implied or inferred device state.
//    ⬜ 📋 CHECKLIST — raised 2026-08-30, never started. One at a time, his ruling.
//    🔒 🎙️ HANDS FREE — his goal, stated plainly 2026-08-31: talk and listen with no
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

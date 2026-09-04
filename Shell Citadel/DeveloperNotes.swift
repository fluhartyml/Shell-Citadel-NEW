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

import Foundation

/// Nothing here ships. See the notes above.
enum DeveloperNotes {}

# Shell Citadel — shakedown fix list

Found by Michael running the app. Nothing here is fixed until he says it looks right.

⚠️ THIS FILE WENT STALE ONCE. It stopped at 7 items while the amber page he actually
reads grew to 27, because the later items were added to the page and not to this table.
The page is the surface; this table is the copy that ships in the repo, and they have to
agree. Full list: Workshop/Shell-Citadel-FIXLIST.html

Status: 🔨 built and wired, not yet seen working by him. ✅ only when he says so.
Items 1-20 are 🔨 as of build 27, commit 2a16713. Items 21-27 are screens the new app
has never had, so they are work to do rather than faults to fix.

| # | Status | Screen | What is wrong |
|---|--------|--------|---------------|
| 1 | [ ] | Connection sheet (Mac) | Labels clipped on BOTH sides — "Address" reads "ddress", "User name" reads "r name", the Mode footer cuts off mid-word. Content is wider than the sheet. |
| 2 | [ ] | Connection sheet (Mac) | Every field is doubled. "Name  My Mac" as text, then "My Mac" again inside the box. The placeholder renders outside the field instead of in it. |
| 3 | [ ] | Connection sheet (Mac) | Section headers are not headers. "The machine", "Sign in", "Mode" sit as plain text jammed against the paragraph above, so it reads as one wall. |
| 4 | [ ] | Connection sheet | Footers are paragraphs. Apple uses one short line or none. |
| 5 | [ ] | Everywhere | The app assumes the far end is a Mac — default name "My Mac", footer says "On a Mac, turn on Remote Login". It could be a Pi, a NAS, anything with SSH. |
| 6 | [x] | About sheet (Mac) | Collapsed to a tiny box; build number unreadable. Fixed, not yet seen working. |
| 7 | [x] | About sheet (Mac) | No way to close it. Done button added, not yet seen working. |

**Root cause of 1–3 is one thing:** the sheet is a `Form` written for iOS, and macOS lays a Form out differently.


---

## Not rebuilt yet — 14

**These are missing because I did not write them, not because they were dropped.**

His correction, 2026-09-04: *"the things that dont exist are what should be on your check
list, they are not there because they are not wanted, they are not there because you chose
not to code them."*

He is right, and the way it happened is worth recording. Rewriting the demo script "around
what the app actually does" quietly turned a list of unbuilt features into a list of
absent ones — the same preemptive scope cut he has called out before. Absence is not a
decision unless he made it.

| # | Missing | His words / why | Asked |
|---|---------|-----------------|-------|
| 28 | Saved connections — a library, not one | One shared list, each with a button that makes it live in the tab you are in. **Each card carries a `teletype` icon** — his call 2026-09-04, and it pairs with `phone.connection.fill` on the toolbar button that edits one. **Open question: whether the speech voice picker lives on the card or in Settings** — he said the card first, then that voices are set in settings, and I have not asked which he meant. | 2026-08-29 |
| 29 | Tabs | "we may need to add tab abilities to citadel so i can have multiple terminals open" — and the reason this is not just another SSH client | 2026-08-29 |
| 30 | A dumb terminal that is actually dumb | "I want a dumb terminal to be a dumb terminal" — no app voice, no transcript rows, no prompt glyph drawn by the app | 2026-08-29 |
| 31 | A real PTY session | Direct mode runs each command in a NEW shell over an exec channel; a PTY is one continuous shell, which is what makes interactive programs and Ctrl-C behave | 2026-08-29 |
| 32 | The link light | "red no signal, yellow some interference, green for all good" | 2026-08-27 |
| 33 | Errors turned into sentences | Written after he locked his phone walking in from the porch. This is why `SSHClientError 4` was on screen today instead of "the sign-in was rejected" | 2026-08-23 |
| 34 | Terminal appearance — font size, colour, background | "user configurable with mine given first launch as example" | 2026-08-29 |
| 35 | The Nerd Font | "the same nerd font im using in my terminal be the standard font in my apps" | 2026-08-29 |
| 36 | Settings — simple by default, Advanced behind a disclosure | The ordering was the argument: one machine should not require meeting everything else | 2026-08-29 |
| 37 | Type `ssh account@host` and it fills the sheet in | He typed it and got an empty list; the fix opens the sheet already filled, password the only thing left | 2026-08-29 |
| 38 | Siri intents | "Can siri intents work?" then "Use shell citadel hands free" — he answered his own question | 2026-08-31 |
| 39 | The passive queue | "we deed a passive queue." Partly here — the reply channel resumes by byte offset — but the marking of what has been heard is not | 2026-08-23 |
| 40 | A composer that does not help | Autocorrect, capitalisation and prediction genuinely off; a terminal command is not prose | 2026-08-29 |
| 41 | The location pin drop | iOS only by his ruling, listed so it is not mistaken for forgotten | 2026-09-04 |

## ⛔ Deliberately NOT rebuilt — 2

`TerminalKeyInput` and `WaitingIndicator` **were the cursor bug.** The invisible key
catcher called `becomeFirstResponder()` on every redraw, and the indicator ticked twice a
second to cause the redraws. Chunk 0.2 replaced both with one rule: the composer is the
only view that ever takes the keyboard. **These two stay gone** — and unlike everything
above, that is a decision, made because of what it cost.

## 🔨 Built 2026-09-05 — not yet seen working

| # | Status | Screen | What changed |
|---|--------|--------|--------------|
| 47 | 🔨 | Appearance | **The Size slider drives columns and lines.** His rule, given at 06:45 after being asked twice: *"it scales the font sizes bigger or smaller making the (height) lines and (width) colums increase or decrease."* So the size is the only stored geometry value and the counts are read off the layout, using the real character cell of the chosen face rather than the old `columns × size × 0.6` guess. The arrows on Columns and Lines run the opposite way and move the slider. **`Lines` is live again** — it was greyed out while a line count meant a PTY grid; under his rule it means how many lines fit down the screen, which the layout can answer today. Item 31 (the real PTY) is still owed, and is no longer what this control waits on. |

⚠️ **Found on the way and fixed in the same build:** the size, the font and all six colours
were written **up** to iCloud and never read back **down** — `pullFromCloud` read only the
pause. The file claimed all of them followed him between devices; one of them did.

| 48 | 💡 | Timestamp tag | **Mark hands-free messages in the tag.** His idea, 2026-09-05: *"when the tag is turned on it also indicates if it was a hands free message or a typed message. HF or no other, assume always typed unless the HF tag."* So `[13:31 SC-Mac HF]` for dictated, and the existing `[13:31 SC-Mac]` for typed — **absence means typed**, which keeps every message already sent correct. ⭐ **Why it is worth more than a label:** a dictated message carries transcription errors and a typed one does not. Claude currently cannot tell them apart, so it either over-reads a mis-transcription as intent or second-guesses something he actually typed. The tag says which kind of scrutiny to apply. |

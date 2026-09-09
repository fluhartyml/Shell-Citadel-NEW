# Shell Citadel — Developer Notes

Ideas and decisions captured as he says them. **Captured is not queued** — nothing here is started
unless he says so.

---

## 💡 MONITOR MODE — a locked phone on a charger that speaks

**Captured 2026-09-09 11:48–11:52. His idea, his name for it. NOTHING STARTED.**

### The goal, in his words

> ***"what i do is put my iPhone on its charger while streaming cryotunes. the screen is locked.
> what i was thinking is having another iPhone on a charger locked with shell citadel so i can hear
> you say something like at the middle of the night or in the morning"***

**A second iPhone, on a charger, screen locked, acting as a voice channel from Claude into the
room.** The 11 Pro is the obvious candidate — it is spare and it already carries build 94.

### ⭐ THE PRODUCT FRAMING IS HIS, AND IT IS BETTER THAN THE PERSONAL ONE

> ***"it would be a terminal monitoring mode for a sys admin to monitor their server while in bed
> or something."***

**This is not a personal workaround dressed up for review — it is a real feature with a real
audience.** A system administrator leaves a terminal watching a server and hears it from across the
room. **The bedside phone is one instance of it, not the point of it.**

**Two things that follow.** It is describable in review notes without apology. And it should be
BUILT as that feature — general, for any user watching any host — rather than shaped around his
bedroom and later widened.

⭐ **He supplied the proof it is possible in the same sentence.** CryoTunes Player streams with the
screen locked. **That is the audio background session doing exactly what this needs**, on his own
hardware, already working. **His analogy is the evidence, not an illustration.**

### The name and the shape — his correction, and it is the good one

> ***"so you toggle on the hands free wouldn't be used because it would be monitoring only. the
> toge should say monitor mode"***

**MONITOR MODE: output only. No microphone.** Hands-free dictation is explicitly NOT part of it.

**Why that is better than the obvious version:** a background mode holding the mic open is a much
harder thing to justify than one playing speech. **He cut the risky half out of his own feature
before anyone asked him to.** And the name is honest about what the phone is — **a speaker on a
charger, not a terminal you type into.**

### ⛔ Where it currently stands in the code

`TerminalView` carries: *"THE CONNECTION DOES NOT SURVIVE A LOCKED SCREEN. See
`standDownForBackground()`."* **Standing down on lock is deliberate, present behaviour.** Monitor
Mode is a change to that, not a gap to fill in.

### ⚠️ App Store compliance — HIS question, and it is unresolved

He asked directly: *"is ot App Store compliant?"*

**Guideline 2.5.4:** background modes may only be used for their intended purpose. **Holding a
silent audio session purely to keep a network connection alive is the pattern Apple rejects.**

**The argument FOR:** Shell Citadel genuinely reads replies aloud. **A speaking terminal that keeps
speaking while the screen is locked is audio doing audio's job.**

**The weak spot, unchanged by the toggle:** ⚠️ **the silence BETWEEN replies.** Overnight that could
be hours of an audio session with nothing playing. A user toggle shows intent and reviewers like it,
**but Apple looks at what the app does with the mode, not whether the user opted in.**

⚠️ **This is Claude reading the guideline, not a ruling anyone has seen on this case.**
**It matters more than usual because Shell Citadel is the App Store track app, not the playground.**
→ `project_lighthouse_two_tracks_personal_vs_asc`

### Open, and all his to answer
- Does the SSH stream actually survive alongside a background audio session? **Untested.**
- What happens overnight during long silence — does the session hold, and what does it cost the
  battery on a charger?
- Does Monitor Mode reconnect on its own if the link drops overnight? ⚠️ **The "never reconnect on
  its own" constraint is NOT his rule.** He said so, 2026-09-09: *"the rule you said was not mine, i
  probably agreed with you and restated it and you took it as a rule i cant be sure. rules change."*
  **Claude proposed it; he agreed in passing; it was written down in his voice and has been quoted
  back at him since.** It was reasoned for a phone in his pocket on cellular — **not a spare phone
  on a charger on his own Wi-Fi.** Treat it as open. → [[feedback_dont_launder_your_own_suggestion_into_his_rule]]

### Decisions taken 2026-09-09 11:58–12:00

- **The toggle is not technically required** — the session could simply always be held. **It exists
  so the behaviour is chosen**, and so it can be pointed at in review notes.
- ⚠️ **DEFAULT STATE: ON, user can toggle it OFF.** *"opt to toggle off."* **This is his call and it
  is the opposite of what Claude recommended** (default off, opt in). **Recorded as his decision, in
  his words, not smoothed into the advice he was given.**
  → [[feedback_dont_launder_your_own_suggestion_into_his_rule]]
  **The cost he is accepting:** every user gets background audio without choosing it — the battery
  draw and the audio focus — and it is the harder version to defend under 2.5.4.
  ⚠️ **Related standing rule worth re-reading before this ships:**
  [[feedback_auto_on_power_on_behavior_discuss_first]] — auto-on behaviour is safety-sensitive and
  gets discussed before it becomes permanent. **He has discussed it; this note is the record.**

### Physical setup at his bedside — his constraint, 11:58

> ***"i have two chargers next to my bed but i have been turning one off because of the pilot lights"***

**Monitor Mode requires that second charger switched back on.** The phone itself stays dark while
locked, **so the charger's own indicator LED is the only new light in the room** — tape, or a
different charger. **Small, but it is the reason the second charger is currently off**, and a
feature that needs it should say so.

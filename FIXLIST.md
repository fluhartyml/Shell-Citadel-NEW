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

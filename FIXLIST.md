# Shell Citadel — shakedown fix list

Found by Michael running the app. Nothing here is fixed until he says it looks right.

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

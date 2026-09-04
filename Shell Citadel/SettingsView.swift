//
//  SettingsView.swift
//  Shell Citadel
//
//  Preferences about HIM. Not about any machine he connects to.
//
//  ⚠️ THE DIVIDING LINE, AND HE DREW IT. 2026-09-04: "for each connection card has a
//  speech voice drop down, and the appearance and hands free mechanics goes in the
//  settings. i like the sliders glyph for settings."
//
//  Anything describing a DESTINATION — address, account, password, mode, session —
//  belongs to a Connection and is saved with it. Anything describing how he talks and
//  listens belongs here, because the answer is the same whichever machine he reaches.
//
//  ⚠️ AND IT IS TWO SHEETS ON PURPOSE, WHICH I GOT WRONG FIRST. I combined them, and he
//  put it back: "i like not bloating menues if we dont have to." Combined, this becomes
//  Server name, Sign in, Mode, Speech, Appearance and later Tabs — one long scroll where
//  every section is in the way of every other. The two surfaces are not clutter; they
//  are the difference between what you change to reach a machine and what you change to
//  suit yourself.
//
//  ⚠️ WHY THIS SCREEN'S ABSENCE WAS A BUG. "Pause before sending" was stored, defaulted
//  to 1.5 seconds and synced across his devices — with no control anywhere to change it.
//  He tuned that number by hand today: 1 second cut him off mid-sentence, 3 too long,
//  2 too long, "1.5 is a sweet spot." On the rebuilt app he could not have got back to
//  it. A stored preference with no way to reach it is a decision made once, on his
//  behalf, permanently.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = SyncedSettings.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // ⚠️ A STEPPER, NOT A SLIDER, AND HE FOUND THE VALUE BY STEPPING.
                    // The useful range is about half a second wide. A slider cannot be
                    // nudged by exactly half a second, and cannot be nudged at all
                    // without looking at it — the wrong requirement for a control that
                    // exists to serve someone talking while doing something else.
                    Stepper(value: $settings.pauseSeconds, in: 0.5...5.0, step: 0.5) {
                        LabeledContent("Pause before sending") {
                            Text(String(format: "%.1f s", settings.pauseSeconds))
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                } header: {
                    HStack {
                        Text("Hands free")
                        MoreInfo(
                            title: "the sending pause",
                            detail: """
                            How long a silence means you have finished talking.

                            Too short and half a sentence gets sent; too long and you \
                            wait for it, and keep talking into the gap.

                            It follows you between devices, so it only has to be found \
                            once.
                            """
                        )
                    }
                } footer: {
                    Text("Follows you between devices.")
                        .fixedSize(horizontal: false, vertical: true)
                }

                // ⚠️ NAMED AND EMPTY ON PURPOSE. Appearance is his — columns, lines,
                // size, colours, the Nerd Font — and it is not built. Listing it as
                // absent is the honest state; leaving it out entirely is how "not built
                // yet" quietly becomes "not wanted", which he caught me doing today:
                // "they are not there because you chose not to code them."
                Section {
                    LabeledContent("Columns, lines, size", value: "not built yet")
                    LabeledContent("Text and background colour", value: "not built yet")
                    LabeledContent("Terminal font", value: "not built yet")
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("On the list, not written yet.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            #if os(macOS)
            .frame(minWidth: 420, idealWidth: 480, minHeight: 320, idealHeight: 400)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}

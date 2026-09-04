//
//  SettingsView.swift
//  Shell Citadel
//
//  Preferences about HIM, not about a machine he connects to.
//
//  ⚠️ THE DIVIDING LINE, AND IT IS NOT ARBITRARY. Anything that describes a destination
//  — address, account, password, mode, session — belongs to a Connection and travels
//  with it. Anything that describes how he talks and listens belongs here, because it is
//  the same answer whichever machine he is reaching.
//
//  ⚠️ THIS SCREEN DID NOT EXIST AND THAT WAS THE BUG. "Pause before sending" was stored,
//  defaulted to 1.5 seconds and synced across his devices — with no control anywhere to
//  change it. He tuned that number by hand on 2026-09-04, trying 1 second (cut him off
//  mid-sentence), 3 (too long), 2 (too long), and landing on "1.5 is a sweet spot" — and
//  on the rebuilt app he could not have got back to it.
//
//  A stored preference with no way to reach it is worse than no preference: it is a
//  decision made once, on his behalf, permanently.
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
                    //
                    // The useful range is about half a second wide and he located it by
                    // trying 1, then 3, then 2, then 1.5. A slider cannot be nudged by
                    // exactly half a second, and it cannot be nudged at all without
                    // looking at it — which is the wrong requirement for a control whose
                    // whole purpose is to serve someone talking while doing something
                    // else.
                    Stepper(value: $settings.pauseSeconds, in: 0.5...5.0, step: 0.5) {
                        LabeledContent("Pause before sending") {
                            Text(String(format: "%.1f s", settings.pauseSeconds))
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                } header: {
                    HStack {
                        Text("Speech")
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
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            #if os(macOS)
            .frame(minWidth: 420, idealWidth: 480, minHeight: 260, idealHeight: 320)
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

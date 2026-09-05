//
//  ConnectionSheet.swift
//  Shell Citadel
//
//  The phone button opens the LIST, not one connection.
//
//  Michael, 2026-09-04: "the phone connection fill connections sheet should show the list
//  of connrction cards with the teletype glyph icon."
//
//  ⚠️ WHY THAT IS THE RIGHT WAY ROUND. The button used to open whichever single
//  connection the tab happened to hold, which meant the app had somewhere to EDIT a
//  connection and nowhere to CHOOSE one. That is the gap behind fix-list item 45 — no
//  Add, no Edit, no Delete, no empty state — and behind his report from 2026-08-29, when
//  he typed an ssh line and the app "didnt give me anywhere to put the password."
//
//  ⚠️ THE SAME CARDS AS THE START PAGE, ON PURPOSE. A new tab shows these cards; so does
//  this sheet. One way a connection looks, wherever it appears, so recognising it in one
//  place teaches recognising it in the other.
//

import SwiftUI

struct ConnectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let store: ConnectionStore
    /// Whether the tab underneath already has a live session.
    let isConnected: Bool
    let onPick: (Connection) -> Void
    let onEdit: (Connection) -> Void
    let onNew: () -> Void

    @State private var pendingReplacement: Connection?

    var body: some View {
        NavigationStack {
            ConnectionCards(
                connections: store.connections,
                onPick: { picked in
                    // ⚠️ ASKS ONLY WHEN THERE IS SOMETHING TO LOSE.
                    //
                    // His design put the + on the tab row, and that is what made this
                    // simple: "open in a new tab" is the plus, so the only question left
                    // here is whether to replace what is in front. On a tab with no
                    // session there is nothing to ask about, and a prompt with one real
                    // answer is a prompt that teaches people to dismiss prompts.
                    if isConnected {
                        pendingReplacement = picked
                    } else {
                        onPick(picked)
                        dismiss()
                    }
                },
                onNew: { onNew(); dismiss() },
                onEdit: { onEdit($0); dismiss() },
                onDelete: { store.remove(id: $0.id) })
            .navigationTitle("Connections")
            #if os(macOS)
            .frame(minWidth: 480, idealWidth: 560, minHeight: 380, idealHeight: 460)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { onNew(); dismiss() } label: {
                        Label("Add a connection", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                pendingReplacement.map { "Replace this tab with \($0.title)?" } ?? "",
                isPresented: Binding(
                    get: { pendingReplacement != nil },
                    set: { if !$0 { pendingReplacement = nil } }),
                titleVisibility: .visible
            ) {
                Button("Replace this tab", role: .destructive) {
                    if let picked = pendingReplacement {
                        onPick(picked)
                        pendingReplacement = nil
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { pendingReplacement = nil }
            } message: {
                // ⚠️ NAMES WHAT IS LOST AND WHERE THE OTHER PATH IS. A confirmation that
                // only says "are you sure" makes him carry the consequence himself.
                Text("This tab is connected. Replacing it disconnects that session. Use + on the tab row to open this alongside instead.")
            }
        }
    }
}

//
//  ConnectionCards.swift
//  Shell Citadel
//
//  What a new tab shows before it is pointed at anything.
//
//  Michael, 2026-09-04: "like safari when you add a new tab the connection cards show or
//  you type in the chat line similar to the url bar."
//
//  ⚠️ THE START PAGE IS WHY THE APP DOES NOT NEED A CONNECTION MANAGER. Safari has no
//  "manage bookmarks" step in the way of opening one — the new tab IS the list. So there
//  is no separate connections screen here either: the empty tab shows what you have, and
//  the composer takes a typed address the way a URL bar does.
//
//  ⚠️ AND AN EMPTY LIST STILL HAS TO SAY SOMETHING. A first launch shows no cards at
//  all, and a blank page with a text box is the "form that does nothing" that gets SSH
//  clients rejected. So the empty state names the two ways in.
//

import SwiftUI

struct ConnectionCards: View {
    let connections: [Connection]
    let onPick: (Connection) -> Void
    let onNew: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 210), spacing: 12)]

    var body: some View {
        ScrollView {
            if connections.isEmpty {
                empty
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(connections) { connection in
                        Button {
                            onPick(connection)
                        } label: {
                            card(connection)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }

    private func card(_ connection: Connection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // ⚠️ HIS EMBELLISHMENT: "you can embellish each card with teletype icons."
                // It pairs with phone.connection.fill on the button that edits one — the
                // machine on the card, the act of dialling it on the toolbar.
                Image(systemName: "teletype")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(connection.mode.title)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }

            Text(connection.title)
                .font(.headline)
                .lineLimit(1)

            // ⚠️ ACCOUNT AND HOST, BECAUSE THOSE ARE WHAT GET PROOFREAD. He asked for
            // failed connections to be kept precisely so a typo could be found by
            // looking — so the card has to show the two fields the typo hides in.
            Text("\(connection.username)@\(connection.host)")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "teletype")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No saved connections")
                .font(.headline)
            Text("Type ssh user@server.local below, or set one up with the phone button.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Set up a connection", action: onNew)
                .buttonStyle(.bordered)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 30)
    }
}

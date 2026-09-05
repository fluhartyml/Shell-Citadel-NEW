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

    /// The connection the tab underneath is already using, if any.
    ///
    /// ⚠️ IT ANSWERS "WHERE AM I?" BEFORE HE HAS TO GUESS. His recollection of the old
    /// app, 2026-09-04: "if you were in a tab and you tapped the connections it had a
    /// 'this tab' indicator." Without it every card looks equally available, including
    /// the one he is already sitting in — and picking that one would offer to replace a
    /// session with itself.
    var currentID: Connection.ID? = nil
    let onPick: (Connection) -> Void
    let onNew: () -> Void
    /// nil where editing does not belong — the start page just opens things.
    var onEdit: ((Connection) -> Void)? = nil
    var onDelete: ((Connection) -> Void)? = nil


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
                        // ⚠️ EDIT AND DELETE LIVE IN A CONTEXT MENU, NOT ON THE CARD.
                        // A card is something you press to go somewhere; putting a
                        // delete control on its face means every trip to a connection
                        // passes a button that destroys it. Long press is the ordinary
                        // place for "something other than the obvious thing".
                        .contextMenu {
                            if let onEdit {
                                Button("Edit\u{2026}") { onEdit(connection) }
                            }
                            if let onDelete {
                                Button("Delete", role: .destructive) { onDelete(connection) }
                            }
                        }
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

            HStack(spacing: 6) {
                Text(connection.title)
                    .font(.headline)
                    .lineLimit(1)
                if connection.id == currentID {
                    Text("This tab")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.18))
                        .foregroundStyle(.tint)
                        .clipShape(Capsule())
                }
            }

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
        // A ring rather than a fill, so the card he is in reads as marked rather than
        // as a different kind of thing.
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(connection.id == currentID ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 2)
        )
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

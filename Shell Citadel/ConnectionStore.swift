//
//  ConnectionStore.swift
//  Shell Citadel
//
//  The saved connections.
//
//  ⚠️ DELETING ONE MUST DELETE ONLY ONE. On 2026-09-04 Michael deleted a single
//  connection in the old app and all three vanished: "i deleted it once and all three
//  deleted." That bug was never diagnosed, and the app was rebuilt before it was.
//
//  So this store is deliberately dull: an array, addressed by the connection's own id,
//  saved as JSON. `remove(id:)` filters on that id and nothing else — no index
//  arithmetic, no shared mutable cursor, no "current selection" that a delete can walk
//  off the end of. Whatever the old cause was, none of the usual ones can happen here.
//

import Foundation
import Observation

@Observable
final class ConnectionStore {
    private static let key = "connections.v1"

    private(set) var connections: [Connection] = []

    init() { load() }

    /// ⚠️ NORMALISED HERE, AT THE ONE DOOR EVERY SAVE GOES THROUGH.
    ///
    /// Not in the editor's onChange, which would fight him mid-word — lowercasing a host
    /// name while he is still typing it moves the caret and makes the field feel broken.
    /// He types what he likes; it is made exact on the way to disk. See
    /// `Connection.normalised()` for why the account and the host are handled
    /// differently.
    func save(_ connection: Connection) {
        let connection = connection.normalised()
        if let i = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[i] = connection
        } else {
            connections.append(connection)
        }
        persist()
    }

    /// Removes exactly the one with this id. See the note at the top of this file.
    func remove(id: Connection.ID) {
        let before = connections.count
        connections.removeAll { $0.id == id }
        let after = connections.count
        Diagnostics.shared.record(.app, "removed connection · \(before) -> \(after)")
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(connections) else {
            Diagnostics.shared.failed(.app, "could not encode connections")
            return
        }
        UserDefaults.standard.set(data, forKey: Self.key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([Connection].self, from: data) else { return }
        connections = decoded
    }
}

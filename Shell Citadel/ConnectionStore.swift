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

    /// ⚠️ ONE STORE FOR THE WHOLE APP, AND TABS ARE WHY.
    ///
    /// `TerminalView` created its own with `@State`, which was harmless while there was
    /// one terminal. With tabs there are four of them, each holding a separate copy of
    /// the same list, each writing the whole list to iCloud — so saving a connection in
    /// one tab would be silently undone by the next write from another, and the tab that
    /// last touched it would win.
    ///
    /// It is shared state by nature: a connection belongs to the person, not to the tab
    /// that happened to open it.
    static let shared = ConnectionStore()
    private static let key = "connections.v1"

    /// ⚠️ THE SAME KEY IN BOTH PLACES, ON PURPOSE. Local is the cache that works with no
    /// network and no account; the cloud is the copy that travels. Reading falls back to
    /// local, writing always does both.
    private let cloud = NSUbiquitousKeyValueStore.default
    private let local = UserDefaults.standard

    private(set) var connections: [Connection] = []

    init() {
        load()
        // ⚠️ ANOTHER DEVICE CHANGING SOMETHING HAS TO ARRIVE WITHOUT A RELAUNCH. Without
        // this, a connection added on the Mac shows up on the phone only after the phone
        // is force-quit — which reads as "it did not sync" rather than "it will".
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.pullFromCloud() }
        }
        cloud.synchronize()
        pullFromCloud()
    }

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
        local.set(data, forKey: Self.key)
        cloud.set(data, forKey: Self.key)
        cloud.synchronize()
        Diagnostics.shared.record(.app, "connections saved \u{00B7} \(connections.count)")
    }

    private func load() {
        guard let data = local.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([Connection].self, from: data) else { return }
        connections = decoded
    }

    /// ⚠️ LAST WRITE WINS, AND THAT IS A REAL LIMITATION RATHER THAN AN OVERSIGHT.
    ///
    /// The whole list travels as one value, so two devices editing at the same moment
    /// means one of them loses. Merging per connection would be better and is not worth
    /// building for one person with three devices who edits on one at a time — but it is
    /// written down here so nobody later mistakes this for a merge that failed.
    ///
    /// ⚠️ PASSWORDS DO NOT TRAVEL WITH THIS, DELIBERATELY. They are in each device's
    /// Keychain, and the app promises exactly that: "never in iCloud, never in a backup."
    /// So a connection appears on the other device complete except for its password, which
    /// is typed once there and then kept. That is the intended trade, not a gap.
    private func pullFromCloud() {
        guard let data = cloud.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([Connection].self, from: data) else { return }
        guard decoded != connections else { return }
        connections = decoded
        local.set(data, forKey: Self.key)
        Diagnostics.shared.record(.app, "connections arrived from another device \u{00B7} \(decoded.count)")
    }
}

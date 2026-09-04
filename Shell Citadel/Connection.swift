//
//  Connection.swift
//  Shell Citadel
//
//  Where to connect, and how to still find it when the address has moved.
//

import Foundation

/// One saved destination.
struct Connection: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()

    /// A friendly label for the list. Not used to connect.
    var name = "My Mac"

    /// ⚠️ THE ADDRESS IS A NAME BY DEFAULT, AND THAT IS DELIBERATE.
    ///
    /// Michael, 2026-09-04, asked whether his Mac should get a fixed IP:
    /// "sounds like an engineering issue, i would as a layman say use
    ///  michaels-macbook-air.local."
    ///
    /// He is right, and the layman answer is the better engineering one. A Bonjour
    /// name follows the machine, so the address changing stops mattering — nothing to
    /// configure on his router and nothing for him to remember. On 2026-09-04 his
    /// Mac moved from 192.168.1.38 to .63 overnight and every saved connection broke;
    /// a name would have survived that untouched.
    var host = ""

    var port = 22
    var username = ""

    /// ⚠️ THE SECOND PATH. A `.local` name is resolved by mDNS, which does not work
    /// over cellular and can be swallowed by a VPN profile that captures DNS. So the
    /// name alone is not enough either — on the same morning, `.local` failed and the
    /// app said "could not reach the server", which is also what it says for a dead
    /// host, a wrong port and a blocked network.
    ///
    /// Every successful connection records the address it actually reached, and a
    /// failure to RESOLVE the name falls back to it. Two independent paths, nothing
    /// for him to configure, and neither one's failure is silent.
    var lastKnownAddress: String?

    /// True when the host is a name rather than a literal address, which is the only
    /// case where the fallback means anything.
    var hostIsName: Bool {
        // Not a full IP parse — just "does this look like digits and dots".
        !host.isEmpty && host.contains(where: { $0.isLetter })
    }
}

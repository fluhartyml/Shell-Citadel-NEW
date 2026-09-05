//
//  Diagnosis.swift
//  Shell Citadel
//
//  Turning a library's error into a sentence a person can act on.
//
//  Michael, 2026-09-04, from bed, with a screenshot of his phone:
//  "(NIOPosix.NIOConnectionError error 1.)" and "(Citadel.SSHClientError error 4.)"
//
//  ⚠️ THOSE TWO STRINGS COST A DAY BETWEEN THEM. "error 4" was on his screen for hours
//  while three different faults produced it — a wrong account, a missing letter, and an
//  empty password — and the message never once said which. He had to describe the symptom
//  to me and wait for me to guess, five times.
//
//  ⚠️ THE RULE THIS FILE FOLLOWS: SAY THE CAUSE, THEN THE NEXT MOVE. Not "an error
//  occurred", not the error's own name. What went wrong, and what he can do about it —
//  and where the app genuinely cannot tell, it says the two possibilities rather than
//  picking one and sounding certain. A confident wrong reason is worse than an honest
//  fork, which is the whole lesson of the five guesses.
//

import Foundation

enum Diagnosis {

    /// What the app should show for a connection failure.
    struct Reading {
        let sentence: String
        /// True when the far end rejected the sign-in — the case where asking for the
        /// password again is the useful response rather than a shrug.
        let isAuthFailure: Bool
    }

    static func read(_ error: Error, connection: Connection, hasPassword: Bool) -> Reading {
        let text = String(describing: error)

        // ── Sign-in rejected ────────────────────────────────────────────────────────
        if text.contains("allAuthenticationOptionsFailed") || text.contains("SSHClientError error 4") {
            if !hasPassword {
                return Reading(
                    sentence: "No password for \(connection.host) on this device. Passwords are kept in each device's Keychain and never travel, so it has to be typed here once.",
                    isAuthFailure: true)
            }
            return Reading(
                sentence: "\(connection.host) refused the sign-in. Either the password is wrong, or the account \u{201C}\(connection.username)\u{201D} is not one it has.",
                isAuthFailure: true)
        }

        // ── Could not get a socket open ─────────────────────────────────────────────
        if text.contains("NIOConnectionError") || text.contains("connectTimeout") {
            return Reading(
                sentence: "Could not reach \(connection.host). It may be asleep or off the network, the name may not be resolving, or this device has not been allowed to find things on the local network \u{2014} Settings \u{203A} Privacy & Security \u{203A} Local Network.",
                isAuthFailure: false)
        }

        if text.contains("connectionRefused") || text.contains("ECONNREFUSED") {
            return Reading(
                sentence: "\(connection.host) answered but refused the connection. Remote Login is probably switched off on it \u{2014} on a Mac that is System Settings \u{203A} General \u{203A} Sharing.",
                isAuthFailure: false)
        }

        if text.contains("hostKey") || text.contains("HostKey") {
            return Reading(
                sentence: "\(connection.host) presented a different key than last time. That is worth checking before you go on \u{2014} it means either the machine was rebuilt, or it is not the same machine.",
                isAuthFailure: false)
        }

        // ⚠️ THE FALLBACK STILL CARRIES THE ORIGINAL. A message it cannot translate is
        // the one most worth reading verbatim, and hiding it would make the unknown case
        // the least informative one.
        return Reading(
            sentence: "\(connection.host) could not be reached: \(error.localizedDescription)",
            isAuthFailure: false)
    }
}

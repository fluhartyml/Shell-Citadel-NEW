//
//  TerminalAppearance.swift
//  Shell Citadel
//
//  Which colour set the terminal is drawing with, when it is not simply the system's.
//
//  ⚠️ HIS ASK, 2026-09-05: "can you set the tab to overide system light dark mode until
//  the system transitions again?"
//
//  The problem it solves is real and small: the Light and Dark tabs let him edit the
//  colours for an appearance he is not currently in, and until now he had to change his
//  Mac's appearance to see what he had just chosen. Picking the tab now shows him the
//  result immediately.
//
//  ⚠️ AND IT EXPIRES BY ITSELF, WHICH IS THE PART THAT MAKES IT SAFE. A preview that
//  sticks is indistinguishable from a bug: weeks later the terminal is stubbornly light
//  in a dark room and nothing on screen says why. His own rule is the expiry — the next
//  real system transition takes it back, because that transition is the user expressing
//  a preference, and a preview must never outrank one.
//
//  ⚠️ SCOPE: THE TERMINAL ONLY. His words: "just the terminal text please." The window,
//  the sheets and the toolbar stay in the system's appearance — which is also what keeps
//  this honest, because an app that forces its own appearance can no longer observe the
//  system's, and would have nothing to expire against.
//
//  ⚠️ THE BACKGROUND TRAVELS WITH THE TEXT, and that is a decision worth stating. He said
//  "text", but a Light text colour drawn on the Dark background is black on near-black.
//  The pair is what an appearance IS here, and splitting it would produce a preview that
//  cannot be read — which is the one thing the feature exists to provide.
//
//  ⚠️ PER DEVICE, NEVER SYNCED. It is a preview of an edit in progress on one screen, not
//  a preference about him. Nothing here goes near SyncedSettings.
//

import SwiftUI

@MainActor
@Observable
final class TerminalAppearance {
    static let shared = TerminalAppearance()

    /// The appearance he is previewing, or nil when the terminal simply follows the
    /// system.
    private(set) var preview: ColorScheme?

    /// What the system was showing at the moment the preview was chosen. The comparison
    /// against this is the whole expiry mechanism — not a timer, not a screen dismissal.
    private var systemWhenChosen: ColorScheme?

    /// Deliberately in memory only. A relaunch is not a system transition, but a preview
    /// that survives one is a state he never chose and cannot see the reason for. Losing
    /// it on launch costs a tap; keeping it risks a mystery.
    private init() {}

    /// Called by the Light/Dark tabs.
    func preview(_ scheme: ColorScheme, systemIs current: ColorScheme) {
        preview = scheme
        systemWhenChosen = current
        Diagnostics.shared.record(.app, "previewing \(scheme == .dark ? "dark" : "light") colours; system is \(current == .dark ? "dark" : "light")")
    }

    /// The appearance the terminal should actually draw with.
    ///
    /// ⚠️ THIS IS ALSO WHERE THE PREVIEW DIES, deliberately: expiry is checked at the
    /// moment of use rather than by something watching in the background. A rule that
    /// only holds while an observer happens to be alive is a rule with a hole in it.
    func resolved(system: ColorScheme) -> ColorScheme {
        guard let preview else { return system }

        if let chosen = systemWhenChosen, chosen != system {
            // The system moved. That outranks a preview, always.
            self.preview = nil
            systemWhenChosen = nil
            Diagnostics.shared.record(.app, "system appearance changed — colour preview released")
            return system
        }

        return preview
    }

    /// Drops the preview without waiting for a system transition.
    func release() {
        guard preview != nil else { return }
        preview = nil
        systemWhenChosen = nil
        Diagnostics.shared.record(.app, "colour preview released")
    }
}

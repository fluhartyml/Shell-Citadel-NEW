//
//  LocalMachine.swift
//  Shell Citadel
//
//  What this machine can tell us about itself, used only to SUGGEST — never to store.
//

import Foundation

/// Facts about the device the app is running on, read at runtime.
///
/// ⚠️ THIS FILE EXISTS BECAUSE A HARDCODED SUGGESTION IS PERSONAL DATA.
///
/// The Address placeholder once read his own Mac's name, typed in as a literal. He
/// caught it on 2026-09-04: "it is my personal data in a distribution app", and he was
/// right twice over — the string shipped in the binary AND in a source comment, in a
/// public repository.
///
/// Computing it instead fixes both halves at once. Every user sees their own machine
/// suggested, nobody's name is in the build, and the suggestion is more useful than any
/// example could have been — on a Mac, the address it offers is usually the right answer.
///
/// ⚠️ SUGGESTIONS ONLY. Nothing here is ever written into a saved connection without the
/// user typing it. A placeholder that silently becomes a value is how you end up
/// connecting somewhere you did not choose.
enum LocalMachine {

    /// This machine's own network name, e.g. `some-computer.local`, or nil.
    ///
    /// ⚠️ nil ON iOS, DELIBERATELY. `ProcessInfo.hostName` on iPhone returns the device
    /// name in a form that is not resolvable and is not a `.local` address — suggesting
    /// it would be worse than suggesting nothing, because it looks plausible.
    static var bonjourName: String? {
        #if os(macOS)
        let name = ProcessInfo.processInfo.hostName
        guard !name.isEmpty, name.contains(".") else { return nil }
        return name
        #else
        return nil
        #endif
    }

    /// The short account name of whoever is running the app, e.g. `someone`, or nil.
    ///
    /// ⚠️ THE SHORT NAME, NOT THE FULL NAME. This distinction cost a day. He typed
    /// `MichaelFluharty` — his *full* name, the one macOS shows on the login screen —
    /// and SSH answered `allAuthenticationOptionsFailed`, which the app reported as
    /// "error 4". `NSUserName()` returns the short name, which is the one SSH wants.
    ///
    /// nil on iOS, where there is no equivalent to offer.
    static var accountName: String? {
        #if os(macOS)
        let name = NSUserName()
        return name.isEmpty ? nil : name
        #else
        return nil
        #endif
    }
}

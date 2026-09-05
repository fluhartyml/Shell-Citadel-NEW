//
//  BundledFont.swift
//  Shell Citadel
//
//  The typeface the app ships with, and the app's default.
//
//  ⚠️ HIS DECISION, 2026-09-05: "nerd font is to be default shipped and user can change
//  it." He had already asked for it on 2026-08-29 — "the same nerd font im using in my
//  terminal be the standard font in my apps" — and it could not be honoured then for a
//  plain reason: iOS ships four monospaced faces (Courier, Courier New, Menlo, and the
//  system monospaced one) and no Nerd Font at all. A default naming a font that is not
//  on the device is not a default; it is a silent fallback.
//
//  So the font travels inside the app. MesloLGM Nerd Font Mono is the terminal-shaped
//  variant of the face his own Terminal runs (MesloLGM Nerd Font at 36 pt) — same
//  typeface, single-width icons instead of double.
//
//  ⚠️ REGISTERED IN CODE, NOT THROUGH Info.plist, AND THAT IS DELIBERATE. iOS wants
//  `UIAppFonts` and macOS wants `ATSApplicationFontsPath`; this target generates its
//  Info.plist from build settings, so the two platforms would need two different keys
//  maintained in parallel. CTFontManager is one call that works on both, and — the part
//  that matters — it RETURNS WHETHER IT WORKED. A plist key fails silently, and a
//  silently missing font would show up as the app quietly using the system face while
//  Settings displayed the name of one it never loaded.
//
//  ⚠️ THE LICENCES SHIP WITH IT. A Nerd Font is a base typeface patched with thirteen
//  other projects' icon sets, and several of those require attribution. They are in
//  Attribution.swift, which is what the About sheet reads. Shipping the file without the
//  notices is the part that would actually be wrong.
//

import SwiftUI
import CoreText

enum BundledFont {

    /// The file in the app bundle, without its extension.
    private static let resource = "MesloLGMNerdFontMono-Regular"

    /// What the picker shows and what `SyncedSettings.Default.fontName` stores.
    ///
    /// ⚠️ THE FAMILY NAME, NOT THE POSTSCRIPT NAME (`MesloLGMNFM-Regular`). The font
    /// picker is built from family names, so the default has to be one of them or the
    /// Picker would draw an empty selection while the terminal rendered correctly — the
    /// kind of disagreement that reads as a bug in the wrong place.
    static let familyName = "MesloLGM Nerd Font Mono"

    /// Whether the bundled face is registered and usable right now.
    ///
    /// Read this rather than assuming: if registration ever fails, the app must fall
    /// back to the system monospaced face **and say so in Diagnostics**, not pretend.
    private(set) static var isAvailable = false

    /// Registers the bundled face with the system. Safe to call more than once.
    ///
    /// Called from the app's own init so the font exists before the first view asks for
    /// it — a terminal that draws one frame in the wrong face and then corrects itself
    /// is a flicker he would be right to report as a bug.
    @discardableResult
    static func register() -> Bool {
        if isAvailable { return true }

        guard let url = Bundle.main.url(forResource: resource, withExtension: "ttf") else {
            Diagnostics.shared.record(.app, "bundled font missing from the app bundle — using the system face")
            return false
        }

        var error: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)

        if ok {
            isAvailable = true
            Diagnostics.shared.record(.app, "bundled font registered — \(familyName)")
            return true
        }

        // ⚠️ ALREADY REGISTERED IS NOT A FAILURE. A second call — a relaunch inside the
        // same process on the Mac, a preview — returns this code, and treating it as an
        // error would disable a font that is in fact loaded.
        let failure = error?.takeRetainedValue()
        let code = failure.map { CFErrorGetCode($0) }
        if code == CTFontManagerError.alreadyRegistered.rawValue {
            isAvailable = true
            return true
        }

        Diagnostics.shared.record(.app, "bundled font failed to register (\(code.map(String.init) ?? "unknown")) — using the system face")
        return false
    }
}

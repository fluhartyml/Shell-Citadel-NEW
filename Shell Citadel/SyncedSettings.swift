//
//  SyncedSettings.swift
//  Shell Citadel
//
//  Preferences that follow HIM, kept apart from state that belongs to a DEVICE.
//
//  ⚠️ THE SPLIT IS HIS, AND IT IS THE WHOLE POINT OF THIS FILE. Michael, 2026-09-04:
//  "the sliders must be persistant across ios and mac" — and when asked whether that
//  included the speaker and microphone toggles: "just the sliders, i dont see a
//  connection between speaker mute microphone mute and the sliders menu."
//
//  He is drawing a real line:
//
//    • A SLIDER IS A PREFERENCE ABOUT HIM. How long he pauses before a sentence is
//      finished is a fact about how he talks. It is the same on the phone, the iPad and
//      the Mac, and having to rediscover 1.5 seconds on each device is three times the
//      work for one answer.
//
//    • A MUTE IS A FACT ABOUT A ROOM. Whether the speaker should be talking depends on
//      who else is present, and syncing it would mean silencing the phone in his pocket
//      because the iPad is in a room with someone in it. Those stay in UserDefaults,
//      per device, deliberately.
//
//  ⚠️ WHY NSUbiquitousKeyValueStore AND NOT CLOUDKIT. This is a handful of numbers, not
//  data. The key-value store is 1 MB total, needs no schema, no container design and no
//  record types, and it reconciles last-writer-wins — which is correct for a preference
//  and would be wrong for anything he could lose.
//
//  ⚠️ IT CAN BE UNAVAILABLE AND THAT IS NOT AN ERROR. Signed out of iCloud, iCloud Drive
//  off, a device in a state where sync is disabled — the store simply does nothing. So
//  the LOCAL value is always authoritative for reading, and the cloud is a mirror that
//  updates it when it has something newer. Nothing here is allowed to leave a setting
//  unreadable because a network was not there.
//

import Foundation
import Observation

// Only to ask whether a font name resolves on THIS device before taking it from iCloud.
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// ✅ LIVE as of 2026-09-04. The iCloud capability with Key-value storage is on the App
// ID — Michael added it in Xcode's Signing & Capabilities while I walked him through it,
// one step at a time. It could not be done from a command line and was not worked around.

@MainActor
@Observable
final class SyncedSettings {
    static let shared = SyncedSettings()

    private let cloud = NSUbiquitousKeyValueStore.default
    private let local = UserDefaults.standard

    private enum Key {
        static let pauseSeconds = "dictation.pauseSeconds"
        // ⚠️ `terminal.columns` AND `terminal.lines` USED TO LIVE HERE AND DELIBERATELY
        // DO NOT ANY MORE. Michael, 2026-09-05: the size is what scales, and "the
        // (height) lines and (width) colums increase or decrease" as a result of it.
        // A stored count would be a second source of truth for a number the layout
        // already decides, and the two would disagree the first time a phone rotated.
        // They are computed now — TerminalMetrics.swift.
        //
        // Old values left behind in iCloud and UserDefaults are simply never read. They
        // are harmless, and deleting a key is not something to do to another device's
        // store on its behalf.
        static let fontSize = "terminal.fontSize"
        static let fontName = "terminal.fontName"
        static let lightBackground = "terminal.light.background"
        static let lightYou = "terminal.light.you"
        static let lightThem = "terminal.light.them"
        static let darkBackground = "terminal.dark.background"
        static let darkYou = "terminal.dark.you"
        static let darkThem = "terminal.dark.them"
    }

    /// ⚠️ THE DEFAULTS ARE GENERIC, NOT HIS.
    ///
    /// On 2026-08-29 he asked for the appearance to be "user configurable with mine given
    /// first launch as example". On 2026-09-04 he set a standing rule that outranks it:
    /// "All apps are to ship agnostic and not use data specific to my personal use...
    /// never use my personal information as a template."
    ///
    /// The later rule wins, and it is the right one — a first launch that arrives
    /// pre-set to one person's terminal is that person's preference presented to
    /// everyone else as a recommendation. So: the system monospaced face, the system
    /// text and background colours, and a terminal's traditional 80 by 24.
    enum Default {
        // ⚠️ 80 COLUMNS BY 24 LINES IS NO LONGER A DEFAULT, BECAUSE IT IS NO LONGER A
        // SETTING. The traditional terminal shape is now whatever 13 pt produces on the
        // device in his hand — which is the honest answer, since a phone was never going
        // to show 80 columns of readable text and used to claim it did.
        static let fontSize = 13.0
        /// ⚠️ THE APP SHIPS ITS OWN TYPEFACE AND THIS IS IT. His decision 2026-09-05:
        /// "nerd font is to be default shipped and user can change it." Empty string
        /// still means the system monospaced face, and is what this falls back to if the
        /// bundled font ever fails to register — see BundledFont.swift, which answers
        /// that question rather than assuming it.
        ///
        /// This is not his personal setup leaking into the app: the font ships in the
        /// binary, so every user gets it, and every user can change it in Settings.
        /// → the "apps ship agnostic" rule is about his hostnames and sessions, not
        ///   about a typeface the app carries for everyone.
        static var fontName: String {
            BundledFont.isAvailable ? BundledFont.familyName : ""
        }
        // ⚠️ HIS SPEC, 2026-09-04: "for the default to be in light mode a light
        // background with black text, and for dark mode i wanted a dark green for my text
        // and a lighter green for your text."
        //
        // Light mode is deliberately plain — a page. Dark mode is a green terminal, and
        // the two greens carry a real distinction: the darker one is what HE typed, the
        // lighter one is what came back. He listens to this app from another room, so the
        // moment he does look at it, whose words are whose has to be answerable without
        // reading them.
        static let lightBackground = "#FFFFFF"
        static let lightYou = "#000000"
        static let lightThem = "#000000"
        static let darkBackground = "#0E120E"
        static let darkYou = "#2E8B57"
        static let darkThem = "#8FE8A8"
    }

    /// How long a pause means he has finished a sentence.
    ///
    /// ⚠️ 1.5 SECONDS, MEASURED TWICE. He tried 1s and it cut him off mid-sentence
    /// repeatedly; 3s was "way too long"; 2s was "too long"; and he landed on
    /// "1.5 is a sweet spot" — independently the same value the old app had arrived at.
    var pauseSeconds: Double {
        didSet { store(pauseSeconds, Key.pauseSeconds, "pause -> \(pauseSeconds)s") }
    }

    // MARK: - Terminal appearance
    //
    // ⚠️ GEOMETRY SITS ABOVE THE TABS AND COLOUR SITS INSIDE THEM. His layout,
    // 2026-09-04: columns, lines and size "are the same in either appearance", so they
    // belong outside; the Light and Dark tabs hold "only the text color and background
    // color". That is not a visual preference — it is the actual shape of the data, and
    // a screen laid out against it would invite setting a column count "for dark mode".

    /// ⚠️ THE ONLY GEOMETRY VALUE THERE IS. Columns and lines are read off the layout at
    /// this size — see TerminalMetrics.swift — so this is the one number that has to be
    /// stored, and the one that has to travel: how big text needs to be is a fact about
    /// his eyes, not about the screen he happens to be holding.
    var fontSize: Double { didSet { store(fontSize, Key.fontSize, "font size -> \(fontSize)") } }
    var fontName: String { didSet { store(fontName, Key.fontName, "font -> \(fontName)") } }
    var lightBackground: String { didSet { store(lightBackground, Key.lightBackground, "light bg -> \(lightBackground)") } }
    var lightYou: String { didSet { store(lightYou, Key.lightYou, "light you -> \(lightYou)") } }
    var lightThem: String { didSet { store(lightThem, Key.lightThem, "light them -> \(lightThem)") } }
    var darkBackground: String { didSet { store(darkBackground, Key.darkBackground, "dark bg -> \(darkBackground)") } }
    var darkYou: String { didSet { store(darkYou, Key.darkYou, "dark you -> \(darkYou)") } }
    var darkThem: String { didSet { store(darkThem, Key.darkThem, "dark them -> \(darkThem)") } }

    /// Put everything on this screen back to the shipped values.
    func resetAppearance() {
        fontSize = Default.fontSize
        fontName = Default.fontName
        lightBackground = Default.lightBackground
        lightYou = Default.lightYou
        lightThem = Default.lightThem
        darkBackground = Default.darkBackground
        darkYou = Default.darkYou
        darkThem = Default.darkThem
        Diagnostics.shared.record(.app, "appearance reset to defaults")
    }

    private func store<T>(_ value: T, _ key: String, _ note: String) {
        local.set(value, forKey: key)
        cloud.set(value, forKey: key)
        cloud.synchronize()
        Diagnostics.shared.record(.app, note)
    }

    private init() {
        let stored = local.double(forKey: Key.pauseSeconds)
        pauseSeconds = stored > 0 ? stored : 1.5

        let fs = local.double(forKey: Key.fontSize)
        fontSize = fs > 0 ? fs : Default.fontSize
        fontName = local.string(forKey: Key.fontName) ?? Default.fontName
        lightBackground = local.string(forKey: Key.lightBackground) ?? Default.lightBackground
        lightYou = local.string(forKey: Key.lightYou) ?? Default.lightYou
        lightThem = local.string(forKey: Key.lightThem) ?? Default.lightThem
        darkBackground = local.string(forKey: Key.darkBackground) ?? Default.darkBackground
        darkYou = local.string(forKey: Key.darkYou) ?? Default.darkYou
        darkThem = local.string(forKey: Key.darkThem) ?? Default.darkThem

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

    /// Takes the cloud's value when it has one. Deliberately quiet: a device that has
    /// never synced keeps whatever it had rather than being reset to a default.
    ///
    /// ⚠️ EVERY SYNCED VALUE IS PULLED, NOT JUST THE PAUSE. Until 2026-09-05 this method
    /// read `pauseSeconds` alone, while the writer sent all eleven — so the size, the
    /// face and the colours went **up** to iCloud and never came **down**. The file said
    /// they follow him between devices; only one of them did. A preference that syncs in
    /// one direction is worse than one that does not sync at all, because the screen
    /// still claims it worked.
    private func pullFromCloud() {
        let pause = cloud.double(forKey: Key.pauseSeconds)
        if pause > 0, pause != pauseSeconds {
            pauseSeconds = pause
            Diagnostics.shared.record(.app, "pause synced from another device -> \(pause)s")
        }

        let size = cloud.double(forKey: Key.fontSize)
        if size > 0, size != fontSize {
            fontSize = size
            Diagnostics.shared.record(.app, "font size synced from another device -> \(size)")
        }

        // A face is only worth taking if this device actually has it installed —
        // otherwise the picker would show the name of a font that cannot be drawn, and
        // the terminal would quietly fall back to the system one. The empty string is
        // the system monospaced face and is always available.
        if let name = cloud.string(forKey: Key.fontName), name != fontName,
           name.isEmpty || Self.monospacedFontExists(name) {
            fontName = name
            Diagnostics.shared.record(.app, "font synced from another device -> \(name.isEmpty ? "system" : name)")
        }

        for (key, apply) in colourPullers {
            guard let hex = cloud.string(forKey: key) else { continue }
            apply(hex)
        }
    }

    /// Paired so a colour cannot be pulled into the wrong slot by a copy-paste — the key
    /// and the property it belongs to are written once, together.
    private var colourPullers: [(String, (String) -> Void)] {
        [
            (Key.lightBackground, { if $0 != self.lightBackground { self.lightBackground = $0 } }),
            (Key.lightYou, { if $0 != self.lightYou { self.lightYou = $0 } }),
            (Key.lightThem, { if $0 != self.lightThem { self.lightThem = $0 } }),
            (Key.darkBackground, { if $0 != self.darkBackground { self.darkBackground = $0 } }),
            (Key.darkYou, { if $0 != self.darkYou { self.darkYou = $0 } }),
            (Key.darkThem, { if $0 != self.darkThem { self.darkThem = $0 } }),
        ]
    }

    private static func monospacedFontExists(_ name: String) -> Bool {
        #if canImport(UIKit)
        UIFont(name: name, size: 12) != nil
        #else
        NSFont(name: name, size: 12) != nil
        #endif
    }
}

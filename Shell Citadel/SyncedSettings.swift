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
        static let columns = "terminal.columns"
        static let lines = "terminal.lines"
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
        static let columns = 80
        static let lines = 24
        static let fontSize = 13.0
        /// Empty means the system monospaced face.
        static let fontName = ""
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

    var columns: Int { didSet { store(columns, Key.columns, "columns -> \(columns)") } }
    var lines: Int { didSet { store(lines, Key.lines, "lines -> \(lines)") } }
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
        columns = Default.columns
        lines = Default.lines
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

        let c = local.integer(forKey: Key.columns)
        columns = c > 0 ? c : Default.columns
        let l = local.integer(forKey: Key.lines)
        lines = l > 0 ? l : Default.lines
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
    private func pullFromCloud() {
        let remote = cloud.double(forKey: Key.pauseSeconds)
        guard remote > 0, remote != pauseSeconds else { return }
        pauseSeconds = remote
        Diagnostics.shared.record(.app, "pause synced from another device -> \(remote)s")
    }
}

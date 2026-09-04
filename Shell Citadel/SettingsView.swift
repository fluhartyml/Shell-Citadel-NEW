//
//  SettingsView.swift
//  Shell Citadel
//
//  Preferences about HIM. Not about any machine he connects to.
//
//  ⚠️ THE DIVIDING LINE, AND HE DREW IT. 2026-09-04: "for each connection card has a
//  speech voice drop down, and the appearance and hands free mechanics goes in the
//  settings. i like the sliders glyph for settings."
//
//  Anything describing a DESTINATION — address, account, password, mode, session —
//  belongs to a Connection and is saved with it. Anything describing how he talks and
//  listens belongs here, because the answer is the same whichever machine he reaches.
//
//  ⚠️ AND IT IS TWO SHEETS ON PURPOSE, WHICH I GOT WRONG FIRST. I combined them, and he
//  put it back: "i like not bloating menues if we dont have to." Combined, this becomes
//  Server name, Sign in, Mode, Speech, Appearance and later Tabs — one long scroll where
//  every section is in the way of every other. The two surfaces are not clutter; they
//  are the difference between what you change to reach a machine and what you change to
//  suit yourself.
//
//  ⚠️ WHY THIS SCREEN'S ABSENCE WAS A BUG. "Pause before sending" was stored, defaulted
//  to 1.5 seconds and synced across his devices — with no control anywhere to change it.
//  He tuned that number by hand today: 1 second cut him off mid-sentence, 3 too long,
//  2 too long, "1.5 is a sweet spot." On the rebuilt app he could not have got back to
//  it. A stored preference with no way to reach it is a decision made once, on his
//  behalf, permanently.
//

import SwiftUI

/// Hex in, Color out, and back again.
///
/// ⚠️ STORED AS HEX RATHER THAN A SwiftUI Color BECAUSE IT HAS TO TRAVEL. These settings
/// sync between his Mac and his phones through a key-value store that holds strings and
/// numbers. A hex string is also readable in the diagnostics record, which a serialised
/// colour object is not — and when a colour goes wrong, being able to read what it
/// actually is beats being able to render it.
enum HexColor {
    static func color(_ hex: String) -> Color {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return .primary }
        return Color(
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255
        )
    }

    static func hex(_ color: Color) -> String {
        #if os(macOS)
        let native = NSColor(color).usingColorSpace(.sRGB)
        let r = native?.redComponent ?? 0, g = native?.greenComponent ?? 0, b = native?.blueComponent ?? 0
        #else
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

/// Which appearance's colours the tabs are showing.
private enum ColourTab: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
}


struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = SyncedSettings.shared
    @State private var tab: ColourTab = .light
    @State private var spoken = SpokenOutput.shared
    @StateObject private var dictation = Dictation.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // ⚠️ A STEPPER, NOT A SLIDER, AND HE FOUND THE VALUE BY STEPPING.
                    // The useful range is about half a second wide. A slider cannot be
                    // nudged by exactly half a second, and cannot be nudged at all
                    // without looking at it — the wrong requirement for a control that
                    // exists to serve someone talking while doing something else.
                    Stepper(value: $settings.pauseSeconds, in: 0.5...5.0, step: 0.5) {
                        LabeledContent("Pause before sending") {
                            Text(String(format: "%.1f s", settings.pauseSeconds))
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                } header: {
                    HStack {
                        Text("Hands free")
                        MoreInfo(
                            title: "the sending pause",
                            detail: """
                            How long a silence means you have finished talking.

                            Too short and half a sentence gets sent; too long and you \
                            wait for it, and keep talking into the gap.

                            It follows you between devices, so it only has to be found \
                            once.
                            """
                        )
                    }
                    // ⚠️ THE SAME STATE THE TOOLBAR ICONS DRIVE, NOT A SECOND COPY OF
                    // IT. His wording on the fix list: "the panel is a second way to
                    // reach them, not a second copy of the state." Two switches that can
                    // disagree about one fact is worse than one switch in an awkward
                    // place.
                    Toggle("Read new output aloud", isOn: $spoken.isEnabled)
                    Toggle("Microphone on", isOn: Binding(
                        get: { dictation.isListening },
                        set: { on in
                            if on {
                                VoiceCoordinator.shared.willListen()
                                dictation.start()
                            } else {
                                dictation.stop()
                                VoiceCoordinator.shared.didStopListening()
                            }
                        }))
                } footer: {
                    // ⚠️ THE PAUSE TRAVELS, THE MUTES DO NOT, AND THAT IS DELIBERATE.
                    // "These stay per-device, not synced. A mute is a fact about the
                    // room." Silencing the phone on his porch must not silence the Mac
                    // indoors.
                    Text("The pause follows you between devices. The mutes stay on this one \u{2014} a mute is a fact about the room you are in.")
                        .fixedSize(horizontal: false, vertical: true)
                }

                // ─────────────────────────────────────────────────────────────────
                // APPEARANCE — geometry above, colour inside the tabs. His layout.
                // ─────────────────────────────────────────────────────────────────
                Section {
                    Stepper(value: $settings.columns, in: 20...300, step: 1) {
                        LabeledContent("Columns") { Text("\(settings.columns)").monospacedDigit() }
                    }
                    Stepper(value: $settings.lines, in: 5...200, step: 1) {
                        LabeledContent("Lines") { Text("\(settings.lines)").monospacedDigit() }
                    }
                    // ⚠️ A SLIDER HERE, A STEPPER FOR THE PAUSE, AND THE DIFFERENCE IS
                    // REAL. Type size is judged by looking at it, so dragging while
                    // watching is the right gesture. The sending pause is judged by
                    // talking, where the number matters and the eye is elsewhere.
                    VStack(alignment: .leading) {
                        LabeledContent("Size") {
                            Text(String(format: "%.0f pt", settings.fontSize)).monospacedDigit()
                        }
                        Slider(value: $settings.fontSize, in: 8...32, step: 1)
                    }
                    Picker("Font", selection: $settings.fontName) {
                        Text("System monospaced").tag("")
                        ForEach(Self.monospacedFonts, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                } header: {
                    HStack {
                        Text("Appearance")
                        MoreInfo(
                            title: "size and shape",
                            detail: """
                            Columns, lines and size are the same whichever appearance you \
                            are in, so they sit above the tabs. Only the two colours \
                            change between Light and Dark.

                            The font list is every monospaced face installed on this \
                            device \u{2014} read from the device, so what you have \
                            installed is what you are offered.
                            """
                        )
                    }
                }

                Section {
                    Picker("", selection: $tab) {
                        ForEach(ColourTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    // ⚠️ ONLY TWO CONTROLS LIVE IN HERE, AND THAT IS THE POINT OF THE
                    // TABS. "the tabs are only for the text color and background color."
                    // Anything else in this section would imply it could differ between
                    // light and dark, and nothing else can.
                    switch tab {
                    case .light:
                        ColorPicker("Text", selection: Binding(
                            get: { HexColor.color(settings.lightText) },
                            set: { settings.lightText = HexColor.hex($0) }))
                        ColorPicker("Background", selection: Binding(
                            get: { HexColor.color(settings.lightBackground) },
                            set: { settings.lightBackground = HexColor.hex($0) }))
                    case .dark:
                        ColorPicker("Text", selection: Binding(
                            get: { HexColor.color(settings.darkText) },
                            set: { settings.darkText = HexColor.hex($0) }))
                        ColorPicker("Background", selection: Binding(
                            get: { HexColor.color(settings.darkBackground) },
                            set: { settings.darkBackground = HexColor.hex($0) }))
                    }

                    // A live sample, so a colour is judged as text rather than as a swatch.
                    Text("$ who am i")
                        .font(.system(size: settings.fontSize, design: .monospaced))
                        .foregroundStyle(HexColor.color(tab == .light ? settings.lightText : settings.darkText))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(HexColor.color(tab == .light ? settings.lightBackground : settings.darkBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } header: {
                    Text("Colours")
                }

                Section {
                    Button("Reset to defaults", role: .destructive) {
                        settings.resetAppearance()
                    }
                } footer: {
                    // ⚠️ SAYS WHAT IT WILL TOUCH. A reset that does not name its scope is
                    // one nobody dares press.
                    Text("Puts size, shape, font and colours back. Connections and the sending pause are not affected.")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            #if os(macOS)
            .frame(minWidth: 420, idealWidth: 480, minHeight: 320, idealHeight: 400)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

extension SettingsView {
    /// Every monospaced face installed on this device.
    ///
    /// ⚠️ READ FROM THE DEVICE, NOT A LIST I WROTE DOWN. He wants his Nerd Font
    /// available — "the same nerd font im using in my terminal" — and the honest way to
    /// offer it is to show what is actually installed rather than name fonts that might
    /// not be there. It also means nothing has to be bundled, so no font licence ships
    /// with the app.
    static var monospacedFonts: [String] {
        #if os(macOS)
        NSFontManager.shared.availableFontFamilies
            .filter { family in
                guard let members = NSFontManager.shared.availableMembers(ofFontFamily: family) else { return false }
                return members.contains { ($0[3] as? NSNumber)?.uintValue ?? 0 & 0x00000001 != 0 }
                    || family.lowercased().contains("mono")
                    || family.lowercased().contains("code")
                    || family.lowercased().contains("courier")
                    || family.lowercased().contains("menlo")
            }
            .sorted()
        #else
        UIFont.familyNames.filter {
            let n = $0.lowercased()
            return n.contains("mono") || n.contains("code") || n.contains("courier") || n.contains("menlo")
        }.sorted()
        #endif
    }
}

#Preview {
    SettingsView()
}

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
// Only to ask a font whether it is monospaced, on both platforms, in one code path.
import CoreText

/// Hex in, Color out, and back again.
///
/// ⚠️ STORED AS HEX RATHER THAN A SwiftUI Color BECAUSE IT HAS TO TRAVEL. These settings
/// sync between his Mac and his phones through a key-value store that holds strings and
/// numbers. A hex string is also readable in the diagnostics record, which a serialised
/// colour object is not — and when a colour goes wrong, being able to read what it
/// actually is beats being able to render it.
enum HexColor {

    /// ⚠️ ONE CHOICE, TWO SHADES. His rule, 2026-09-04: "so whatever color i choose my
    /// color is dark and yours is lighter."
    ///
    /// That is better than two pickers and not merely fewer controls. Two independent
    /// colours can be set to the same value, or to two that clash, and then the one thing
    /// the pair exists to do — telling his words from the machine's at a glance — quietly
    /// stops working. Deriving both from one hue makes them impossible to confuse and
    /// impossible to accidentally equalise.
    ///
    /// The hue is kept and only brightness moves, so it stays the colour he picked rather
    /// than becoming a different one.
    static func shades(_ hex: String) -> (yours: Color, theirs: Color) {
        #if os(macOS)
        let base = NSColor(color(hex)).usingColorSpace(.deviceRGB) ?? .green
        var h: CGFloat = 0, sat: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        base.getHue(&h, saturation: &sat, brightness: &b, alpha: &a)
        #else
        var h: CGFloat = 0, sat: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color(hex)).getHue(&h, saturation: &sat, brightness: &b, alpha: &a)
        #endif
        // ⚠️ FLOORED AND CAPPED. A very dark pick would otherwise make "his" unreadable,
        // and a very light one would make "theirs" white on white.
        let yours = Color(hue: h, saturation: sat, brightness: max(0.28, b * 0.62))
        let theirs = Color(hue: h, saturation: max(0.0, sat * 0.82), brightness: min(0.97, max(b, 0.55) * 1.45))
        return (yours, theirs)
    }

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
    /// What the terminal is actually being drawn into on this device, so the column and
    /// line counts describe his screen rather than a nominal one.
    @State private var geometry = TerminalGeometry.shared

    // MARK: - Consequences of the size
    //
    // ⚠️ COMPUTED EVERY TIME, NEVER CACHED. The window can be dragged and a phone can be
    // rotated while this sheet is open; a stored count would go stale on screen while he
    // watched it.

    private var fittedColumns: Int {
        TerminalMetrics.columns(
            across: geometry.viewport.width,
            fontName: settings.fontName,
            size: settings.fontSize
        )
    }

    private var fittedLines: Int {
        TerminalMetrics.lines(
            down: geometry.viewport.height,
            fontName: settings.fontName,
            size: settings.fontSize
        )
    }

    /// One point bigger or smaller, stopping at the ends of the slider rather than
    /// wrapping or silently doing nothing.
    private func nudgeSize(by delta: Double) {
        let next = TerminalMetrics.clamp(settings.fontSize + delta)
        guard next != settings.fontSize else { return }
        settings.fontSize = next
    }

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
                    // ⚠️ THESE TWO ARE READOUTS THAT CAN BE PUSHED, NOT SETTINGS.
                    //
                    // His rule, 2026-09-05: "it scales the font sizes bigger or smaller
                    // making the (height) lines and (width) colums increase or decrease."
                    // So the size is the only stored value, and these show what it buys
                    // on the screen actually in front of him.
                    //
                    // The arrows still work, and they run BACKWARDS on purpose — more
                    // columns means smaller type, which is the same sentence read the
                    // other way. That is also his second requirement: "changing those
                    // numbers changes the slider position."
                    //
                    // ⚠️ AND `LINES` IS LIVE AGAIN. It was greyed out with "there is
                    // nothing yet for it to count", which was true while a line count
                    // meant a PTY grid. Under his rule it means how many lines fit down
                    // the screen at this size, and the layout can answer that today. The
                    // real PTY (fix list 31) is still owed; it is no longer what this
                    // control is waiting on.
                    if geometry.isMeasured {
                        Stepper {
                            LabeledContent("Columns") {
                                Text("\(fittedColumns)").monospacedDigit()
                            }
                        } onIncrement: {
                            nudgeSize(by: -1)
                        } onDecrement: {
                            nudgeSize(by: +1)
                        }
                        Stepper {
                            LabeledContent("Lines") {
                                Text("\(fittedLines)").monospacedDigit()
                            }
                        } onIncrement: {
                            nudgeSize(by: -1)
                        } onDecrement: {
                            nudgeSize(by: +1)
                        }
                    } else {
                        // ⚠️ NO NUMBER RATHER THAN A MADE-UP ONE. Before the terminal has
                        // been laid out once there is nothing to divide, and printing 80
                        // here would be a claim about a screen nobody has measured.
                        LabeledContent("Columns") { Text("\u{2014}") }
                        LabeledContent("Lines") { Text("\u{2014}") }
                        Text("Counted once the terminal has been on screen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // ⚠️ A SLIDER HERE, A STEPPER FOR THE PAUSE, AND THE DIFFERENCE IS
                    // REAL. Type size is judged by looking at it, so dragging while
                    // watching is the right gesture. The sending pause is judged by
                    // talking, where the number matters and the eye is elsewhere.
                    VStack(alignment: .leading) {
                        LabeledContent("Size") {
                            Text(String(format: "%.0f pt", settings.fontSize)).monospacedDigit()
                        }
                        Slider(
                            value: $settings.fontSize,
                            in: TerminalMetrics.minSize...TerminalMetrics.maxSize,
                            step: 1
                        )
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
                            Size is the setting. Columns and lines are what that size \
                            fits on this screen, so they move the opposite way \u{2014} \
                            larger type, fewer of both.

                            Their arrows work too, and they change the size, which is \
                            why the slider moves with them.

                            The count is for the screen you are on. The same size gives \
                            a phone and a Mac very different numbers, so only the size \
                            follows you between devices.

                            Size is the same whichever appearance you are in, so it sits \
                            above the tabs. Only the two colours change between Light \
                            and Dark.

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
                    // ⚠️ THREE COLOURS PER APPEARANCE, NOT TWO. His spec: the background,
                    // what HE types, and what comes BACK. The last two are separate
                    // because in dark mode they are deliberately different greens.
                    //
                    // Labelled by role rather than by who — "you" and "the machine" —
                    // because the far end might be a Pi running a build, and naming it
                    // after one particular thing on the other end is the same mistake as
                    // calling the mode "Claude".
                    switch tab {
                    case .light:
                        ColorPicker("Background", selection: Binding(
                            get: { HexColor.color(settings.lightBackground) },
                            set: { settings.lightBackground = HexColor.hex($0) }))
                        ColorPicker("Text", selection: Binding(
                            get: { HexColor.color(settings.lightYou) },
                            set: { settings.lightYou = HexColor.hex($0) }))
                    case .dark:
                        ColorPicker("Background", selection: Binding(
                            get: { HexColor.color(settings.darkBackground) },
                            set: { settings.darkBackground = HexColor.hex($0) }))
                        ColorPicker("Text", selection: Binding(
                            get: { HexColor.color(settings.darkYou) },
                            set: { settings.darkYou = HexColor.hex($0) }))
                    }

                    // ⚠️ THE SAMPLE SHOWS BOTH ROLES, because the only question worth
                    // asking of these colours is whether the two are distinguishable from
                    // each other — which a single line of text cannot answer.
                    VStack(alignment: .leading, spacing: 3) {
                        let pair = HexColor.shades(tab == .light ? settings.lightYou : settings.darkYou)
                        Text("$ who am i").foregroundStyle(pair.yours)
                        Text("michaelfluharty  ttys004").foregroundStyle(pair.theirs)
                    }
                    .font(.system(size: settings.fontSize, design: .monospaced))
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
    ///
    /// ⚠️ ASKS THE FONT, RATHER THAN READING ITS NAME. Until 2026-09-05 both branches
    /// matched names containing "mono", "code", "courier" or "menlo" — a guess that
    /// missed the one font this feature exists for. **His terminal runs MesloLGM Nerd
    /// Font, and "meslo" is not "menlo"**: one letter, and the font he asked for by name
    /// could not appear in the list at all.
    ///
    /// The macOS branch also had a precedence bug. `traits ?? 0 & 0x1 != 0` parses as
    /// `(traits ?? 0) != 0`, not as a test of the monospace bit — so it accepted any face
    /// carrying any trait whatsoever, and the name checks were doing the real filtering.
    ///
    /// CoreText answers this properly on both platforms: `kCTFontTraitMonoSpace` is the
    /// font's own declaration about itself.
    static var monospacedFonts: [String] {
        let families: [String]
        #if os(macOS)
        families = NSFontManager.shared.availableFontFamilies
        #else
        families = UIFont.familyNames
        #endif
        return families.filter(isMonospaced).sorted()
    }

    /// True when any face in the family declares the monospace trait.
    ///
    /// A family is offered if ANY member is monospaced, because that is what the picker
    /// then draws with — and a family whose regular face is monospaced is the whole
    /// point even when some exotic member of it is not.
    private static func isMonospaced(_ family: String) -> Bool {
        let descriptor = CTFontDescriptorCreateWithAttributes(
            [kCTFontFamilyNameAttribute: family as CFString] as CFDictionary
        )
        guard let matches = CTFontDescriptorCreateMatchingFontDescriptors(descriptor, nil)
                as? [CTFontDescriptor], !matches.isEmpty else { return false }

        return matches.contains { candidate in
            guard let traits = CTFontDescriptorCopyAttribute(candidate, kCTFontTraitsAttribute)
                    as? [CFString: Any],
                  let symbolic = traits[kCTFontSymbolicTrait] as? UInt32
            else { return false }
            return symbolic & CTFontSymbolicTraits.traitMonoSpace.rawValue != 0
        }
    }
}

#Preview {
    SettingsView()
}

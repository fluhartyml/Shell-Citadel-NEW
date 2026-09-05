//
//  ConnectionEditor.swift
//  Shell Citadel
//
//  Where a connection is set up. Every field on this screen has a scar behind it.
//

import AVFoundation
import SwiftUI

struct ConnectionEditor: View {
    @Binding var connection: Connection
    @Binding var password: String

    /// What the Port field is currently showing. See the note at the Port field.
    @State private var portText = "22"

    /// True once he has typed a name himself, which stops the address from filling it in.
    ///
    /// ⚠️ WITHOUT THIS, ITEM 8 EATS HIS TYPING. "Name suggests itself from the Address"
    /// has to stop suggesting the moment there is a real answer, or every keystroke in
    /// the Address field overwrites a name he chose on purpose.
    @State private var nameIsHis = false

    var body: some View {
        Form {
            // ─────────────────────────────────────────────────────────────────────
            // SERVER NAME — items 5, 6, 7, 8, 9, 10
            // ─────────────────────────────────────────────────────────────────────
            Section {
                // ⚠️ TextField(title:text:prompt:) — NOT LabeledContent WRAPPING ONE.
                //
                // This is the whole of fix-list item 2, "every field is doubled". The old
                // form read:
                //
                //     LabeledContent("Name") { TextField("My Mac", text: $name) }
                //
                // On iOS that renders as one row: the label, and "My Mac" greyed inside
                // the box. On macOS a TextField's title is drawn as its OWN attached
                // label — so LabeledContent's label and the TextField's title both
                // appear, and the row reads "Name  My Mac" followed by the empty box.
                //
                // The same mistake made the sheet too wide, which is item 1: two labels
                // per row plus a trailing-aligned field is more content than the sheet
                // was ever going to fit, and macOS clipped the ends off rather than wrap.
                //
                // `title` is the label on both platforms; `prompt` is the placeholder on
                // both. One row, one label, one hint, nothing clipped.
                TextField("Name", text: $connection.name, prompt: Text(suggestedName))
                    .onChange(of: connection.name) { _, new in
                        if !new.isEmpty { nameIsHis = true }
                    }

                TextField("Address", text: $connection.host, prompt: Text(addressPrompt))
                    .autocorrectionDisabled()
                    .onChange(of: connection.host) { _, _ in
                        // Item 8 — the name follows the address until he names it himself.
                        if !nameIsHis { connection.name = "" }
                    }
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif

                // ⚠️ PLAIN TEXT, NOT A FORMATTED VALUE.
                //
                // This was TextField(value:format:) in the old app. A formatter-bound
                // field validates on every keystroke, so clearing it to type a new port
                // leaves it momentarily empty — which is not a number — and the binding
                // writes the old value straight back. From outside, the field simply
                // refuses to change. Michael: "Port 22 doesnt let you tap it, it wont
                // let you change from 22." Item 10 records that it stays 22 and stays
                // editable, so nobody "tidies" this back into a formatter later.
                TextField("Port", text: $portText, prompt: Text("22"))
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .onAppear { portText = String(connection.port) }
                    .onChange(of: portText) { _, new in
                        let digits = new.filter(\.isNumber)
                        if digits != new { portText = digits }
                        if let n = Int(digits), (1...65535).contains(n) { connection.port = n }
                    }
            } header: {
                // Item 6 — "The machine" is gone.
                HStack {
                    Text("Server name")
                    MoreInfo(
                        title: "the address",
                        detail: """
                        A name ending in .local follows the machine, so it keeps working \
                        when the address changes.

                        Shell Citadel remembers the address that worked and falls back to \
                        it if the name cannot be looked up.
                        """
                    )
                }
            } footer: {
                // Item 4 — one short line. Item 5 — it does not say "Mac".
                Text("Anything running an SSH server.")
            }

            // ─────────────────────────────────────────────────────────────────────
            // SIGN IN — items 11, 12, 13, 14, 15
            // ─────────────────────────────────────────────────────────────────────
            Section {
                // ⛔ DO NOT ADD .textContentType TO THESE TWO. 2026-09-04.
                //
                // .textContentType(.username) beside .textContentType(.password) makes
                // iOS treat the pair as a login form and drive AutoFill. AutoFill takes
                // the field over: the caret appears for a moment and is then taken away,
                // and nothing typed lands. Michael: "i tab the box to type my name it
                // has a cursor once and then it dissapears."
                //
                // It also fills a CREDENTIAL, not a field — tapping it on the password
                // overwrote his user name with the display name stored beside it,
                // "michael fluharty", with a space, which SSH rejects outright.
                //
                // The old app carried this from 2026-08-22 and it survived three
                // rollbacks because every rollback point was newer than the cause.
                TextField("Account", text: $connection.username, prompt: Text(accountPrompt))
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif

                SecureField("Password", text: $password, prompt: Text("Required"))

                if connection.username.contains(" ") {
                    Label(
                        "An account name cannot contain a space. SSH wants the short account name \u{2014} the one the home folder is named after.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(.orange)
                }
            } header: {
                HStack {
                    Text("Sign in")
                    // Item 13 and item 15, both behind the ⓘ rather than under the section.
                    MoreInfo(
                        title: "signing in",
                        detail: """
                        Account: no spaces, and nothing the far end treats as an \
                        illegal character. Use the short account name, not the full name \
                        shown on a login screen.

                        The password is case sensitive, and is kept in this device's \
                        Keychain \u{2014} never in iCloud, never in a backup.
                        """
                    )
                }
            } footer: {
                // ⚠️ CORRECTED 2026-09-04. This read "Both are case sensitive", which is
                // wrong about the account and was my mis-diagnosis of his afternoon: the
                // failure was a dropped letter in `michaelfuharty`, not the capitals in
                // `MichaelFluharty`. macOS resolves accounts case-insensitively —
                // verified against the live directory, not recalled.
                Text("The password is case sensitive.")
            }

            if let remembered = connection.lastKnownAddress {
                Section {
                    LabeledContent("Last reached at", value: remembered)
                        .font(.system(.footnote, design: .monospaced))
                } footer: {
                    Text("Used if the name cannot be looked up.")
                }
            }

            // ─────────────────────────────────────────────────────────────────────
            // MODE — items 16, 17, 18, 19, 20. LAST ON THE SHEET, and it owns the
            // settings that belong to it.
            //
            // His instruction, 2026-09-04: "the mode has direct and attach to session,
            // under the direct tab relocate the starting folder to live there, and under
            // the attach to session have the tag (user definable) toggle, session, and
            // all the other stuff user definable."
            //
            // ⚠️ THE POINT IS NOT TIDINESS. Start in folder cannot exist in Attach mode
            // at all — see Connection.startFolder — and a control that is meaningless in
            // the mode you are in is a control you have to reason about and dismiss.
            // Putting each mode's settings inside the mode makes that impossible.
            // ─────────────────────────────────────────────────────────────────────
            Section {
                Picker("Mode", selection: $connection.mode) {
                    ForEach(Connection.Mode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch connection.mode {
                case .shell:
                    // Item 18 — it was in the old app and had not been rebuilt.
                    TextField("Start in folder",
                              text: $connection.startFolder,
                              prompt: Text("Wherever the login lands"))
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif

                case .tmux:
                    TextField("Session", text: $connection.tmuxSession, prompt: Text("main"))
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif

                    TextField("Replies file", text: $connection.replyPath, prompt: Text("~/session-output.txt"))
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif

                    // Item 17 — kept, and reframed as the generic feature it is.
                    Toggle("Timestamp each message", isOn: $connection.stampMessages)
                }

                // ⚠️ THE VOICE BELONGS TO THE CONNECTION, NOT THE DEVICE. His design,
                // 2026-09-04: "for each connection card has a speech voice drop down."
                //
                // The reason is not decoration. He listens to this app from another room,
                // so with more than one connection open the voice is how he knows WHICH
                // machine just spoke — the identity moves into the audio, where he
                // actually is, instead of staying on a screen he is not looking at.
                //
                // ⚠️ "System default" IS THE FIRST ENTRY AND THE DEFAULT VALUE. He has
                // twice corrected an overridden voice: use the one he set in his own OS
                // settings unless he says otherwise here. An unset picker must never
                // quietly become a choice.
                Picker("Voice", selection: $connection.voiceIdentifier) {
                    Text("System default").tag(String?.none)
                    ForEach(SpokenOutput.availableVoices, id: \.identifier) { voice in
                        Text(SpokenOutput.label(for: voice)).tag(String?.some(voice.identifier))
                    }
                }
                // ⚠️ IT SAYS HELLO THE MOMENT YOU PICK ONE. His idea: a list of names is
                // blind, and the only thing a voice has to do for him is be tellable
                // apart from another room. Hearing it is the only way to judge that.
                .onChange(of: connection.voiceIdentifier) { _, chosen in
                    SpokenOutput.shared.preview(voiceIdentifier: chosen)
                }

                if let problem = SpokenOutput.shared.lastProblem {
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                HStack {
                    Text("Mode")
                    // Item 20 — the tmux paragraph goes behind the ⓘ.
                    MoreInfo(
                        title: "the two modes",
                        detail: """
                        Direct: type a command, the machine answers. Nothing else is \
                        running.

                        Attach to session: what you type is handed to a program already \
                        running in a tmux session, and its replies are read from a file \
                        that program writes \u{2014} not from the terminal's output. \
                        Needs tmux on that machine.

                        Timestamps are off in Direct always, because a stamp typed into a \
                        shell is garbage on the command line.
                        """
                    )
                }
            }
        }
        // ⚠️ .grouped IS FIX-LIST ITEM 3. Without it macOS lays a Form out as a plain
        // stack: the section headers render as ordinary text jammed against the footer
        // above them, which is exactly what he described — "so the sheet reads as one
        // wall". .grouped gives macOS the inset, boxed sections it draws in System
        // Settings, where a header looks like a header because it is one.
        .formStyle(.grouped)
        .navigationTitle("Connection")
    }

    // MARK: - Runtime suggestions  (items 9 and 12)

    /// What to offer as the Address. The running machine's own name, where there is one.
    private var addressPrompt: String {
        LocalMachine.bonjourName ?? "server.local"
    }

    /// What to offer as the Account.
    ///
    /// ⚠️ EMPTY ON THE PHONE, NOT A GUESS. iOS has no short account name to offer, and a
    /// plausible-looking wrong suggestion is worse than none — it is the kind of thing
    /// somebody accepts without reading.
    private var accountPrompt: String {
        LocalMachine.accountName ?? "account"
    }

    /// What to offer as the Name — item 8, the name follows the address.
    private var suggestedName: String {
        connection.host.isEmpty ? "Server" : connection.host
    }
}

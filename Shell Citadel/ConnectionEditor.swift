//
//  ConnectionEditor.swift
//  Shell Citadel
//
//  Where a connection is set up. Every field on this screen has a scar behind it.
//

import SwiftUI

struct ConnectionEditor: View {
    @Binding var connection: Connection
    @Binding var password: String

    /// What the Port field is currently showing. See the note at the Port field.
    @State private var portText = "22"

    var body: some View {
        Form {
            Section {
                LabeledContent("Name") {
                    TextField("My Mac", text: $connection.name)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Address") {
                    TextField("michaels-macbook-air.local", text: $connection.host)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                }
                // ⚠️ PLAIN TEXT, NOT A FORMATTED VALUE.
                //
                // This was TextField(value:format:) in the old app. A formatter-bound
                // field validates on every keystroke, so clearing it to type a new port
                // leaves it momentarily empty — which is not a number — and the binding
                // writes the old value straight back. From outside, the field simply
                // refuses to change. Michael: "Port 22 doesnt let you tap it, it wont
                // let you change from 22."
                LabeledContent("Port") {
                    TextField("22", text: $portText)
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .onAppear { portText = String(connection.port) }
                        .onChange(of: portText) { _, new in
                            let digits = new.filter(\.isNumber)
                            if digits != new { portText = digits }
                            if let n = Int(digits), (1...65535).contains(n) { connection.port = n }
                        }
                }
            } header: {
                Text("The machine")
            } footer: {
                // Saying WHY a name is better than an address, because the reason is his.
                Text("A name like michaels-macbook-air.local follows the machine, so it keeps working when the address changes. Shell Citadel remembers the address that worked and falls back to it if the name cannot be looked up.")
            }

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
                LabeledContent("User name") {
                    TextField("your account name", text: $connection.username)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                }
                LabeledContent("Password") {
                    SecureField("required", text: $password)
                        .multilineTextAlignment(.trailing)
                }
                if connection.username.contains(" ") {
                    Label(
                        "A user name cannot contain a space. SSH wants your short account name \u{2014} the one your home folder is named after.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(.orange)
                }
            } header: {
                Text("Sign in")
            } footer: {
                Text("The password is kept in this device's Keychain \u{2014} never in iCloud, never in a backup. On a Mac, turn on Remote Login in System Settings \u{203A} General \u{203A} Sharing.")
            }

            Section {
                Picker("Mode", selection: $connection.mode) {
                    ForEach(Connection.Mode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if connection.mode == .claude {
                    LabeledContent("Session") {
                        TextField("claude", text: $connection.tmuxSession)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                    }
                    LabeledContent("Replies file") {
                        TextField("~/session-output.txt", text: $connection.replyPath)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                    }
                }
            } header: {
                Text("Mode")
            } footer: {
                // These are two different things, not one thing with a switch, and
                // saying so here is cheaper than him discovering it.
                Text(connection.mode == .claude
                     ? "What you type is handed to a running session, and what comes back is what Claude chose to say \u{2014} not the terminal's output. Needs tmux on that machine."
                     : "Type a command, the machine answers. Nothing else is running.")
            }

            if let remembered = connection.lastKnownAddress {
                Section {
                    LabeledContent("Last reached at", value: remembered)
                        .font(.system(.footnote, design: .monospaced))
                } footer: {
                    Text("Used automatically if the name above cannot be looked up.")
                }
            }
        }
        .navigationTitle("Connection")
    }
}

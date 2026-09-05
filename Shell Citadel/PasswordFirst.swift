//
//  PasswordFirst.swift
//  Shell Citadel
//
//  What a typed ssh line opens: the one field it did not contain.
//
//  Michael, 2026-09-04, after typing `ssh MichaelFluharty@Michaels-macbook-air.local` and
//  landing in the connections list: "it did not operate as expected. i am assuming it
//  poped up to get a password first. i would invision a enter password field would show
//  with the '@michaels-macbook-air.local' would be the card title already populated."
//
//  He is describing the right screen. The typed line already carried the account and the
//  host — everything except the secret — so sending him to a full editor, or worse to a
//  list of other connections, asks him to re-enter what he just typed. This asks for the
//  one thing missing and nothing else.
//
//  ⚠️ IT SHOWS THE ACCOUNT AND HOST RATHER THAN HIDING THEM, AND THAT IS THE SECOND JOB
//  OF THIS SCREEN. He typed `MichaelFluharty` with two capitals; his Mac's account is
//  `michaelfluharty`, all lowercase, and SSH is case sensitive — that exact mistake cost
//  him an afternoon today and surfaced only as "SSHClientError 4". Printing the account
//  back to him in a monospaced face, before he commits, is the cheapest possible place to
//  catch it.
//
//  ⛔ NO .textContentType HERE. The old app's password-first editor used
//  .textContentType(.password), which is half of the AutoFill pair that took the caret
//  away from every field it touched and survived three rollbacks. This screen is the same
//  idea written again without it.
//

import SwiftUI

struct PasswordFirst: View {
    @Environment(\.dismiss) private var dismiss

    let onConnect: (Connection, String) -> Void

    /// ⚠️ EDITABLE HERE, NOT JUST DISPLAYED. He asked for the mode on this screen:
    /// "under the password it should also provide direct attach to session tabs."
    ///
    /// A typed ssh line can only ever mean Direct — nothing in `ssh user@host` names a
    /// session — but Attach is what he actually wants most of the time, and making him
    /// connect first and then go and change it means connecting twice. So the one thing
    /// the typed line could not carry is offered right where the password is.
    @State private var connection: Connection

    init(connection: Connection, onConnect: @escaping (Connection, String) -> Void) {
        _connection = State(initialValue: connection)
        self.onConnect = onConnect
    }

    @State private var password = ""
    @FocusState private var passwordFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Account") {
                        Text(connection.username)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    LabeledContent("Address") {
                        Text(connection.host)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    if connection.port != 22 {
                        LabeledContent("Port") { Text("\(connection.port)").monospacedDigit() }
                    }
                } header: {
                    Text("Connecting to")
                } footer: {
                    Text("Taken from what you typed. The account is case sensitive.")
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section {
                    SecureField("Password", text: $password, prompt: Text("Required"))
                        .focused($passwordFocused)
                        .onSubmit(go)
                } footer: {
                    Text("Kept in this device's Keychain \u{2014} never in iCloud, never in a backup.")
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section {
                    Picker("Mode", selection: $connection.mode) {
                        ForEach(Connection.Mode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    // ⚠️ ONLY THE CHOSEN MODE'S SETTINGS APPEAR, the same rule as the
                    // editor. A field that cannot apply to the mode you are in is a
                    // field you have to read and dismiss.
                    if connection.mode == .tmux {
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
                    }
                } header: {
                    HStack {
                        Text("Mode")
                        MoreInfo(
                            title: "the two modes",
                            detail: """
                            Direct: type a command, the machine answers.

                            Attach to session: what you type is handed to a program \
                            already running in a tmux session, and its replies are read \
                            from a file that program writes.

                            A typed ssh line always starts as Direct, because nothing in \
                            it names a session.
                            """
                        )
                    }
                }
            }
            .formStyle(.grouped)
            // ⚠️ THE TITLE IS THE MACHINE, WHICH IS WHAT HE ASKED FOR — the card he is
            // about to create, named before it exists.
            .navigationTitle(connection.title)
            #if os(macOS)
            .frame(minWidth: 420, idealWidth: 480, minHeight: 300, idealHeight: 340)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Connect", action: go)
                        .disabled(password.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            // The password is the only thing left, so the caret starts in it.
            .onAppear { passwordFocused = true }
        }
    }

    private func go() {
        guard !password.isEmpty else { return }
        onConnect(connection, password)
        dismiss()
    }
}

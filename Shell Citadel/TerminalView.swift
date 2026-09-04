//
//  TerminalView.swift
//  Shell Citadel
//
//  Roadmap step 1. Type a command, see the real answer, and `cd` sticks.
//
//  ⚠️ THE COMPOSER IS THE ONLY VIEW IN THIS APP THAT TAKES THE KEYBOARD (step 0.2).
//  There is no invisible key catcher here and there must never be one. The transcript
//  is a ScrollView of text — it is not focusable, it does not hold first responder, and
//  it cannot take the caret back off the field he is typing into. That single sentence
//  is the difference between this app and the one it replaced.
//

import SwiftUI
import PhotosUI
#if os(iOS)
import VisionKit
#endif

struct TerminalView: View {
    @State private var store = ConnectionStore()
    @State private var session = SSHSession()
    @State private var diagnostics = Diagnostics.shared
    @State private var spoken = SpokenOutput.shared
    @StateObject private var dictation = Dictation.shared

    @State private var connection = Connection()
    @State private var password = ""
    @State private var transcript: [TranscriptLine] = []
    @State private var input = ""
    @State private var isConnected = false
    @State private var isBusy = false
    @State private var showingConnection = false
    @State private var showingAbout = false
    @State private var showingSettings = false
    @State private var light = LinkLight()
    @State private var replyTask: Task<Void, Never>?
    @State private var replyOffset = 0

    // ⚠️ THE DEMO IS A REJECTION GUARD. See DemoMode.swift.
    @State private var isDemo = false
    @State private var demoTask: Task<Void, Never>?
    /// The real transcript, put back when the demonstration ends.
    @State private var transcriptBeforeDemo: [TranscriptLine] = []

    // The "+" beside the composer. Michael, 2026-08-25: "I want to add a plus next ti
    // the predictive text boxes to add a camera capture function" — "image or scan".
    @State private var pickedItem: PhotosPickerItem?
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var showingScanner = false

    /// The composer's focus. The ONLY @FocusState in the app.
    @FocusState private var composerFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ⚠️ ALWAYS ON SCREEN WHILE THE DEMO RUNS, AND THERE IS NO WAY TO CLOSE
                // IT. A simulation somebody could mistake for a real connection is both
                // a rejection reason and a lie. It says "not connected" in plain words
                // rather than "demo", because that is the thing the reader must not be
                // wrong about.
                if isDemo {
                    HStack {
                        Text(DemoMode.banner)
                            .font(.footnote.weight(.semibold))
                        Spacer()
                        // ⚠️ THIS DOES NOT DISMISS THE NOTICE, IT ENDS THE STATE THE
                        // NOTICE REPORTS. Rule 1 says the banner is never dismissible,
                        // and it is not: there is no way to be in the simulation without
                        // this bar on screen. But a demonstration with no exit is a trap
                        // — the reviewer who wants to try their own machine next has to
                        // force-quit — so ending the simulation has to be one tap, and
                        // the bar goes away because the simulation did.
                        Button("End") { endDemo() }
                            .font(.footnote.weight(.semibold))
                            .buttonStyle(.borderless)
                            .foregroundStyle(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.orange)
                    .foregroundStyle(.black)
                }
                transcriptView
                Divider()
                composer
            }
            .navigationTitle(connection.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(isConnected ? "Disconnect" : "Connect") {
                        Task { await toggleConnection() }
                    }
                    .disabled(isBusy || connection.host.isEmpty || connection.username.isEmpty)
                }
                ToolbarItem(placement: .automatic) {
                    Button { showingConnection = true } label: {
                        // ⚠️ HIS PICK, 2026-09-04: "phone connection fill for
                        // connections cards." A handset with signal arcs — a modem
                        // reaching out, which is what this sheet sets up. It also stops
                        // this button and Settings drawing the same sliders glyph, which
                        // he spotted the moment both were on screen.
                        Label("Connection", systemImage: "phone.connection.fill")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    // ⚠️ ONE TAP, ALWAYS REACHABLE. Whether the room is quiet changes
                    // minute to minute, and burying this in a settings sheet means it is
                    // still talking while he is deciding where to find the switch.
                    Button {
                        spoken.isEnabled.toggle()
                    } label: {
                        Label("Speak output",
                              systemImage: spoken.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    }
                    .tint(spoken.isEnabled ? .accentColor : .red)
                }
                ToolbarItem(placement: .navigation) {
                    LinkLightView(light: light)
                }
                ToolbarItem(placement: .automatic) {
                    Button { showingSettings = true } label: {
                        Label("Settings", systemImage: "slider.horizontal.3")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button { showingAbout = true } label: {
                        Label("About", systemImage: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showingConnection) {
                NavigationStack {
                    ConnectionEditor(connection: $connection, password: $password)
                        // Same reason as About: a Mac sheet sizes to its content and a
                        // Form has no natural size, so it collapses without this.
                        #if os(macOS)
                        .frame(minWidth: 480, idealWidth: 560, minHeight: 560, idealHeight: 680)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    store.save(connection)
                                    _ = CredentialStore.save(password: password, for: connection)
                                    showingConnection = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(isPresented: $showingAbout) {
                AboutView(onStartDemo: startDemo)
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $pickedItem, matching: .images)
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                Task {
                    defer { pickedItem = nil }
                    guard let data = try? await item.loadTransferable(type: Data.self) else {
                        transcript.append(.init(kind: .failure, text: "That picture could not be read."))
                        return
                    }
                    #if os(iOS)
                    guard let image = UIImage(data: data), let jpeg = PhotoSend.prepare(image) else {
                        transcript.append(.init(kind: .failure, text: "That picture could not be prepared."))
                        return
                    }
                    await sendImage(jpeg)
                    #else
                    await sendImage(data)
                    #endif
                }
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $showingCamera) {
                CameraCapture(onCapture: { image in
                    showingCamera = false
                    guard let jpeg = PhotoSend.prepare(image) else { return }
                    Task { await sendImage(jpeg) }
                }, onCancel: { showingCamera = false })
                .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showingScanner) {
                DocumentScanner(onScan: { pages in
                    showingScanner = false
                    Task {
                        // In order, one at a time. A two-sided form sent as one page is
                        // a form with half of it missing.
                        for page in pages {
                            guard let jpeg = PhotoSend.prepare(page) else { continue }
                            await sendImage(jpeg)
                        }
                    }
                }, onCancel: { showingScanner = false })
                .ignoresSafeArea()
            }
            #endif
        }
        .onAppear {
            restore()
            // One place decides who owns the audio path — register the microphone with
            // it so speech can silence the mic without either file importing the other.
            dictation.registerWithCoordinator()
            dictation.onUtterance = { text in
                input = text
                Task { await send() }
            }
            dictation.onCancelled = {
                input = ""
                transcript.append(.init(kind: .status, text: "Scratched."))
            }
        }
        // What he is saying, shown as it is recognised. Without this the pause is a
        // guessing game: he cannot tell whether it heard him until it has already sent.
        .safeAreaInset(edge: .bottom) {
            if dictation.isListening, !dictation.partial.isEmpty {
                Text(dictation.partial)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Pieces

    private var transcriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(transcript) { line in
                        Text(line.text)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(line.kind.color)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .id(line.id)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .onChange(of: transcript.count) { _, _ in
                if let last = transcript.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 8) {
            // ⚠️ A MENU, NOT A BUTTON THAT GUESSES. A page and a cable want different
            // capture paths — the document scanner hunts for edges a cable does not
            // have — and choosing wrong wastes a photograph he had to get into position
            // to take.
            Menu {
                Button {
                    showingPhotoPicker = true
                } label: {
                    Label("Photo or screenshot", systemImage: "photo.on.rectangle")
                }
                #if os(iOS)
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Take a picture", systemImage: "camera")
                    }
                }
                if VNDocumentCameraViewController.isSupported {
                    Button {
                        showingScanner = true
                    } label: {
                        Label("Scan a document", systemImage: "doc.viewfinder")
                    }
                }
                #endif
            } label: {
                Image(systemName: "plus.circle.fill").font(.title2)
            }
            .disabled(!isConnected || isBusy)

            // ⚠️ THE MICROPHONE IS A TOGGLE HE CAN ALWAYS REACH, and its colour IS the
            // state. Michael has said repeatedly that he forgets to mute — the failure
            // is not knowing whether it is listening, so the control has to answer that
            // question by looking at it rather than by being tapped.
            Button {
                if dictation.isListening {
                    dictation.stop()
                    VoiceCoordinator.shared.didStopListening()
                } else {
                    VoiceCoordinator.shared.willListen()
                    dictation.start()
                }
            } label: {
                // ⚠️ HIS COLOURS, AND THEY ARE THE OPPOSITE OF WHAT WAS HERE.
                //
                // 2026-09-04: "add the red mute mic and green [wiggling] while noise is
                // present mic glyphs."
                //
                // This drew RED while listening, which is backwards from every other
                // control he owns — red is the state you want to leave, not the state
                // that is working. Muted is red. Live is green.
                //
                // ⚠️ AND GREEN ALONE IS NOT ENOUGH, WHICH IS THE POINT OF THE MOVEMENT.
                // A green mic says the app THINKS it is listening. It says nothing about
                // whether the microphone is actually picking anything up — and that gap
                // is exactly where his afternoon went: his voice was not reaching it and
                // nothing on screen distinguished "listening to silence" from "listening
                // to you". `Dictation.level` is a real measurement of the room, so a
                // glyph that moves with it answers the question the colour cannot.
                Image(systemName: dictation.isListening ? "mic.fill" : "mic.slash")
                    .font(.title2)
                    .foregroundStyle(dictation.isListening ? .green : .red)
                    .scaleEffect(dictation.isListening ? 1.0 + CGFloat(dictation.level) * 0.45 : 1.0)
                    .animation(.easeOut(duration: 0.12), value: dictation.level)
                    .accessibilityLabel(dictation.isListening ? "Microphone on" : "Microphone muted")
            }
            .disabled(!isConnected || isBusy)

            TextField(isConnected ? "Type a command" : "Not connected", text: $input)
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .focused($composerFocused)
                .disabled(!isConnected || isBusy)
                .onSubmit { Task { await send() } }
                // Recording the focus change is the whole of step 0.3 in one line: the
                // question "who has the keyboard" now has an answer that is written
                // down rather than inferred from a blinking cursor.
                .onChange(of: composerFocused) { _, focused in
                    diagnostics.focusChanged(to: focused ? "composer" : "none")
                }

            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.title2)
            }
            .disabled(!isConnected || isBusy || input.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(10)
    }

    // MARK: - Doing things

    /// The source tag. More than one app types into the same session, and without this
    /// Claude cannot tell which one he is speaking from.
    static var sourceTag: String {
        #if os(macOS)
        "SC-Mac"
        #else
        "SC"
        #endif
    }

    /// Follows the reply file so what Claude says arrives on its own, without being
    /// asked for. Cancelled and restarted with the connection, never left running.
    private func startFollowingReplies() {
        replyTask?.cancel()
        replyTask = Task {
            do {
                let stream = try await session.replyLines(path: connection.replyPath, startingAtByte: replyOffset)
                for try await chunk in stream {
                    transcript.append(.init(kind: .output, text: chunk.text))
                    light.didReceive()
                    replyOffset = chunk.offsetAfter
                    // Speaking it is the point of the mode: he is not looking at the
                    // screen, which is why the reply channel is sentences and not a
                    // terminal stream in the first place.
                    spoken.speak(chunk.text)
                }
            } catch {
                if !Task.isCancelled {
                    transcript.append(.init(kind: .failure, text: error.localizedDescription))
                }
            }
        }
    }

    private func restore() {
        if let first = store.connections.first {
            connection = first
            password = CredentialStore.password(for: first) ?? ""
        }
    }

    private func toggleConnection() async {
        if isConnected {
            replyTask?.cancel()
            replyTask = nil
            await session.close()
            isConnected = false
            light.markDown()
            transcript.append(.init(kind: .status, text: "Disconnected."))
            return
        }

        isBusy = true
        defer { isBusy = false }
        // ⚠️ A REAL CONNECTION ENDS THE SIMULATION, ALWAYS. The two states must never
        // be able to overlap: a banner saying "not connected" above a live session
        // would be worse than either one alone.
        if isDemo { endDemo() }

        transcript.append(.init(kind: .status, text: "Connecting to \(connection.host)\u{2026}"))
        do {
            try await session.connect(to: connection, password: password)
            isConnected = true

            // Remember the address that actually worked, so a name that stops resolving
            // has somewhere to fall back to. This is the second half of the addressing
            // decision and it costs one line.
            if let used = await session.addressUsed, used != connection.host {
                connection.lastKnownAddress = used
                store.save(connection)
                transcript.append(.init(kind: .status, text: "Reached it at \(used) \u{2014} the name did not resolve."))
            } else if let used = await session.addressUsed {
                connection.lastKnownAddress = used
                store.save(connection)
            }

            if await session.trustedOnFirstUse {
                transcript.append(.init(kind: .status, text: "First time connecting to this machine \u{2014} its key has been recorded."))
            }
            transcript.append(.init(kind: .status, text: "Connected."))
            light.start(pinging: session)
            composerFocused = true
            if connection.mode == .tmux { startFollowingReplies() }
        } catch {
            // Say the real reason. "Could not reach the server" for every cause is what
            // turned one stale address into an hour of guessing on 2026-09-04.
            transcript.append(.init(kind: .failure, text: error.localizedDescription))
        }
    }

    /// Sends prepared image bytes to the Mac and says where they landed.
    ///
    /// ⚠️ SAYING THE PATH IS THE FEATURE, not politeness. Claude can then look at it
    /// without being told where, and he can see that it arrived rather than trusting a
    /// spinner that stopped.
    private func sendImage(_ data: Data) async {
        isBusy = true
        defer { isBusy = false }
        let name = PhotoSend.filename()
        transcript.append(.init(kind: .status, text: "Sending \(name), \(data.count / 1024) KB"))
        do {
            let path = try await session.upload(data, named: name, toFolder: "Uploads")
            transcript.append(.init(kind: .output, text: path))
        } catch {
            transcript.append(.init(kind: .failure, text: error.localizedDescription))
            light.markDown()
        }
        composerFocused = true
    }

    /// Play the script. Touches nothing but the transcript.
    ///
    /// ⚠️ IT KEEPS THE REAL TRANSCRIPT AND PUTS IT BACK. Somebody trying the demo out of
    /// curiosity mid-session should not lose what they were doing.
    private func startDemo() {
        demoTask?.cancel()
        transcriptBeforeDemo = transcript
        transcript = []
        isDemo = true
        demoTask = Task {
            for beat in DemoMode.script {
                try? await Task.sleep(for: .seconds(beat.delay))
                if Task.isCancelled { return }
                transcript.append(.init(kind: beat.kind, text: beat.text))
            }
            // ⚠️ THE SCRIPT ENDING DOES NOT END THE DEMO. Wiping the transcript the
            // moment the last line lands would take the demonstration away from
            // somebody still reading it. The state ends when they say so, or when they
            // connect to something real.
        }
    }

    private func endDemo() {
        demoTask?.cancel()
        demoTask = nil
        isDemo = false
        transcript = transcriptBeforeDemo
        transcriptBeforeDemo = []
    }

    private func send() async {
        let command = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }
        input = ""
        transcript.append(.init(kind: .command, text: "$ \(command)"))

        // ⚠️ THE NETWORK GUARD. Rule 2 of DemoMode: nothing here may reach a socket.
        // It answers rather than staying silent, because silence during a demonstration
        // reads as a hung app \u{2014} which is the exact impression this mode exists to
        // disprove.
        if isDemo {
            transcript.append(.init(kind: .status, text: DemoMode.reply(to: command)))
            return
        }
        isBusy = true
        defer { isBusy = false }
        // ⚠️ TWO DIFFERENT THINGS, NOT ONE WITH A FLAG. In Claude mode the message is
        // HANDED to a running session and the answer arrives later on its own channel;
        // there is no output to wait for here, and waiting would look like a hang.
        if connection.mode == .tmux {
            do {
                try await session.sendToSession(command, session: connection.tmuxSession, tag: Self.sourceTag, stamped: connection.stampMessages)
                // ⚠️ ONLY IN ATTACH MODE. In Direct mode the answer comes back on the
                // same call and the wait is already over by the time this line runs.
                light.didSend()
            } catch {
                transcript.append(.init(kind: .failure, text: error.localizedDescription))
            }
            composerFocused = true
            return
        }

        do {
            let output = try await session.runTrackingDirectory(command)
            if !output.isEmpty {
                transcript.append(.init(kind: .output, text: output))
                // Step 3: new output speaks itself the moment it lands, so the loop
                // closes without him having to ask for each half of it.
                spoken.speak(output)
            }
        } catch {
            transcript.append(.init(kind: .failure, text: error.localizedDescription))
            await session.markDisconnected()
            isConnected = false
        }
        composerFocused = true
    }
}

/// One line in the transcript.
struct TranscriptLine: Identifiable {
    enum Kind {
        case command, output, status, failure

        var color: Color {
            switch self {
            case .command: .accentColor
            case .output: .primary
            case .status: .secondary
            case .failure: .orange
            }
        }
    }

    let id = UUID()
    let kind: Kind
    let text: String
}

#Preview {
    TerminalView()
}

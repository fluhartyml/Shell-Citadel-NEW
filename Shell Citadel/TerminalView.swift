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

    @State private var settings = SyncedSettings.shared
    @Environment(\.colorScheme) private var scheme

    /// The face and size he chose, or the system monospaced face if he chose nothing.
    private var terminalFont: Font {
        settings.fontName.isEmpty
            ? .system(size: settings.fontSize, design: .monospaced)
            : .custom(settings.fontName, size: settings.fontSize)
    }

    /// ⚠️ HIS TEXT COLOUR FOR ORDINARY OUTPUT; THE SEMANTIC ONES STAY SEMANTIC.
    ///
    /// A failure has to stay orange and a status has to stay quiet even after he sets
    /// the text colour to something else, because those colours are carrying meaning
    /// rather than taste. Only `.output` and `.command` — the far end's own words, and
    /// his — take the colour he picked.
    private func colour(for kind: TranscriptLine.Kind) -> Color {
        let chosen = HexColor.color(scheme == .dark ? settings.darkText : settings.lightText)
        switch kind {
        case .output: return chosen
        case .command: return chosen.opacity(0.75)
        case .status, .failure: return kind.color
        }
    }

    /// The composer's focus. The ONLY @FocusState in the app.
    @FocusState private var composerFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ⚠️ THE STATUS ROW, DIRECTLY UNDER THE TOOLBAR — his placement: "the
                // connection status should be on the row below the sliders."
                //
                // It reads full width instead of competing for toolbar space, which is
                // what the waiting clock needs: the seconds change once a second and a
                // number that resizes its own container is a number that makes the row
                // twitch. Here it has room to count without moving anything.
                HStack {
                    LinkLightView(light: light)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.bar)
                Divider()

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
            // ⚠️ THE ORDER IS HIS, STATED CONTROL BY CONTROL, 2026-09-04: "the phone
            // to the far left and the mic the speaker then the (i) far right", with the
            // connection status "on the row below".
            //
            // It reads as one sentence left to right: how you get there, whether it can
            // hear you, whether it can talk to you, how it is set up, what it is. The
            // status came OUT of this row because a state is not an action — it sat among
            // five buttons looking like a sixth, and it is the one thing here you never
            // press.
            .toolbar {
                // ⚠️ SLIDERS FIRST, THEN THE PHONE. His correction, 2026-09-04: "no
                // the slider then the phone to the far left." Settings is the outer
                // container and the connection sits inside it, so the wider thing leads.
                ToolbarItem(placement: .navigation) {
                    Button { showingSettings = true } label: {
                        Label("Settings", systemImage: "slider.horizontal.3")
                    }
                }
                ToolbarItem(placement: .navigation) {
                    Button { showingConnection = true } label: {
                        // ⚠️ HIS PICK: "phone connection fill for connections cards."
                        // A handset with signal arcs — a modem reaching out, which is
                        // what this sheet sets up. It also stops this button and Settings
                        // drawing the same sliders glyph, which he spotted the moment
                        // both were on screen.
                        Label("Connection", systemImage: "phone.connection.fill")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(isConnected ? "Disconnect" : "Connect") {
                        Task { await toggleConnection() }
                    }
                    // ⚠️ RED WHILE CONNECTED, BECAUSE THE COLOUR DESCRIBES WHAT THE
                    // BUTTON DOES, NOT WHAT THE STATE IS. His call, 2026-09-04: "the
                    // connect pill changes to red disconnect while connected."
                    //
                    // It reads the opposite way to the status dot beside it, and that is
                    // correct rather than confusing: green there means the link is good;
                    // red here means pressing this ends it. One is a report, the other is
                    // a warning, and they are never both describing the same thing.
                    .tint(isConnected ? .red : .accentColor)
                    .disabled(isBusy || connection.host.isEmpty || connection.username.isEmpty)
                }
                // ⚠️ THE MICROPHONE AND THE SPEAKER ARE A PAIR AND STAY ADJACENT.
                // "a mic is supposed to be next to the speaker." They are the two halves
                // of talking to it, and apart, "is it listening?" and "is it talking?"
                // were answered in different places.
                ToolbarItem(placement: .automatic) {
                    Button {
                        if dictation.isListening {
                            dictation.stop()
                            VoiceCoordinator.shared.didStopListening()
                        } else {
                            VoiceCoordinator.shared.willListen()
                            dictation.start()
                        }
                    } label: {
                        Label(dictation.isListening ? "Microphone on" : "Microphone muted",
                              systemImage: dictation.isListening ? "mic.fill" : "mic.slash")
                    }
                    .tint(dictation.isListening ? .green : .red)
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
                            // ⚠️ THE APPEARANCE SETTINGS ARE APPLIED HERE, AND IF THEY
                            // WERE NOT, THAT SCREEN WOULD BE A LIE. A settings panel
                            // whose controls change nothing is exactly the false green
                            // this rebuild exists to stop making — it reports a state
                            // the app does not actually have.
                            .font(terminalFont)
                            .foregroundStyle(colour(for: line.kind))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .id(line.id)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(HexColor.color(scheme == .dark ? settings.darkBackground : settings.lightBackground))
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

            // ⚠️ THE MICROPHONE USED TO BE HERE AND IS NOW IN THE TOOLBAR, BESIDE THE
            // SPEAKER — his placement. It is not duplicated: two controls driving one
            // piece of state is the same mistake as the two identical sliders glyphs he
            // caught earlier, except this pair could disagree on screen while agreeing
            // underneath, which is worse.

            // ⚠️ THE EMPTY BOX IS THE INSTRUCTION. "Not connected" states a problem and
            // offers nothing; `ssh user@server.local` is the answer to it, sitting in the
            // place you would type the answer. He noticed it was gone before he noticed
            // the feature was — 2026-09-04: "in the typing bar where it says not
            // connected you used to have ssh user@servername.local."
            TextField(isConnected ? "Type a command" : "ssh user@server.local", text: $input)
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .focused($composerFocused)
                // ⚠️ TYPABLE WHILE DISCONNECTED, AND THAT IS THE WHOLE POINT.
                //
                // This read `.disabled(!isConnected || isBusy)`, which made the ssh-line
                // feature unreachable by construction: the box invites you to type
                // `ssh user@server.local` and then refuses the keystrokes, because the
                // only way to reach it is from the state where it is switched off.
                //
                // Only busy disables it now. A disconnected composer is exactly when he
                // has something to say to it.
                .disabled(isBusy)
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
            // Same reasoning as the field: the arrow has to work while disconnected,
            // or the ssh line has no way to be submitted.
            .disabled(isBusy || input.trimmingCharacters(in: .whitespaces).isEmpty)
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

        // ⚠️ SAVED BEFORE THE ATTEMPT, AND KEPT WHETHER IT WORKS OR NOT. His rule,
        // 2026-09-04: a manually entered connection "gets saved to the connection good
        // or unsucessful connect so the user can go to the connection cards and
        // proofread for typos."
        //
        // Saving only on success is backwards. A connection that FAILED is the one worth
        // keeping, because the failure is usually a typo and the typo is invisible until
        // you can look at it again. It cost him an afternoon today: the account read
        // michaelfuharty, missing the l, and the app answered "SSHClientError 4" — a
        // discarded connection would have meant retyping the same mistake from memory.
        // ⚠️ NORMALISE THE LIVE COPY TOO, NOT JUST THE SAVED ONE. The store cleans what
        // goes to disk; without this line the ATTEMPT still went out with whatever was
        // typed — so a space in the account would be stripped from the saved connection
        // and left in the one being used, and the failure would not match the record of
        // it. Same values in both places or the saved connection is not evidence.
        connection = connection.normalised()
        store.save(connection)

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
            // ⚠️ AND SAY WHERE TO GO AND LOOK. The saved connection is only useful for
            // proofreading if he knows it was kept.
            transcript.append(.init(kind: .status,
                                    text: "The connection was saved as typed \u{2014} open Connection settings to check it for a typo."))
            light.markDown()
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

    /// Pull `ssh [user@]host [-p port]` — or a bare `user@host` — out of a typed line.
    ///
    /// ⚠️ IT RETURNS nil RATHER THAN GUESSING. Anything that is not clearly one of those
    /// two shapes is somebody's command, not a connection request, and taking it over
    /// would be worse than ignoring it. A bare word with no `@` is not a host here, even
    /// though `ssh myserver` is valid — because at this point in the app it is far more
    /// likely to be a typo or a command than an intention to connect.
    static func parseSSHLine(_ line: String) -> (user: String?, host: String, port: Int?)? {
        var parts = line.split(separator: " ").map(String.init)
        guard !parts.isEmpty else { return nil }
        if parts[0].lowercased() == "ssh" { parts.removeFirst() }
        guard !parts.isEmpty else { return nil }

        var port: Int?
        if let flag = parts.firstIndex(of: "-p"), parts.indices.contains(flag + 1) {
            port = Int(parts[flag + 1])
            parts.removeSubrange(flag...(flag + 1))
        }

        guard let target = parts.first, target.contains("@") else { return nil }
        let halves = target.split(separator: "@", maxSplits: 1).map(String.init)
        guard halves.count == 2, !halves[0].isEmpty, !halves[1].isEmpty else { return nil }
        return (user: halves[0], host: halves[1], port: port)
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

        // ⚠️ A TYPED ssh LINE IS A CONNECTION REQUEST, NOT A COMMAND. He typed
        // `ssh account@host` the way he would in any terminal, and the old app answered
        // with an empty Connections list — his report: "It didnt give me anywhere to put
        // the password." So the line is parsed here and the sheet opens already filled,
        // with the password the only thing left to type.
        if !isConnected, let parsed = Self.parseSSHLine(command) {
            connection.host = parsed.host
            connection.username = parsed.user ?? connection.username
            if let port = parsed.port { connection.port = port }
            // A typed ssh line is always a plain shell — nothing in it names a session.
            connection.mode = .shell
            transcript.append(.init(kind: .status,
                                    text: "Ready to connect to \(parsed.host). The password is the only thing missing."))
            showingConnection = true
            return
        }

        // ⚠️ AND ANYTHING ELSE TYPED WHILE DISCONNECTED GETS AN ANSWER, NOT SILENCE.
        // Opening the composer up means ordinary commands can now be typed with nowhere
        // to send them, and a command that simply disappears is the failure this app was
        // rebuilt to stop making.
        if !isConnected && !isDemo {
            transcript.append(.init(kind: .status,
                                    text: "Not connected, so that went nowhere. Type ssh user@server.local to connect, or open Connection settings."))
            return
        }

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

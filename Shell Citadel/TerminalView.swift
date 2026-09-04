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
    @State private var replyTask: Task<Void, Never>?
    @State private var replyOffset = 0

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
                        Label("Connection", systemImage: "slider.horizontal.3")
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
                ToolbarItem(placement: .automatic) {
                    Button { showingAbout = true } label: {
                        Label("About", systemImage: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showingConnection) {
                NavigationStack {
                    ConnectionEditor(connection: $connection, password: $password)
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
            .sheet(isPresented: $showingAbout) { AboutView() }
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
                Image(systemName: dictation.isListening ? "mic.fill" : "mic.slash")
                    .font(.title2)
                    .foregroundStyle(dictation.isListening ? .red : .secondary)
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
            transcript.append(.init(kind: .status, text: "Disconnected."))
            return
        }

        isBusy = true
        defer { isBusy = false }
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
        }
        composerFocused = true
    }

    private func send() async {
        let command = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }
        input = ""
        transcript.append(.init(kind: .command, text: "$ \(command)"))
        isBusy = true
        defer { isBusy = false }
        // ⚠️ TWO DIFFERENT THINGS, NOT ONE WITH A FLAG. In Claude mode the message is
        // HANDED to a running session and the answer arrives later on its own channel;
        // there is no output to wait for here, and waiting would look like a hang.
        if connection.mode == .tmux {
            do {
                try await session.sendToSession(command, session: connection.tmuxSession, tag: Self.sourceTag)
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

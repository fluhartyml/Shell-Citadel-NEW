//
//  AboutView.swift
//  Shell Citadel
//
//  Step 0.1 of the roadmap. This exists before the app does anything, because the
//  build number is worthless if it is not readable from the device.
//
//  ⚠️ THE BUILD ROW IS NOT DECORATION. The previous app reported "1.0 (1)" for every
//  build ever made, so when an iPad worked and three iPhones did not, nobody could say
//  what the difference was. This row is the answer to "which build is this?", and it is
//  SELECTABLE and MONOSPACED on purpose — the point is being able to read it out loud
//  to someone who cannot see the screen.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        NavigationStack {
        List {
            Section {
                Text("Shell Citadel")
                    .font(.title2.weight(.semibold))
                Text("A terminal you talk to.")
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Version", value: Self.marketingVersion)
                LabeledContent("Build", value: Self.buildNumber)
                LabeledContent("Commit", value: BuildStamp.commit)
                LabeledContent("Built", value: BuildStamp.built)
            } header: {
                Text("Build")
            } footer: {
                Text(BuildStamp.isStamped
                     ? "The build number counts commits, so it only ever goes up. It is the same number Xcode and App Store Connect show, and it points at the commit beside it. A \u{201C}+\u{201D} after the commit means this build carries changes that were never committed."
                     : "This build was made before build numbering existed \u{2014} so it is older than any build that names a commit here.")
            }
            .textSelection(.enabled)
            .font(.system(.footnote, design: .monospaced))

            // ⚠️ STEP 0.3. This is the screen that answers "what is it doing right
            // now?" without anyone guessing. It is here from the first day rather
            // than added after a bug, because the bugs that ended the previous app
            // were all state questions nothing could answer.
            Section {
                LabeledContent("Keyboard", value: diagnostics.focusOwner)
                LabeledContent("Microphone", value: diagnostics.isListening ? "listening" : "off")
                LabeledContent("Speech", value: diagnostics.isSpeaking ? "speaking" : "off")
                LabeledContent("Connection", value: diagnostics.connection)
                if let lastError = diagnostics.lastError {
                    LabeledContent("Last error", value: lastError)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Now")
            } footer: {
                Text("What the app is doing at this moment. If something looks wrong, this row says what it actually is rather than what it appears to be.")
            }
            .textSelection(.enabled)
            .font(.system(.footnote, design: .monospaced))

            Section {
                NavigationLink("Recent activity") {
                    DiagnosticsLogView()
                }
            } footer: {
                // Reading a log aloud is exactly the work this is meant to remove, so
                // the record is here to be COPIED, not recited. Once there is a
                // connection it writes itself to the Mac and this becomes the fallback.
                Text("A timestamped record of focus, microphone, speech and connection changes. Nothing private is recorded \u{2014} no passwords, no commands, no transcript.")
            }
        }
        .navigationTitle("About")
        }
    }

    @State private var diagnostics = Diagnostics.shared

    /// The marketing version — `1.0`. What a customer would call the release.
    static var marketingVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    /// The build number — the repository's commit count.
    ///
    /// ⚠️ THE SAME STRING XCODE AND APP STORE CONNECT SHOW, on purpose. Michael:
    /// "uniform viewable in the app in xcode and app store connect." It counts commits,
    /// so it only ever goes up — which is what App Store Connect requires of every
    /// upload, and what a hash could never promise.
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }
}

/// The rolling record, for when there is no connection to write it over.
struct DiagnosticsLogView: View {
    @State private var diagnostics = Diagnostics.shared

    var body: some View {
        ScrollView {
            Text(diagnostics.report)
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle("Recent activity")
    }
}

#Preview {
    AboutView()
}

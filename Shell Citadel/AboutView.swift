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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
        List {
            Section {
                Text("Shell Citadel")
                    .font(.title2.weight(.semibold))
                Text("A terminal you talk to.")
                    .foregroundStyle(.secondary)
            }

            // ⚠️ THESE TWO SECTIONS ARE A LICENCE OBLIGATION, NOT A COURTESY.
            //
            // MIT requires the copyright and permission notices to be included in
            // copies; Apache 2.0 section 4 carries its own attribution duty. The duty
            // attaches to the BINARY, so it has to be reachable from inside the running
            // app — a line in the README does not discharge it.
            //
            // The old app carried this from 2026-08-22. The rebuild dropped it, because
            // nothing anywhere fails when a notice is missing.
            Section {
                Text(Attribution.disclaimer)
            } header: {
                Text("Not official")
            }

            Section {
                ForEach(Attribution.components) { component in
                    NavigationLink {
                        LicenseView(component: component)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(component.name)
                            Text("\(component.holder) \u{00B7} \(component.license)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Built with")
                    MoreInfo(
                        title: "the components",
                        detail: """
                        Every component this app links, and the licence each one ships \
                        under. Open one for its full text.

                        These notices are here because the licences require it \u{2014} \
                        MIT asks that the copyright and permission notices travel with \
                        the software, and Apache 2.0 carries its own attribution duty.
                        """
                    )
                }
            }

            Section {
                Group {
                    LabeledContent("Version", value: Self.marketingVersion)
                    LabeledContent("Build", value: Self.buildNumber)
                    LabeledContent("Commit", value: BuildStamp.commit)
                    LabeledContent("Built", value: BuildStamp.built)
                }
                // ⚠️ THE FACE GOES ON THE ROWS, NOT THE SECTION. Applied to the Section
                // it also reaches the header and footer, so "Build" rendered in a
                // typewriter face while every other header on the sheet did not. The
                // VALUES want monospace \u{2014} they get read out loud a character at a
                // time, and a commit hash in a proportional face is where 1 and l stop
                // being distinguishable.
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
            } header: {
                HStack {
                    Text("Build")
                    MoreInfo(
                        title: "the build number",
                        detail: BuildStamp.isStamped
                        ? """
                          The build number counts commits, so it only ever goes up.

                          It is the same number Xcode and App Store Connect show, and it \
                          points at the commit beside it.

                          A "+" after the commit means this build carries changes that \
                          were never committed.
                          """
                        : """
                          This build was made before build numbering existed \u{2014} so \
                          it is older than any build that names a commit here.
                          """
                    )
                }
            }

            // ⚠️ STEP 0.3. This is the screen that answers "what is it doing right
            // now?" without anyone guessing. It is here from the first day rather
            // than added after a bug, because the bugs that ended the previous app
            // were all state questions nothing could answer.
            Section {
                Group {
                    LabeledContent("Keyboard", value: diagnostics.focusOwner)
                    LabeledContent("Microphone", value: diagnostics.isListening ? "listening" : "off")
                    LabeledContent("Speech", value: diagnostics.isSpeaking ? "speaking" : "off")
                    LabeledContent("Connection", value: diagnostics.connection)
                    if let lastError = diagnostics.lastError {
                        LabeledContent("Last error", value: lastError)
                            .foregroundStyle(.orange)
                    }
                }
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
            } header: {
                HStack {
                    Text("Now")
                    MoreInfo(
                        title: "what the app is doing",
                        detail: """
                        What the app is doing at this moment.

                        If something looks wrong, these rows say what it actually is \
                        rather than what it appears to be.
                        """
                    )
                }
            }

            Section {
                NavigationLink {
                    DiagnosticsLogView()
                } label: {
                    HStack {
                        Text("Recent activity")
                        Spacer()
                        // ⚠️ THE CHEVRON IS DRAWN BY HAND ON PURPOSE. macOS does not add
                        // one to a NavigationLink inside a List in a sheet, so the row
                        // read as a heading rather than a way in \u{2014} he said so:
                        // it "doesn't look tappable". A row that opens something has to
                        // look like a row that opens something.
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
            } header: {
                HStack {
                    Text("Recent activity")
                    // Reading a log aloud is exactly the work this is meant to remove, so
                    // the record is here to be COPIED, not recited. Once there is a
                    // connection it writes itself to the Mac and this becomes the fallback.
                    MoreInfo(
                        title: "the activity record",
                        detail: """
                        A timestamped record of focus, microphone, speech and connection \
                        changes.

                        Nothing private is recorded \u{2014} no passwords, no commands, \
                        no transcript.
                        """
                    )
                }
            }
        }
        // ⚠️ THE FOOTERS WERE TRUNCATED WITH AN ELLIPSIS. On macOS a List footer takes
        // its ideal height from one line, so the build-number explanation cut off at
        // "It is the s\u{2026}" \u{2014} the sentence explaining the one number the whole
        // app exists to make readable. This lets any Text on the sheet take the height
        // its wrapped content needs instead of the height of one line.
        .environment(\.defaultMinListRowHeight, 22)
        .navigationTitle("About")
        // ⚠️ A MAC SHEET SIZES TO ITS CONTENT AND A List HAS NO NATURAL SIZE, so
        // without this the whole sheet collapsed to a box showing the title and one
        // row. He caught it on the running Mac app, 2026-09-04 — and it was the worst
        // possible thing to lose, because the build number lives here and the entire
        // point of the build number is that it can always be read off the screen.
        #if os(macOS)
        .frame(minWidth: 460, idealWidth: 520, minHeight: 560, idealHeight: 640)
        #endif
        .toolbar {
            // ⚠️ AND THERE WAS NO WAY OUT. iOS gives a sheet a swipe-down; macOS gives
            // it nothing. A modal with no dismiss is not a cosmetic bug — it is an app
            // he has to force-quit.
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
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

/// The full licence text for one component.
///
/// ⚠️ SELECTABLE, AND SCROLLABLE TO THE END. A notice you cannot copy or cannot reach the
/// bottom of has not really been included. The link is live so the source is one tap away.
struct LicenseView: View {
    let component: Attribution.Component

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let url = URL(string: component.url) {
                    Link(component.url, destination: url)
                        .font(.footnote)
                }
                Text(component.text)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(component.name)
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

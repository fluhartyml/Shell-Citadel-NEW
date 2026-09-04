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
        }
    }

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

#Preview {
    AboutView()
}

//
//  BuildStamp.swift
//  Shell Citadel
//
//  ⚠️ THE VALUES BELOW ARE REWRITTEN BY `Scripts/stamp-build.sh`. Do not hand-edit them.
//
//  This is step 0.1 of the roadmap and it is deliberately the FIRST code in the project,
//  written before the app does anything at all.
//
//  The previous Shell Citadel shipped roughly ninety-five builds that every one of them
//  called "1.0 (1)". When an iPad kept working and three iPhones did not, nothing on any
//  of the four devices could say which build it was running, and a full day went into
//  guessing at a difference the app could simply have stated.
//
//  Michael, 2026-09-04: "you need to make sure it happens and you do not get complaicent
//  and not do it in the future."
//
//  So it is not a habit. Scripts/post-commit rewrites the build number after every
//  commit, and Scripts/install-hooks.sh puts that hook in place — git never copies hooks
//  on clone, so the hook has to be installed from something the repository carries.

import Foundation

enum BuildStamp {
    /// Short SHA of HEAD when this build was stamped. "+" suffix = uncommitted changes.
    static let commit = "3e5bc39"

    /// Branch HEAD was on when this build was stamped.
    static let branch = "return-key-fix"

    /// Local time the stamp was generated — effectively the build time.
    static let built = "2026-09-11 12:01"

    /// True when this binary was never stamped. Not a missing answer — it IS the answer:
    /// this build predates stamping, so it is older than any stamped one.
    static var isStamped: Bool { commit != "unstamped" }

    /// The build number — `CURRENT_PROJECT_VERSION`, which is the git commit count.
    ///
    /// ⚠️ READ FROM THE BUNDLE, NOT STAMPED INTO THIS FILE. It is already written into
    /// the project by `Scripts/stamp-build.sh`, and a second copy here could disagree
    /// with the first. One source, so there is nothing to keep in step.
    static var number: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }
}

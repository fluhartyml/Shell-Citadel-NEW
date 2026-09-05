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

enum BuildStamp {
    /// Short SHA of HEAD when this build was stamped. "+" suffix = uncommitted changes.
    static let commit = "523ec4f"

    /// Branch HEAD was on when this build was stamped.
    static let branch = "main"

    /// Local time the stamp was generated — effectively the build time.
    static let built = "2026-09-04 18:35"

    /// True when this binary was never stamped. Not a missing answer — it IS the answer:
    /// this build predates stamping, so it is older than any stamped one.
    static var isStamped: Bool { commit != "unstamped" }
}

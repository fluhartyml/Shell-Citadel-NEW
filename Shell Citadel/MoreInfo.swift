//
//  MoreInfo.swift
//  Shell Citadel
//
//  The ⓘ that holds an explanation, so the explanation is not in the way.
//

import SwiftUI

/// A round ⓘ beside a section header that opens its detail in a popover.
///
/// ⚠️ THIS EXISTS BECAUSE THE EXPLANATIONS WERE UNREADABLE AND UNSKIPPABLE AT THE SAME
/// TIME. Michael, 2026-09-04, on the Connection sheet: "the hints are too much, they dont
/// look normalized or within apples standards." Apple's own settings screens carry one
/// short line under a section, or nothing.
///
/// And a footer does not merely take up room — on macOS a List footer sizes itself to one
/// line and truncates the rest with an ellipsis, so the sentence explaining the build
/// number ended at "It is the s…". The text was both cluttering the sheet AND cut off.
/// Behind an ⓘ it is complete, and it costs nothing to ignore.
///
/// ⚠️ NOT A PLACE TO HIDE THINGS THAT MATTER. What goes in here is the second paragraph —
/// the reasoning, the character rules, the caveat. What the user must know to answer the
/// question in front of them stays visible.
struct MoreInfo: View {
    let title: String
    let detail: String
    @State private var showing = false

    var body: some View {
        Button {
            showing = true
        } label: {
            Image(systemName: "info.circle")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("More about \(title)")
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            Text(detail)
                .font(.callout)
                .multilineTextAlignment(.leading)
                // Without this the popover truncates for the same reason the footer did.
                .fixedSize(horizontal: false, vertical: true)
                .padding()
                .frame(maxWidth: 320)
                .presentationCompactAdaptation(.popover)
        }
    }
}

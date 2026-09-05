//
//  Tabs.swift
//  Shell Citadel
//
//  Michael, 2026-08-29: "we may need to add tab abilities to citadel so i can have
//  multiple terminals open." And 2026-09-04, the reason it is not a luxury: "Tabs were a
//  distinguishing factor for my app... That makes my app useful so it doesnt get
//  rejected."
//
//  THE NEED IS CONCRETE. With one connection it is the Mac OR the Pi — pointing the app
//  at one wipes the other. A tab is an open connection, so a tab attached to a tmux
//  session can sit beside a tab running plain commands on a Pi at the same time. That
//  combination is impossible while the connection is a single global thing.
//
//  ── ⚠️ THE CONSTRAINT THAT DECIDES THE WHOLE DESIGN ────────────────────────────────
//
//  SwiftUI DESTROYS @State WHEN A VIEW LEAVES THE VIEW TREE, and `TerminalView` owns its
//  `SSHSession` as @State. So rendering only the selected tab would CLOSE the connection
//  on every tab switch — the exact opposite of what tabs are for.
//
//  Every tab therefore stays in the hierarchy and the ones not in front are hidden, not
//  removed. This is the one thing the old app wrote down about tabs, it is the thing that
//  is not obvious from the outside, and getting it wrong produces a bug that looks like a
//  flaky network rather than a layout mistake.
//
//  ── HIS MODEL: A BROWSER ───────────────────────────────────────────────────────────
//
//  2026-09-04: "i think a plus should be on the tab row and like safari when you add a new
//  tab the connection cards show or you type in the chat line similar to the url bar."
//
//  That model answers a question I had put to him badly. I had proposed a three-way
//  prompt — new tab / replace this tab / cancel — when picking a connection while a tab
//  was live. With a + on the tab row, "open in a new tab" IS the plus, so the prompt only
//  has to ask the one thing left: replace what is here, or not.
//

import Foundation
import Observation
import SwiftUI

/// One tab: what the tab bar needs to draw it, written by the terminal inside it.
///
/// ⚠️ DELIBERATELY THIN. The connection, the session, the transcript and the rest stay
/// inside the TerminalView that owns them — moving them out here would mean rebuilding
/// every one of them through this object, and the point of the exercise is that the
/// session is NOT rebuilt. This carries only what something outside the terminal has to
/// know: what to call it, and whether its light is on.
@Observable
final class TerminalTab: Identifiable {
    let id = UUID()

    /// What the tab says. The terminal keeps this in step with its connection.
    var title = "New tab"

    /// Whether this tab's session is live, for the dot on the tab.
    var isConnected = false

    /// True until it has ever connected — an untouched tab shows the connection cards.
    var isFresh = true

    /// Whether this tab is the one in front.
    ///
    /// ⚠️ DORMANT IS NOT DISCONNECTED, AND THE DIFFERENCE IS THE POINT. His rule,
    /// 2026-09-04: "connections stay open but can go dormant so they dont update in the
    /// background but pick back up when they are refocused on."
    ///
    /// The SSH session stays up. What stops is the WORK: tailing the reply file, and the
    /// heartbeat. Four tabs each polling a file and pinging every ten seconds is four
    /// times the radio traffic and battery for three terminals nobody is reading.
    ///
    /// Nothing is lost by stopping, because the reply channel resumes by BYTE OFFSET —
    /// the same mechanism that makes locking the screen free. A dormant tab picks up
    /// exactly where it left off and fills the gap in order.
    var isFrontmost = false
}

@Observable
final class TabsModel {
    var tabs: [TerminalTab] = [TerminalTab()]
    var selected: TerminalTab.ID?

    init() { selected = tabs.first?.id }

    var current: TerminalTab? { tabs.first { $0.id == selected } }

    @discardableResult
    func newTab() -> TerminalTab {
        let tab = TerminalTab()
        tabs.append(tab)
        selected = tab.id
        Diagnostics.shared.record(.app, "new tab \u{00B7} \(tabs.count) open")
        return tab
    }

    /// ⚠️ NEVER LEAVES HIM WITH NOTHING. Closing the last tab opens a fresh one rather
    /// than emptying the window — an app showing no terminal at all reads as a crash.
    func close(_ id: TerminalTab.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: index)
        if tabs.isEmpty { tabs = [TerminalTab()] }
        if selected == id {
            selected = tabs[min(index, tabs.count - 1)].id
        }
        Diagnostics.shared.record(.app, "closed a tab \u{00B7} \(tabs.count) open")
    }
}

/// The tab row, above everything else.
///
/// ⚠️ ABOVE THE TOOLBAR, HIS PLACEMENT: "above the sliders connections mic speaker and
/// info should be tabs." The controls below it all act on whichever tab is in front, so
/// the tab has to be chosen before they mean anything — top to bottom is the order of
/// the decision.
struct TabBar: View {
    @Bindable var model: TabsModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(model.tabs) { tab in
                    HStack(spacing: 5) {
                        // The same LED language as the status row, at tab size.
                        Circle()
                            .fill(tab.isConnected ? Color.green : Color.secondary.opacity(0.45))
                            .frame(width: 7, height: 7)

                        Text(tab.title)
                            .font(.footnote)
                            .lineLimit(1)

                        // ⚠️ THE CLOSE BUTTON ONLY APPEARS ON THE TAB IN FRONT. On a
                        // phone the tabs are already small, and an X on every one of them
                        // is four targets a thumb can hit by accident when it meant to
                        // switch.
                        if model.selected == tab.id {
                            Button {
                                model.close(tab.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption2.weight(.semibold))
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Close \(tab.title)")
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(model.selected == tab.id ? AnyShapeStyle(.selection) : AnyShapeStyle(.clear))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .contentShape(Rectangle())
                    .onTapGesture { model.selected = tab.id }
                }

                // ⚠️ HIS PLUS, AND IT REPLACED A DIALOG. "a plus should be on the tab row
                // and like safari when you add a new tab the connection cards show."
                Button {
                    model.newTab()
                } label: {
                    Image(systemName: "plus")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("New tab")
                .padding(.horizontal, 6)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
        .background(.bar)
    }
}

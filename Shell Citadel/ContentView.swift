//
//  ContentView.swift
//  Shell Citadel
//
//  The tab row, and every terminal underneath it.
//

import SwiftUI

struct ContentView: View {
    @State private var model = TabsModel()

    var body: some View {
        VStack(spacing: 0) {
            TabBar(model: model)
            Divider()

            // ⚠️ EVERY TAB IS BUILT AND THE ONES NOT IN FRONT ARE HIDDEN, NOT REMOVED.
            //
            // This is the whole reason tabs are not a `switch` on the selection. A
            // TerminalView owns its SSHSession as @State, and SwiftUI destroys @State
            // when a view leaves the tree — so rendering only the selected tab would
            // close the connection every time he switched, which is precisely what tabs
            // exist to prevent.
            //
            // ⚠️ `.hidden()` AND NOT `if selected` — the difference is the entire bug.
            // It costs a built view per tab, which is nothing next to a dropped session,
            // and `.opacity(0)` would be wrong too: an invisible view still takes touches.
            ZStack {
                ForEach(model.tabs) { tab in
                    TerminalView(tab: tab)
                        .hidden(model.selected != tab.id)
                }
            }
        }
        // ⚠️ ONE PLACE DECIDES WHO IS AWAKE. Setting isFrontmost from inside each
        // terminal would mean four views racing to agree on which of them is in front;
        // the model already knows, so it says so.
        .onChange(of: model.selected) { _, _ in updateFrontmost() }
        .onAppear { updateFrontmost() }
    }

    private func updateFrontmost() {
        for tab in model.tabs {
            tab.isFrontmost = (tab.id == model.selected)
        }
    }
}

private extension View {
    @ViewBuilder
    func hidden(_ yes: Bool) -> some View {
        if yes { self.hidden() } else { self }
    }
}

#Preview {
    ContentView()
}

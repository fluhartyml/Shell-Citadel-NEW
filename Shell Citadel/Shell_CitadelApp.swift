//
//  Shell_CitadelApp.swift
//  Shell Citadel
//
//  Created by Michael Fluharty on 9/4/26.
//

import SwiftUI

@main
struct Shell_CitadelApp: App {

    /// ⚠️ THE BUNDLED TYPEFACE IS REGISTERED BEFORE THE FIRST VIEW EXISTS. His decision
    /// 2026-09-05: the Nerd Font ships as the default and he can change it. Registering
    /// later would draw the first frame in the system face and correct itself, which is
    /// a flicker he would be right to report as a bug.
    init() {
        BundledFont.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

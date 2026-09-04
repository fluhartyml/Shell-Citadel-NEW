//
//  SyncedSettings.swift
//  Shell Citadel
//
//  Preferences that follow HIM, kept apart from state that belongs to a DEVICE.
//
//  ⚠️ THE SPLIT IS HIS, AND IT IS THE WHOLE POINT OF THIS FILE. Michael, 2026-09-04:
//  "the sliders must be persistant across ios and mac" — and when asked whether that
//  included the speaker and microphone toggles: "just the sliders, i dont see a
//  connection between speaker mute microphone mute and the sliders menu."
//
//  He is drawing a real line:
//
//    • A SLIDER IS A PREFERENCE ABOUT HIM. How long he pauses before a sentence is
//      finished is a fact about how he talks. It is the same on the phone, the iPad and
//      the Mac, and having to rediscover 1.5 seconds on each device is three times the
//      work for one answer.
//
//    • A MUTE IS A FACT ABOUT A ROOM. Whether the speaker should be talking depends on
//      who else is present, and syncing it would mean silencing the phone in his pocket
//      because the iPad is in a room with someone in it. Those stay in UserDefaults,
//      per device, deliberately.
//
//  ⚠️ WHY NSUbiquitousKeyValueStore AND NOT CLOUDKIT. This is a handful of numbers, not
//  data. The key-value store is 1 MB total, needs no schema, no container design and no
//  record types, and it reconciles last-writer-wins — which is correct for a preference
//  and would be wrong for anything he could lose.
//
//  ⚠️ IT CAN BE UNAVAILABLE AND THAT IS NOT AN ERROR. Signed out of iCloud, iCloud Drive
//  off, a device in a state where sync is disabled — the store simply does nothing. So
//  the LOCAL value is always authoritative for reading, and the cloud is a mirror that
//  updates it when it has something newer. Nothing here is allowed to leave a setting
//  unreadable because a network was not there.
//

import Foundation
import Observation

// ⚠️ NOT WIRED UP YET, AND THE REASON IS NOT IN THIS FILE. 2026-09-04.
//
// The iCloud key-value store needs the iCloud capability on the App ID, and the wildcard
// team provisioning profile does not carry it:
//
//   error: Provisioning profile "iOS Team Provisioning Profile: *" doesn't include the
//          iCloud capability
//
// That is added in Xcode under Signing & Capabilities — Michael's account, his portal,
// one click. It cannot be done from here and must not be worked around.
//
// Until then this class is written, compiled and unused: the pause lives in UserDefaults
// per device. When the capability is on, attach the entitlements file and point
// Dictation at SyncedSettings.shared.pauseSeconds.

@MainActor
@Observable
final class SyncedSettings {
    static let shared = SyncedSettings()

    private let cloud = NSUbiquitousKeyValueStore.default
    private let local = UserDefaults.standard

    private enum Key {
        static let pauseSeconds = "dictation.pauseSeconds"
    }

    /// How long a pause means he has finished a sentence.
    ///
    /// ⚠️ 1.5 SECONDS, MEASURED TWICE. He tried 1s and it cut him off mid-sentence
    /// repeatedly; 3s was "way too long"; 2s was "too long"; and he landed on
    /// "1.5 is a sweet spot" — independently the same value the old app had arrived at.
    var pauseSeconds: Double {
        didSet {
            guard pauseSeconds != oldValue else { return }
            local.set(pauseSeconds, forKey: Key.pauseSeconds)
            cloud.set(pauseSeconds, forKey: Key.pauseSeconds)
            cloud.synchronize()
            Diagnostics.shared.record(.app, "pause -> \(pauseSeconds)s")
        }
    }

    private init() {
        let stored = local.double(forKey: Key.pauseSeconds)
        pauseSeconds = stored > 0 ? stored : 1.5

        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.pullFromCloud() }
        }
        cloud.synchronize()
        pullFromCloud()
    }

    /// Takes the cloud's value when it has one. Deliberately quiet: a device that has
    /// never synced keeps whatever it had rather than being reset to a default.
    private func pullFromCloud() {
        let remote = cloud.double(forKey: Key.pauseSeconds)
        guard remote > 0, remote != pauseSeconds else { return }
        pauseSeconds = remote
        Diagnostics.shared.record(.app, "pause synced from another device -> \(remote)s")
    }
}

//
//  TerminalMetrics.swift
//  Shell Citadel
//
//  How many characters fit, at the size he picked.
//
//  ⚠️ HIS RULE, 2026-09-05, AND IT DECIDES THE WHOLE FILE:
//
//    "it scales the font sizes bigger or smaller making the (height) lines and
//     (width) colums increase or decrease. font gets bigger the height and width
//     get smaller, the font size gets smaller the height and width get increased"
//
//  So THE SIZE IS THE ONLY REAL VALUE. Columns and lines are not settings — they are
//  consequences, and they run the opposite way to the size. That is why nothing here
//  stores a column count: a stored one would be a second source of truth for a number
//  the layout already decides, and the two would disagree the first time he rotated a
//  phone.
//
//  ⚠️ AND IT IS WHY COLUMNS CANNOT SYNC. The size follows him between devices because
//  legibility is a fact about his eyes. How many columns that buys is a fact about the
//  glass in front of him — 54 on the 16e and 200 on the Mac, from the same point size.
//  Syncing the consequence would fight the cause. → SyncedSettings.swift
//
//  ⚠️ THE 0.6 IS GONE. The wrap width used to be `columns × size × 0.6`, a guess at how
//  wide a monospaced character is. It is close for many faces and wrong for plenty of
//  others, and he can install any monospaced font on the device. This measures the face
//  he actually chose instead of assuming a ratio.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
private typealias PlatformFont = UIFont
#else
import AppKit
private typealias PlatformFont = NSFont
#endif

// MARK: - What the glass is

/// The size of the transcript area as last laid out **on this device**.
///
/// ⚠️ PER DEVICE AND DELIBERATELY NOT SYNCED — see the header. It is also not persisted:
/// a window size from last launch is a claim about a window that may not exist any more,
/// and the layout hands us the real one within a frame of appearing.
@MainActor
@Observable
final class TerminalGeometry {
    static let shared = TerminalGeometry()

    /// `.zero` until the terminal has actually been laid out once.
    private(set) var viewport: CGSize = .zero

    /// True once a real measurement has arrived. The settings screen reads this rather
    /// than showing a column count derived from nothing — a made-up readout is the false
    /// green this rebuild exists to stop producing.
    var isMeasured: Bool { viewport.width > 1 && viewport.height > 1 }

    func report(_ size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        // Layout chatters during rotation and window drags; only a real change matters.
        guard abs(size.width - viewport.width) > 0.5 || abs(size.height - viewport.height) > 0.5
        else { return }
        viewport = size
    }

    private init() {}
}

// MARK: - How big one character is

enum TerminalMetrics {

    /// Point size bounds, shared with the slider so the two can never disagree.
    static let minSize: Double = 8
    static let maxSize: Double = 32

    /// The width and height of one character cell at `size`, in points.
    ///
    /// Measured from the font's own metrics: the advance of a character in a monospaced
    /// face is every character's advance, and the line box is ascender to descender plus
    /// the face's leading.
    static func cell(fontName: String, size: Double) -> CGSize {
        let ratio = ratios(for: fontName)
        return CGSize(width: ratio.width * size, height: ratio.height * size)
    }

    /// How many whole characters fit across `width` at `size`.
    static func columns(across width: CGFloat, fontName: String, size: Double) -> Int {
        let w = cell(fontName: fontName, size: size).width
        guard w > 0 else { return 0 }
        return max(1, Int(width / w))
    }

    /// How many whole lines fit down `height` at `size`.
    static func lines(down height: CGFloat, fontName: String, size: Double) -> Int {
        let h = cell(fontName: fontName, size: size).height
        guard h > 0 else { return 0 }
        return max(1, Int(height / h))
    }

    // MARK: Measurement
    //
    // ⚠️ MEASURED ONCE PER FACE, NOT ONCE PER KEYSTROKE. A scalable font's advance and
    // line box are linear in point size, so one measurement at a reference size gives
    // the ratio for every size — and dragging the slider then costs arithmetic rather
    // than text layout on every frame.

    private static let reference: CGFloat = 100
    nonisolated(unsafe) private static var cache: [String: CGSize] = [:]
    private static let lock = NSLock()

    private static func ratios(for fontName: String) -> CGSize {
        lock.lock()
        defer { lock.unlock() }
        if let hit = cache[fontName] { return hit }

        let font = platformFont(fontName, reference)
        // "M" is the widest glyph in most faces and identical to every other advance in
        // a monospaced one, so it measures the cell rather than one lucky character.
        let width = ("M" as NSString).size(withAttributes: [.font: font]).width / reference
        let height = (font.ascender - font.descender + font.leading) / reference

        // A face that reports nothing usable must not produce a divide-by-zero or a
        // column count of infinity. Fall back to the conventional monospaced ratios.
        let ratio = CGSize(
            width: width > 0 ? width : 0.6,
            height: height > 0 ? height : 1.2
        )
        cache[fontName] = ratio
        return ratio
    }

    /// Keeps a nudged size inside the slider's own range, so the two controls can never
    /// arrive at a value the other one cannot show.
    static func clamp(_ size: Double) -> Double {
        min(max(size, minSize), maxSize)
    }

    /// The face he chose, or the system monospaced face when he has chosen nothing.
    /// A name that no longer resolves — a font he removed — falls back rather than
    /// crashing or silently measuring something else.
    private static func platformFont(_ name: String, _ size: CGFloat) -> PlatformFont {
        if name.isEmpty {
            return PlatformFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
        return PlatformFont(name: name, size: size)
            ?? PlatformFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
}

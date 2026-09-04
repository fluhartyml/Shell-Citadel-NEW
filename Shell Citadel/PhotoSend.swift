//
//  PhotoSend.swift
//  Shell Citadel
//
//  Roadmap step 2.5 — the "+" beside the composer.
//
//  ⚠️ HIS PRIORITY, NOT A NICE-TO-HAVE. Michael, 2026-08-23: "stt and tts is lower
//  priority than getting a photo or screenshot from my phone to you." Two reasons landed
//  on it the same morning: it is the missing EYE for the homelab — Claude cannot see a
//  cable, a label or an amber light — and it is how he reports a bug from the couch with
//  only a phone in his hand.
//
//  ── CONTAINMENT, HIS BOUNDARY ──────────────────────────────────────────────────
//  Michael, 2026-08-27: "that way the pictures and videos stay within shell citadel and
//  dont leave its sandbox."
//
//  That is a boundary, not a filing preference: these photographs are of medical
//  documents, the inside of his house, his equipment. So nothing is ever written to the
//  photo library — the moment an image lands there it syncs to iCloud and it has left.
//  The bytes exist in memory, go up the wire, and are dropped. This file keeps no cache
//  and owns no directory.
//
//  ── WHY IT IS COMPRESSED ───────────────────────────────────────────────────────
//  An iPhone photograph is 3-6 MB. Over cellular, on a connection also carrying the
//  conversation, that is a long stall with no progress bar. A serial number has to be
//  READABLE, not archival: 2000px on the long edge at quality 0.7 lands near 400 KB and
//  every character is still sharp.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum PhotoSend {

    /// Target for the long edge. Chosen so small print — a service tag, a MAC address on
    /// a sticker — survives, while the file stays sendable from a rack room on one bar.
    static let longEdge: CGFloat = 2000
    static let quality: CGFloat = 0.7

    /// `2026-09-04-0914-32.jpg` — sortable, readable, and unique enough for a folder a
    /// human opens by hand. Deliberately not a UUID: he will see this filename in a
    /// message, and a UUID tells him nothing about when it was taken.
    static func filename(at date: Date = Date(), extension ext: String = "jpg") -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm-ss"
        return "\(f.string(from: date)).\(ext)"
    }

    #if canImport(UIKit)
    /// Downscale and JPEG-encode. Returns nil only if the image cannot be encoded at
    /// all, which in practice means it was empty.
    static func prepare(_ image: UIImage) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }

        let longest = max(size.width, size.height)
        let scale = longest > longEdge ? longEdge / longest : 1
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        // UIGraphicsImageRenderer respects the image's orientation, which matters more
        // here than usual: a photograph of a label held sideways that arrives rotated is
        // a photograph Claude reads the wrong way up.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1          // target is already in pixels, not points
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: quality)
    }
    #endif
}

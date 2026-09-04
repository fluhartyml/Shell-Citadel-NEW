//
//  DocumentScanner.swift
//  Shell Citadel
//
//  The "scan" half of his "+" button. Michael, 2026-08-25: "I want to add a plus next ti
//  the predictive text boxes to add a camera capture function to shell citadel" —
//  "image or scan".
//
//  ⚠️ WHY VISIONKIT AND NOT JUST THE CAMERA. A photograph of a page taken at an angle,
//  in a wheelchair, one-handed, is a trapezoid with a shadow across it. VNDocumentCamera
//  finds the page edges, corrects the perspective and crops — for free, on device, with
//  no model to ship. It is the same machinery as his own Snap&ScanKeeper, so it is a
//  known quantity rather than a new dependency.
//
//  Nothing is written to the photo library here either. The scan comes back as an image
//  in memory, is compressed by PhotoSend, goes up the wire, and is dropped.
//

#if os(iOS)
import SwiftUI
import VisionKit

struct DocumentScanner: UIViewControllerRepresentable {
    /// Called with every page the scan produced, in order.
    var onScan: ([UIImage]) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScanner
        init(_ parent: DocumentScanner) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            // Multi-page is free here and worth keeping: he photographs medical
            // paperwork, and a two-sided form sent as one page is a form with half of
            // it missing.
            var pages: [UIImage] = []
            for i in 0..<scan.pageCount { pages.append(scan.imageOfPage(at: i)) }
            parent.onScan(pages)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            Diagnostics.shared.failed(.app, "document scan failed: \(error.localizedDescription)")
            parent.onCancel()
        }
    }
}

/// The plain camera, for when the subject is not a page — a cable run, a rack light, a
/// connector. The document scanner would try to find edges that are not there.
struct CameraCapture: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCapture
        init(_ parent: CameraCapture) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            } else {
                parent.onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}
#endif

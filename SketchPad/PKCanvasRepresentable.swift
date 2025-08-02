// === Placement ===
// File: PKCanvasRepresentable.swift
// Xcode: Replace your existing file with this one.
// Fixes: (a) uses drawingPolicy instead of allowsFingerDrawing,
//        (b) finds a UIWindow for PKToolPicker.shared(for:).

import SwiftUI
import PencilKit
import UIKit

struct PKCanvasRepresentable: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var isFingerDrawingEnabled: Bool = true

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PKCanvasRepresentable
        init(_ parent: PKCanvasRepresentable) { self.parent = parent }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawing = drawing
        canvas.backgroundColor = .systemBackground
        // iOS 14+: replace deprecated allowsFingerDrawing
        canvas.drawingPolicy = isFingerDrawingEnabled ? .anyInput : .pencilOnly
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
        // Keep policy in sync with the SwiftUI binding
        uiView.drawingPolicy = isFingerDrawingEnabled ? .anyInput : .pencilOnly

        // Attach the tool picker once the view is in a window.
        #if !targetEnvironment(macCatalyst)
        DispatchQueue.main.async {
            guard let window = uiView.window ?? Self.keyWindow() else { return }
            if let picker = PKToolPicker.shared(for: window) {
                picker.setVisible(true, forFirstResponder: uiView)
                picker.addObserver(uiView)
                uiView.becomeFirstResponder()
            }
        }
        #endif
    }

    // Helper: find a UIWindow for the current scene
    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

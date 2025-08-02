// === Placement ===
// File: PKCanvasRepresentable.swift
// Replace your existing file with this version.
// Fixes: reliably attaches/shows PKToolPicker when the floating button is tapped.

import SwiftUI
import PencilKit
import UIKit

struct PKCanvasRepresentable: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var isFingerDrawingEnabled: Bool = true
    var toolPickerTrigger: Int = 0   // bump this from SwiftUI to show the picker

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PKCanvasRepresentable
        var lastTrigger: Int = -1
        var picker: PKToolPicker?  // keep a strong reference

        init(_ parent: PKCanvasRepresentable) {
            self.parent = parent
        }

        func attachPickerIfPossible(to canvas: PKCanvasView) {
            guard let window = canvas.window ?? PKCanvasRepresentable.keyWindow(),
                  let pk = PKToolPicker.shared(for: window) else { return }

            if picker !== pk {
                picker = pk
                pk.addObserver(canvas)
            }
        }

        func showPicker(on canvas: PKCanvasView) {
            guard let pk = picker else { return }
            pk.setVisible(true, forFirstResponder: canvas)
            canvas.becomeFirstResponder()
        }

        // PencilKit delegate
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

        // Default tool so you can draw even without the palette (Simulator-friendly)
        canvas.tool = PKInkingTool(.pen, color: .label, width: 5)
        canvas.drawingPolicy = isFingerDrawingEnabled ? .anyInput : .pencilOnly

        // Attach picker once the view is in a window (next run loop)
        DispatchQueue.main.async {
            context.coordinator.attachPickerIfPossible(to: canvas)
        }
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing { uiView.drawing = drawing }
        uiView.drawingPolicy = isFingerDrawingEnabled ? .anyInput : .pencilOnly

        // Ensure picker is attached (in case window became available after makeUIView)
        DispatchQueue.main.async {
            context.coordinator.attachPickerIfPossible(to: uiView)

            // Respond to the floating button tap
            if context.coordinator.lastTrigger != toolPickerTrigger {
                context.coordinator.lastTrigger = toolPickerTrigger
                context.coordinator.showPicker(on: uiView)
            }
        }
    }

    // Helper: find a key window if SwiftUI hasn't wired uiView.window yet
    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

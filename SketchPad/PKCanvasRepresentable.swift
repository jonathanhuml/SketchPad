// === Placement ===
// File: PKCanvasRepresentable.swift
// Add to your app target.
// Uses PKToolPicker.shared(for: UIWindow) so it compiles on SDKs that don't expose the UIWindowScene overload.

import SwiftUI
import PencilKit
import UIKit

struct PKCanvasRepresentable: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var isFingerDrawingEnabled: Bool
    var toolPickerTrigger: Int   // bump this (e.g., &+= 1) to re-show the picker

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PKCanvasRepresentable
        var lastTrigger: Int = -1

        weak var toolPicker: PKToolPicker?
        let canvasView = PKCanvasView()

        init(_ parent: PKCanvasRepresentable) {
            self.parent = parent
            super.init()
            canvasView.delegate = self
            canvasView.drawing = parent.drawing
            canvasView.alwaysBounceVertical = true
            canvasView.backgroundColor = .clear
            canvasView.isOpaque = false
            canvasView.drawingPolicy = parent.isFingerDrawingEnabled ? .anyInput : .pencilOnly
        }

        // Attach PKToolPicker once we actually have a window.
        func attachToolPickerIfPossible() {
            // Already attached?
            guard toolPicker == nil else { return }
            // Need a real window first.
            guard let window = canvasView.window else { return }

            // SDK exposes only the UIWindow variant here.
            guard let picker = PKToolPicker.shared(for: window) else { return }
            toolPicker = picker

            picker.addObserver(canvasView)
            picker.setVisible(true, forFirstResponder: canvasView)

            // Must be first responder for the picker to appear on device.
            DispatchQueue.main.async { [weak self] in
                self?.canvasView.becomeFirstResponder()
            }
        }

        func showToolPicker() {
            // Ensure we’re attached; if not yet in a window, try again shortly.
            attachToolPickerIfPossible()
            guard let picker = toolPicker else {
                DispatchQueue.main.async { [weak self] in self?.showToolPicker() }
                return
            }
            picker.setVisible(true, forFirstResponder: canvasView)
            canvasView.becomeFirstResponder()
        }

        // MARK: - PKCanvasViewDelegate
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }

        deinit {
            toolPicker?.removeObserver(canvasView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let v = context.coordinator.canvasView
        // Defer tool picker attachment until the view is in a window.
        DispatchQueue.main.async { context.coordinator.attachToolPickerIfPossible() }
        return v
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        let c = context.coordinator

        // Sync drawing
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }

        // Sync input policy
        let desiredPolicy: PKCanvasViewDrawingPolicy = isFingerDrawingEnabled ? .anyInput : .pencilOnly
        if uiView.drawingPolicy != desiredPolicy {
            uiView.drawingPolicy = desiredPolicy
        }

        // Re-show picker when the trigger changes (from your pencil button).
        if c.lastTrigger != toolPickerTrigger {
            c.lastTrigger = toolPickerTrigger
            c.showToolPicker()
        }
    }
}

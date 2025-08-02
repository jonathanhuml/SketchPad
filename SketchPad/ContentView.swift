// === Placement ===
// File: ContentView.swift
// Replace your existing ContentView.swift entirely with this file.
// Sidebar (files) on the left, drawing canvas in the main detail.

import SwiftUI
import PencilKit

struct ContentView: View {
    @StateObject private var store = SketchStore()

    // Drawing shown in the detail canvas
    @State private var current = PKDrawing()

    // Selected sketch in the sidebar (nil = new/unsaved)
    @State private var selection: Sketch?

    // Toggle finger vs pencil-only input
    @State private var pencilOnly = false

    var body: some View {
        NavigationSplitView {
            // === Sidebar: saved sketches ===
            List(selection: $selection) {
                Section("Sketches") {
                    ForEach(store.sketches) { sketch in
                        HStack(spacing: 12) {
                            Image(uiImage: sketch.thumbnail)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text(sketch.url.deletingPathExtension().lastPathComponent)
                                .lineLimit(1)
                        }
                        .tag(sketch)
                    }
                    .onDelete(perform: delete) // <-- now resolves
                }
            }
            .navigationTitle("Sketches")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        // Start a brand-new drawing in the detail
                        current = PKDrawing()
                        selection = nil
                    } label: { Label("New", systemImage: "plus") }

                    Button {
                        do {
                            try store.save(current)
                            store.loadAll()
                            // Select the newest (inserted at index 0)
                            selection = store.sketches.first
                        } catch {
                            print("Save failed:", error)
                        }
                    } label: { Label("Save", systemImage: "square.and.arrow.down") }
                }
            }
        } detail: {
            // === Detail: drawing canvas ===
            PKCanvasRepresentable(
                drawing: $current,
                isFingerDrawingEnabled: !pencilOnly
            )
            .ignoresSafeArea()
            .navigationTitle(selectionTitle)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        pencilOnly.toggle()
                    } label: {
                        Label(pencilOnly ? "Pencil Only" : "Any Input",
                              systemImage: pencilOnly ? "pencil.and.outline" : "hand.draw")
                    }
                }
            }
        }
        // Load the chosen sketch into the canvas
        .onChange(of: selection) { newValue in
            if let s = newValue, let d = store.load(url: s.url) {
                current = d
            }
        }
        .onAppear { store.loadAll() }
        .navigationSplitViewColumnWidth(min: 260, ideal: 300)
    }

    // Title shown above the canvas
    private var selectionTitle: String {
        if let s = selection {
            return s.url.deletingPathExtension().lastPathComponent
        } else {
            return "New Sketch"
        }
    }

    // Delete rows from sidebar + remove files from disk
    private func delete(at offsets: IndexSet) {
        for idx in offsets {
            guard store.sketches.indices.contains(idx) else { continue }
            let url = store.sketches[idx].url
            try? FileManager.default.removeItem(at: url)
        }
        store.loadAll()
        if let sel = selection, !store.sketches.contains(sel) {
            selection = nil
            current = PKDrawing()
        }
    }
}

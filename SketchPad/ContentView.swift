// === Placement ===
// File: ContentView.swift
// Replace your existing ContentView.swift with this file.
// Sidebar (files) on the left, drawing canvas in the main detail.
// Adds a BIG pencil-tip button pinned to the TOP-RIGHT of the canvas to show the Apple Pencil tool palette.

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

    // Bump this to request the PKToolPicker (handled inside PKCanvasRepresentable)
    @State private var toolPickerTrigger: Int = 0

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
                    .onDelete(perform: delete)
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
            // === Detail: drawing canvas + BIG top-right pencil button ===
            ZStack(alignment: .topTrailing) {
                PKCanvasRepresentable(
                    drawing: $current,
                    isFingerDrawingEnabled: !pencilOnly,
                    toolPickerTrigger: toolPickerTrigger
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

                // BIGGER pencil-tip button pinned to top-right to show Apple Pencil tools
                Button {
                    toolPickerTrigger &+= 1   // show Apple Pencil tool palette
                } label: {
                    Image(systemName: "pencil.tip")
                        .font(.system(size: 30, weight: .semibold)) // larger icon
                        .padding(20)                                 // larger tap target
                }
                .buttonStyle(.plain)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(.secondary, lineWidth: 1))
                .shadow(radius: 3)
                .padding(.top, 16)        // distance from the top safe area
                .padding(.trailing, 24)   // distance from the right edge
                .accessibilityLabel("Show Apple Pencil tools")
            }
        }
        // Load the chosen sketch into the canvas when selection changes
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

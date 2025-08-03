// === Placement ===
// File: ContentView.swift
// Replace your existing ContentView.swift with this file.
// Behavior: Sidebar + PencilKit canvas; overlays a typewriter-style text animation on the canvas; top-right pencil-tools button.

import SwiftUI
import PencilKit

struct ContentView: View {
    // MARK: – Sidebar & Canvas State
    @StateObject private var store = SketchStore()
    @State private var current = PKDrawing()
    @State private var selection: Sketch?
    @State private var pencilOnly = false
    @State private var toolPickerTrigger: Int = 0

    // MARK: – Typewriter Text Animation State
    private let fullText = "Hello World!"
    @State private var displayCount = 0
    @State private var displayedText = ""
    private let typewriterTimer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()
    @State private var canvasSize: CGSize = .zero

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
                        // New sketch
                        current = PKDrawing()
                        selection = nil
                    } label: {
                        Label("New", systemImage: "plus")
                    }
                    Button {
                        // Save current sketch
                        do {
                            try store.save(current)
                            store.loadAll()
                            selection = store.sketches.first
                        } catch {
                            print("Save failed:", error)
                        }
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                }
            }
        } detail: {
            // === Detail: Canvas + Typewriter Text + Pencil Button ===
            GeometryReader { geo in
                // Track canvas size
                Color.clear
                    .onAppear { canvasSize = geo.size }
                    .onChange(of: geo.size) { canvasSize = $0 }

                ZStack(alignment: .topTrailing) {
                    // PencilKit canvas
                    PKCanvasRepresentable(
                        drawing: $current,
                        isFingerDrawingEnabled: !pencilOnly,
                        toolPickerTrigger: toolPickerTrigger
                    )
                    .ignoresSafeArea()
                    .navigationTitle(selectionTitle)
                    .toolbar {
                        // Toggle finger vs pencil-only
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                pencilOnly.toggle()
                            } label: {
                                Label(
                                    pencilOnly ? "Pencil Only" : "Any Input",
                                    systemImage: pencilOnly ? "pencil.and.outline" : "hand.draw"
                                )
                            }
                        }
                    }

                    Text(displayedText)
                      .font(.system(size: 36, weight: .regular, design: .monospaced))
                      .foregroundColor(.primary)
                      .onReceive(typewriterTimer) { _ in
                        // Only advance until we hit the end of the string
                        if displayCount < fullText.count {
                          displayCount += 1
                          displayedText = String(fullText.prefix(displayCount))
                        }
                        // Once displayCount == fullText.count, we do nothing and the timer keeps firing
                        // but the text stays at full length and never resets.
                      }
                      .position(x: canvasSize.width / 2, y: 80)
                      .allowsHitTesting(false)

                    // Pencil-tools button
                    Button {
                        toolPickerTrigger &+= 1
                    } label: {
                        Image(systemName: "pencil.tip")
                            .font(.system(size: 30, weight: .semibold))
                            .padding(20)
                    }
                    .buttonStyle(.plain)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(.secondary, lineWidth: 1))
                    .shadow(radius: 3)
                    .padding(.top, 16)
                    .padding(.trailing, 24)
                    .accessibilityLabel("Show Apple Pencil tools")
                }
            }
        }
        // Sync picked sketch into the canvas
        .onChange(of: selection) { new in
            if let s = new, let d = store.load(url: s.url) {
                current = d
            }
        }
        // Load existing sketches
        .onAppear { store.loadAll() }
        .navigationSplitViewColumnWidth(min: 260, ideal: 300)
    }

    // MARK: – Helpers

    private var selectionTitle: String {
        selection?.url.deletingPathExtension().lastPathComponent ?? "New Sketch"
    }

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

// === Placement ===
// File: ContentView.swift
// Replace your existing ContentView.swift with this file.
// Behavior: Sidebar + PencilKit canvas; typewriter text wraps into multiple lines
// flowing downward; pencil-tools button remains in top-right.

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
    private let fullText = """
    Welcome to section 2.1 of Stewart's Calculus of Transcendentals. \
    In this section, we'll be exploring rules of differentiation for \
    special functions, like logarithms, inverse trigonometric functions, \
    and exponentials. First, we'll go over one of our favorite functions: \
    the natural logarithm. Here's the rule: d/dx ln(x) = 1/x. 
    
    Let's try an example together first. ry to differentiate f(x) = ln(2x+1). 
    
    Look arcane? No worries, let's go over a quick sketch of a proof. [SKIP] 
    """
    @State private var displayCount = 0
    @State private var displayedText = ""
    private let typewriterTimer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    // Track canvas size for proper wrapping width
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
                        current = PKDrawing()
                        selection = nil
                    } label: {
                        Label("New", systemImage: "plus")
                    }
                    Button {
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
            // === Detail: Canvas + wrapping typewriter text + pencil button ===
            GeometryReader { geo in
                Color.clear
                    .onAppear { canvasSize = geo.size }
                    .onChange(of: geo.size) { canvasSize = $0 }

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
                            Label(
                                pencilOnly ? "Pencil Only" : "Any Input",
                                systemImage: pencilOnly ? "pencil.and.outline" : "hand.draw"
                            )
                        }
                    }
                }
                // MARK: — wrap text into multiple lines, flowing down
                .overlay(
                    VStack(alignment: .leading) {
                        Text(displayedText)
                            .font(.system(size: 28, weight: .regular, design: .monospaced))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            // constrain to ~90% of canvas width for wrapping
                            .frame(maxWidth: canvasSize.width * 0.9, alignment: .leading)
                            .padding(.top, 20)
                            .padding(.leading, 20)
                        Spacer()
                    }
                    , alignment: .topLeading
                )
                // MARK: — pencil-tools button in top-right
                .overlay(
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
                    , alignment: .topTrailing
                )
                // MARK: — typewriter animation handler
                .onReceive(typewriterTimer) { _ in
                    if displayCount < fullText.count {
                        displayCount += 1
                        displayedText = String(fullText.prefix(displayCount))
                    }
                }
            }
        }
        // Sync selected sketch into canvas
        .onChange(of: selection) { new in
            if let s = new, let d = store.load(url: s.url) {
                current = d
            }
        }
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

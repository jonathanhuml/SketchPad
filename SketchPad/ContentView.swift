// === Placement ===
// File: ContentView.swift
// Replace your existing ContentView.swift with this file.
// Update: Adds a much larger gap between paragraphs (enough for ~4–5 handwritten lines),
// and that gap does NOT block drawing (touches pass through to the canvas).

import SwiftUI
import PencilKit
import AVFoundation

struct ContentView: View {
    // MARK: — Sidebar & Canvas State
    @StateObject private var store = SketchStore()
    @State private var current = PKDrawing()
    @State private var selection: Sketch?
    @State private var pencilOnly = false
    @State private var toolPickerTrigger = 0

    // MARK: — Typewriter Text Animation State (Paragraph 1)
    private let fullText = """
    Welcome to section 2.1 of Stewart's Calculus of Transcendentals. \
    In this section, we'll be exploring rules of differentiation for \
    special functions, like logarithms, inverse trigonometric functions, \
    and exponentials. First, we'll go over one of our favorite functions: \
    the natural logarithm.
    """
    @State private var displayCount = 0
    @State private var displayedText = ""
    @State private var lessonStarted = false

    // MARK: — Typewriter Text Animation State (Paragraph 2)
    private let secondText = "Awesome."
    @State private var secondDisplayCount = 0
    @State private var secondDisplayedText = ""
    @State private var secondScheduled = false
    @State private var secondStarted = false

    // Single timer drives both paragraphs
    private let typewriterTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    // MARK: — Audio Playback (reused for both starts)
    @State private var audioPlayer: AVAudioPlayer?

    // MARK: — Canvas Size (for wrapping & gap sizing)
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
            .navigationTitle("Section 2.1: Differentiation Rules.")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        current = PKDrawing()
                        selection = nil
                    } label: { Label("New", systemImage: "plus") }
                    Button {
                        do {
                            try store.save(current)
                            store.loadAll()
                            selection = store.sketches.first
                        } catch {
                            print("Save failed:", error)
                        }
                    } label: { Label("Save", systemImage: "square.and.arrow.down") }
                }
            }
        } detail: {
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

                // === Overlay 1: Start Lesson button (interactive)
                .overlay(
                    Button("Start lesson") {
                        guard !lessonStarted else { return }
                        lessonStarted = true
                        displayCount = 0
                        displayedText = ""
                        // Begin audio for paragraph 1
                        playLessonAudio()
                    }
                    .font(.headline)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(radius: 2)
                    .padding(.top, 20)
                    .padding(.leading, 20)
                    , alignment: .topLeading
                )

                // === Overlay 2: Paragraphs (non-interactive, so you can write in the gaps)
                .overlay(
                    VStack(alignment: .leading, spacing: 0) {
                        // Shift the text down a bit so it doesn't overlap the button
                        Spacer().frame(height: 56).allowsHitTesting(false)

                        // Paragraph 1
                        Text(displayedText)
                            .font(.system(size: 28, weight: .regular, design: .monospaced))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .frame(maxWidth: canvasSize.width * 0.9, alignment: .leading)
                            .allowsHitTesting(false)

                        // BIG writable gap between paragraphs (~4–5 lines)
                        let gapHeight = max(180, canvasSize.height * 0.18)
                        Color.clear
                            .frame(height: gapHeight)
                            .allowsHitTesting(false)

                        // Paragraph 2 (appears after delay when it starts typing)
                        if secondStarted || secondDisplayCount > 0 {
                            Text(secondDisplayedText)
                                .font(.system(size: 28, weight: .regular, design: .monospaced))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil)
                                .frame(maxWidth: canvasSize.width * 0.9, alignment: .leading)
                                .allowsHitTesting(false)
                        }

                        Spacer()
                            .allowsHitTesting(false)
                    }
                    .padding(.leading, 20)
                    .padding(.top, 20)
                    .allowsHitTesting(false)  // <-- whole text overlay lets touches fall through to the canvas
                    , alignment: .topLeading
                )

                // — Pencil-tools button in top-right
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

                // — Typewriter driver for both paragraphs
                .onReceive(typewriterTimer) { _ in
                    guard lessonStarted else { return }

                    // Paragraph 1 typing
                    if displayCount < fullText.count {
                        displayCount += 1
                        displayedText = String(fullText.prefix(displayCount))

                        // When paragraph 1 JUST finishes, schedule paragraph 2 after 10 seconds
                        if displayCount == fullText.count && !secondScheduled {
                            secondScheduled = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                                secondStarted = true
                                secondDisplayCount = 0
                                secondDisplayedText = ""
                                playLessonAudio() // reuse same MP3 for now
                            }
                        }
                    } else {
                        // If for any reason we missed scheduling, ensure it's scheduled
                        if !secondScheduled {
                            secondScheduled = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                                secondStarted = true
                                secondDisplayCount = 0
                                secondDisplayedText = ""
                                playLessonAudio()
                            }
                        }
                    }

                    // Paragraph 2 typing
                    if secondStarted && secondDisplayCount < secondText.count {
                        secondDisplayCount += 1
                        secondDisplayedText = String(secondText.prefix(secondDisplayCount))
                    }
                }
            }
        }
        // Sync selected sketch into canvas
        .onChange(of: selection) { new in
            if let s = new, let d = store.load(url: s.url) { current = d }
        }
        .onAppear { store.loadAll() }
        .navigationSplitViewColumnWidth(min: 260, ideal: 300)
    }

    // MARK: — Helpers

    private func playLessonAudio() {
        if let url = Bundle.main.url(forResource: "lesson2_1", withExtension: "mp3") {
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        }
    }

    private func delete(at offsets: IndexSet) {
        for idx in offsets where store.sketches.indices.contains(idx) {
            try? FileManager.default.removeItem(at: store.sketches[idx].url)
        }
        store.loadAll()
        if let sel = selection, !store.sketches.contains(sel) {
            selection = nil
            current = PKDrawing()
        }
    }
}


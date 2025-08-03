// === Placement ===
// File: ContentView.swift
// Replace your existing ContentView.swift with this file.
// Update:
// • Adds simple markup for the FIRST section (paragraph 1):
//    - Write "*new line*" in your source to start a new centered line for the text that follows.
//      (Each "*new line*" starts a NEW centered line; the very first segment stays left-aligned.)
//    - Write "bold{...}" to make the "..." part bold.
// • The typewriter reveals the styled text character-by-character (markup is NOT counted).
// • All existing audio/timing behavior is preserved: paragraph 2 starts 10s AFTER paragraph 1 audio finishes.

import SwiftUI
import PencilKit
import AVFoundation

// Helper delegate to detect when AVAudioPlayer finishes
final class AudioFinishDelegate: NSObject, AVAudioPlayerDelegate {
    var onFinish: (() -> Void)?
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [onFinish] in onFinish?() }
    }
}

struct ContentView: View {
    // MARK: — Sidebar & Canvas State
    @StateObject private var store = SketchStore()
    @State private var current = PKDrawing()
    @State private var selection: Sketch?
    @State private var pencilOnly = false
    @State private var toolPickerTrigger = 0

    // MARK: — Typewriter Text Animation State (Paragraph 1 with markup)
    // Markup supported:
    //   *new line*            → starts a new centered line
    //   bold{...}             → makes "..." bold within that line
    private let fullText = """
    Welcome to section 2.1 of Stewart's Calculus of Transcendentals. \
    In this section, we'll be exploring rules of differentiation for \
    special functions, like logarithms, inverse trigonometric functions, \
    and exponentials. First, we'll go over one of our favorite functions: \
    the natural logarithm. *new line* bold{DEFINITION:} d/dx ln(x) = 1/x. *new line* bold{PRACTICE:} Differentiate ln(5x)
    """
    @State private var displayCount = 0              // counts visible characters (excluding markup)
    @State private var lessonStarted = false

    // Parsed segments for paragraph 1 (computed from fullText)
    @State private var segments: [Segment] = []
    @State private var totalVisibleCount: Int = 0

    // MARK: — Typewriter Text Animation State (Paragraph 2)
    private let secondText = "Good try, but this is not quite right. Hint: use the Chain Rule (Section 1.5)"
    @State private var secondDisplayCount = 0
    @State private var secondDisplayedText = ""
    @State private var secondScheduled = false
    @State private var secondStarted = false
    @State private var secondWorkItem: DispatchWorkItem?

    // Single timer drives both paragraphs (faster typing: 0.07 s/char)
    private let typewriterTimer = Timer.publish(every: 0.07, on: .main, in: .common).autoconnect()

    // MARK: — Audio Playback
    @State private var audioPlayer: AVAudioPlayer?
    @State private var audioDelegate = AudioFinishDelegate() // persists for callbacks

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
                    .onAppear {
                        canvasSize = geo.size
                        if segments.isEmpty { // parse once
                            segments = parseSegments(from: fullText)
                            totalVisibleCount = segments.reduce(0) { $0 + $1.length }
                        }
                    }
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
                        // Play paragraph 1 audio; when it finishes, start 10s delay
                        playAudio(named: "lesson2_1") { [scheduleSecondParagraphAfterAudio] in
                            scheduleSecondParagraphAfterAudio()
                        }
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

                // === Overlay 2: Paragraphs (non-interactive so drawing passes through)
                .overlay(
                    VStack(alignment: .leading, spacing: 0) {
                        // keep clear of the button
                        Spacer().frame(height: 56).allowsHitTesting(false)

                        // Paragraph 1 (styled)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(segments.indices, id: \.self) { idx in
                                let seg = segments[idx]
                                let reveal = revealedCountForSegment(at: idx)
                                if reveal > 0 {
                                    let attr = attributedString(for: seg, reveal: reveal)
                                    Text(attr)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(seg.isCentered ? .center : .leading)
                                        .frame(maxWidth: canvasSize.width * 0.9,
                                               alignment: seg.isCentered ? .center : .leading)
                                        .allowsHitTesting(false)
                                }
                            }
                        }

                        // BIG writable gap between paragraphs (~4–5 lines)
                        let gapHeight = max(180, canvasSize.height * 0.18)
                        Color.clear
                            .frame(height: gapHeight)
                            .allowsHitTesting(false)

                        // Paragraph 2 (plain)
                        if secondStarted || secondDisplayCount > 0 {
                            Text(secondDisplayedText)
                                .font(.system(size: 28, weight: .regular, design: .monospaced))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil)
                                .frame(maxWidth: canvasSize.width * 0.9, alignment: .leading)
                                .allowsHitTesting(false)
                        }

                        Spacer().allowsHitTesting(false)
                    }
                    .padding(.leading, 20)
                    .padding(.top, 20)
                    .allowsHitTesting(false)
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

                    // Paragraph 1 typing (based on visible characters only)
                    if displayCount < totalVisibleCount {
                        displayCount += 1
                    }

                    // Paragraph 2 typing (begins only after audio finished + 10s delay)
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

    // MARK: — Scheduling & Audio

    // Called when the FIRST audio finishes; starts a strict 10s countdown
    private func scheduleSecondParagraphAfterAudio() {
        guard !secondScheduled else { return }
        secondScheduled = true
        secondWorkItem?.cancel()
        let work = DispatchWorkItem {
            startSecondParagraph()
        }
        secondWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: work)
    }

    private func startSecondParagraph() {
        guard !secondStarted else { return }
        secondStarted = true
        secondDisplayCount = 0
        secondDisplayedText = ""
        // Play audio for paragraph 2
        playAudio(named: "initial_feedback", onFinish: nil)
    }

    /// Plays an mp3 from bundle. If `onFinish` is provided, it will be called when playback ends.
    private func playAudio(named name: String, onFinish: (() -> Void)? = nil) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else {
            print("Audio file \(name).mp3 not found in bundle")
            return
        }
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = audioDelegate
        audioDelegate.onFinish = onFinish
        audioPlayer?.play()
    }

    // MARK: — Markup parsing & rendering for paragraph 1

    // A fragment is a run of text with a bold flag
    private struct Fragment {
        let text: String
        let isBold: Bool
        var length: Int { text.count }
    }

    // A segment is one line (left-aligned for the first, centered for any after "*new line*")
    private struct Segment {
        let fragments: [Fragment]
        let isCentered: Bool
        var length: Int { fragments.reduce(0) { $0 + $1.length } }
    }

    // Split by "*new line*" and parse bold{...} inside each segment
    private func parseSegments(from source: String) -> [Segment] {
        let parts = source.components(separatedBy: "*new line*")
        return parts.enumerated().map { idx, raw in
            let frags = parseBoldFragments(in: raw)
            return Segment(fragments: frags, isCentered: idx > 0)
        }
    }

    // Parse "bold{...}" markup into fragments; everything else is normal
    private func parseBoldFragments(in text: String) -> [Fragment] {
        var result: [Fragment] = []
        var i = text.startIndex

        func appendNormal(from start: String.Index, to end: String.Index) {
            if start < end {
                let s = String(text[start..<end])
                if !s.isEmpty { result.append(Fragment(text: s, isBold: false)) }
            }
        }

        while i < text.endIndex {
            if let rangeStart = text.range(of: "bold{", range: i..<text.endIndex) {
                // normal before bold
                appendNormal(from: i, to: rangeStart.lowerBound)
                // find closing "}"
                if let close = text.range(of: "}", range: rangeStart.upperBound..<text.endIndex) {
                    let boldContent = String(text[rangeStart.upperBound..<close.lowerBound])
                    if !boldContent.isEmpty {
                        result.append(Fragment(text: boldContent, isBold: true))
                    }
                    i = close.upperBound
                    continue
                } else {
                    // no closing }, treat remainder as normal
                    appendNormal(from: rangeStart.lowerBound, to: text.endIndex)
                    break
                }
            } else {
                // no more bold markers
                appendNormal(from: i, to: text.endIndex)
                break
            }
        }
        return result
    }

    // How many visible characters of segment at index `idx` should be revealed?
    private func revealedCountForSegment(at idx: Int) -> Int {
        let before = segments.prefix(idx).reduce(0) { $0 + $1.length }
        let remaining = max(0, displayCount - before)
        return min(segments[idx].length, remaining)
    }

    // Build an AttributedString with inline bold runs, revealing only `reveal` chars
    private func attributedString(for segment: Segment, reveal: Int) -> AttributedString {
        var remaining = reveal
        var combined = AttributedString()
        for frag in segment.fragments {
            if remaining <= 0 { break }
            let take = min(remaining, frag.length)
            let part = String(frag.text.prefix(take))
            var attr = AttributedString(part)
            // Set explicit fonts on runs so inline bolding works
            attr.font = .system(size: 28, weight: frag.isBold ? .bold : .regular, design: .monospaced)
            combined += attr
            remaining -= take
        }
        return combined
    }

    // MARK: — Helpers

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

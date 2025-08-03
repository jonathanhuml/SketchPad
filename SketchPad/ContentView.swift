// === Placement ===
// File: ContentView.swift
// Replace your existing ContentView.swift with this file.
// Fixes: declares the missing `fourthWorkItem` state so the code compiles.

import SwiftUI
import PencilKit
import AVFoundation

final class AudioFinishDelegate: NSObject, AVAudioPlayerDelegate {
    var onFinish: (() -> Void)?
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [onFinish] in onFinish?() }
    }
}

struct ContentView: View {
    // MARK: — Sidebar & Canvas
    @StateObject private var store = SketchStore()
    @State private var current = PKDrawing()
    @State private var selection: Sketch?
    @State private var pencilOnly = false
    @State private var toolPickerTrigger = 0

    // MARK: — Paragraph 1 (markup)
    private let fullText = """
    Welcome to section 2.1 of Stewart's Calculus of Transcendentals. \
    In this section, we'll be exploring rules of differentiation for \
    special functions, like logarithms, inverse trigonometric functions, \
    and exponentials. First, we'll go over one of our favorite functions: \
    the natural logarithm. *new line* bold{DEFINITION:} d/dx ln(x) = 1/x. *new line* bold{PRACTICE:} Differentiate ln(x^2)
    """
    @State private var segments1: [Segment] = []
    @State private var totalCount1 = 0
    @State private var count1 = 0

    // MARK: — Paragraph 2 (plain)
    private let secondText = "Good try, but this is not quite right. Hint: use the Chain Rule (Section 1.5)"
    @State private var text2 = ""
    @State private var count2 = 0
    @State private var secondStarted = false
    @State private var scheduled2 = false
    @State private var secondWorkItem: DispatchWorkItem?

    // MARK: — Paragraph 3 (markup)
    private let thirdText = """
    Good question! Here's a quick reminder about the Chain Rule: \
    *new line* bold{REMINDER:} d/dx f(g(x)) = f'(g(x)) * g'(x).
    """
    @State private var segments3: [Segment] = []
    @State private var totalCount3 = 0
    @State private var count3 = 0
    @State private var thirdStarted = false
    @State private var scheduled3 = false
    @State private var thirdWorkItem: DispatchWorkItem?

    // MARK: — Paragraph 4 (plain)
    private let fourthText = "Correct! Great job. Let's start a guided example."
    @State private var text4 = ""
    @State private var count4 = 0
    @State private var fourthStarted = false
    @State private var scheduled4 = false
    @State private var fourthWorkItem: DispatchWorkItem?  // ← Added missing declaration

    // MARK: — Flow & Timer
    @State private var lessonStarted = false
    private let timer = Timer.publish(every: 0.07, on: .main, in: .common).autoconnect()

    // MARK: — Audio
    @State private var audioPlayer: AVAudioPlayer?
    @State private var audioDelegate = AudioFinishDelegate()

    // MARK: — Layout
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Sketches") {
                    ForEach(store.sketches) { sketch in
                        HStack(spacing: 12) {
                            Image(uiImage: sketch.thumbnail)
                                .resizable().scaledToFill()
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
                    Button("New") { resetAll() }
                    Button {
                        do { try store.save(current); store.loadAll() }
                        catch { print("Save failed:", error) }
                    } label: { Label("Save", systemImage: "square.and.arrow.down") }
                }
            }
        } detail: {
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        canvasSize = geo.size
                        if segments1.isEmpty {
                            segments1 = parseSegments(from: fullText)
                            totalCount1 = segments1.reduce(0) { $0 + $1.length }
                        }
                        if segments3.isEmpty {
                            segments3 = parseSegments(from: thirdText)
                            totalCount3 = segments3.reduce(0) { $0 + $1.length }
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
                        Button { pencilOnly.toggle() }
                        label: {
                            Label(
                                pencilOnly ? "Pencil Only" : "Any Input",
                                systemImage: pencilOnly ? "pencil.and.outline" : "hand.draw"
                            )
                        }
                    }
                }

                // Start Lesson button
                .overlay(
                    Button("Start lesson") {
                        resetAll()
                        lessonStarted = true
                        playAudio(named: "lesson2_1") { scheduleSecond() }
                    }
                    .font(.headline)
                    .padding(.vertical, 6).padding(.horizontal, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(radius: 2)
                    .padding(.top, 20).padding(.leading, 20),
                    alignment: .topLeading
                )

                // Text overlays (non-interactive)
                .overlay(
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: 56).allowsHitTesting(false)

                        // Paragraph 1 styled
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(segments1.indices, id: \.self) { i in
                                let seg = segments1[i]
                                let prev = segments1.prefix(i).map(\.length).reduce(0, +)
                                let cnt = clamp(count1 - prev, lower: 0, upper: seg.length)
                                if cnt > 0 {
                                    Text(attributedString(for: seg, reveal: cnt))
                                        .multilineTextAlignment(seg.isCentered ? .center : .leading)
                                        .frame(maxWidth: canvasSize.width * 0.9,
                                               alignment: seg.isCentered ? .center : .leading)
                                        .allowsHitTesting(false)
                                }
                            }
                        }

                        // Gap before paragraph 2
                        let gap = max(180, canvasSize.height * 0.18)
                        Color.clear.frame(height: gap).allowsHitTesting(false)

                        // Paragraph 2
                        if count2 > 0 {
                            Text(text2)
                                .font(.system(size: 28, weight: .regular, design: .monospaced))
                                .frame(maxWidth: canvasSize.width * 0.9, alignment: .leading)
                                .allowsHitTesting(false)
                        }

                        // Paragraph 3 styled (immediately after)
                        if count3 > 0 {
                            ForEach(segments3.indices, id: \.self) { i in
                                let seg = segments3[i]
                                let prev = segments3.prefix(i).map(\.length).reduce(0, +)
                                let cnt = clamp(count3 - prev, lower: 0, upper: seg.length)
                                if cnt > 0 {
                                    Text(attributedString(for: seg, reveal: cnt))
                                        .multilineTextAlignment(seg.isCentered ? .center : .leading)
                                        .frame(maxWidth: canvasSize.width * 0.9,
                                               alignment: seg.isCentered ? .center : .leading)
                                        .allowsHitTesting(false)
                                }
                            }
                        }

                        // Gap before paragraph 4 (same as above)
                        Color.clear.frame(height: gap).allowsHitTesting(false)

                        // Paragraph 4
                        if count4 > 0 {
                            Text(text4)
                                .font(.system(size: 28, weight: .regular, design: .monospaced))
                                .frame(maxWidth: canvasSize.width * 0.9, alignment: .leading)
                                .allowsHitTesting(false)
                        }

                        Spacer().allowsHitTesting(false)
                    }
                    .padding(.leading, 20).padding(.top, 20)
                    .allowsHitTesting(false),
                    alignment: .topLeading
                )

                // Pencil tip button
                .overlay(
                    Button { toolPickerTrigger &+= 1 }
                    label: {
                        Image(systemName: "pencil.tip")
                            .font(.system(size: 30, weight: .semibold))
                            .padding(20)
                    }
                    .buttonStyle(.plain)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(.secondary, lineWidth: 1))
                    .shadow(radius: 3)
                    .padding(.top, 16).padding(.trailing, 24)
                    .accessibilityLabel("Show Apple Pencil tools"),
                    alignment: .topTrailing
                )

                // Typewriter driver
                .onReceive(timer) { _ in
                    guard lessonStarted else { return }
                    if count1 < totalCount1 { count1 += 1 }
                    if secondStarted && count2 < secondText.count {
                        count2 += 1; text2 = String(secondText.prefix(count2))
                    }
                    if thirdStarted && count3 < totalCount3 { count3 += 1 }
                    if fourthStarted && count4 < fourthText.count {
                        count4 += 1; text4 = String(fourthText.prefix(count4))
                    }
                }
            }
        }
        .onChange(of: selection) { s in
            if let d = store.load(url: s!.url) { current = d }
        }
        .onAppear { store.loadAll() }
        .navigationSplitViewColumnWidth(min: 260, ideal: 300)
    }

    // MARK: — Flow & Scheduling

    private func resetAll() {
        secondWorkItem?.cancel()
        thirdWorkItem?.cancel()
        fourthWorkItem?.cancel()
        lessonStarted = false
        count1 = 0; count2 = 0; count3 = 0; count4 = 0
        text2 = ""; text4 = ""
        secondStarted = false; thirdStarted = false; fourthStarted = false
        scheduled2 = false; scheduled3 = false; scheduled4 = false
    }

    private func scheduleSecond() {
        guard !scheduled2 else { return }
        scheduled2 = true
        let w = DispatchWorkItem { startSecond() }
        secondWorkItem = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: w)
    }
    private func startSecond() {
        secondStarted = true
        count2 = 0; text2 = ""
        playAudio(named: "initial_feedback") { scheduleThird() }
    }

    private func scheduleThird() {
        guard !scheduled3 else { return }
        scheduled3 = true
        let w = DispatchWorkItem { startThird() }
        thirdWorkItem = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 9, execute: w)
    }
    private func startThird() {
        thirdStarted = true
        count3 = 0
        playAudio(named: "answer_question") { scheduleFourth() }
    }

    private func scheduleFourth() {
        guard !scheduled4 else { return }
        scheduled4 = true

        // create a work item that actually starts para 4
        let work = DispatchWorkItem {
            fourthStarted = true
            count4 = 0
            text4 = ""
            playAudio(named: "secondary_feedback")
        }
        fourthWorkItem = work

        // fire it 8 seconds after para-3 audio finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: work)
    }

    private func playAudio(named name: String, onFinish: (() -> Void)? = nil) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return }
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = audioDelegate
        audioDelegate.onFinish = onFinish
        audioPlayer?.play()
    }

    // MARK: — Markup parsing

    private struct Fragment { let text: String; let isBold: Bool; var length: Int { text.count } }
    private struct Segment { let fragments: [Fragment]; let isCentered: Bool; var length: Int { fragments.reduce(0){$0+$1.length} } }

    private func parseSegments(from s: String) -> [Segment] {
        s.components(separatedBy: "*new line*").enumerated().map { idx, raw in
            let frags = parseBold(in: raw)
            return Segment(fragments: frags, isCentered: idx > 0)
        }
    }
    private func parseBold(in txt: String) -> [Fragment] {
        var res: [Fragment] = []; var i = txt.startIndex
        func add(_ str: String, bold: Bool) { if !str.isEmpty { res.append(Fragment(text: str, isBold: bold)) } }
        while i < txt.endIndex {
            if let o = txt.range(of: "bold{", range: i..<txt.endIndex) {
                add(String(txt[i..<o.lowerBound]), bold: false)
                if let c = txt.range(of: "}", range: o.upperBound..<txt.endIndex) {
                    add(String(txt[o.upperBound..<c.lowerBound]), bold: true)
                    i = c.upperBound; continue
                } else {
                    add(String(txt[o.lowerBound..<txt.endIndex]), bold: false)
                    break
                }
            } else {
                add(String(txt[i..<txt.endIndex]), bold: false)
                break
            }
        }
        return res
    }
    private func attributedString(for seg: Segment, reveal: Int) -> AttributedString {
        var rem = reveal, out = AttributedString()
        for frag in seg.fragments {
            if rem <= 0 { break }
            let take = min(rem, frag.length)
            var a = AttributedString(String(frag.text.prefix(take)))
            a.font = .system(size: 28, weight: frag.isBold ? .bold : .regular, design: .monospaced)
            out += a; rem -= take
        }
        return out
    }

    private func clamp(_ v: Int, lower: Int, upper: Int) -> Int { min(max(v, lower), upper) }

    private func delete(at offsets: IndexSet) {
        for idx in offsets where store.sketches.indices.contains(idx) {
            try? FileManager.default.removeItem(at: store.sketches[idx].url)
        }
        store.loadAll()
        if let sel = selection, !store.sketches.contains(sel) {
            selection = nil; current = PKDrawing()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView() }
}

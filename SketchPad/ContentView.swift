// === Placement ===
// File: ContentView.swift
// Replace your existing ContentView.swift with this file.
//
// Adds:
//  • "Ask question" button to the right of "Start lesson" with a 2s rainbow glow on tap.
//  • Paragraph 5 “saving progress...” (italic) directly below paragraph 4; shows ~2s with moving dots.
//  • After the first audio finishes: show “waiting...” (italic, moving dots) under paragraph 1 for 8s,
//    then exactly 2s before paragraph 2 starts: flash “analyzing answer...” for ~2s.
//  • After the “REMINDER” chunk (paragraph 3) audio finishes: repeat the same pattern relative to
//    paragraph 4’s start (8s later) — i.e., “waiting...” for 6s, then “analyzing answer...” for 2s.

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

    // MARK: — Paragraph 5 (saving flash)
    @State private var savingVisible = false
    @State private var savingDots = 1          // 1…3
    @State private var savingFrame = 0
    @State private var savingScheduled = false
    @State private var savingWorkItem: DispatchWorkItem?

    // MARK: — Waiting/Analyzing under Paragraph 1 (after audio 1 ends)
    @State private var wait1Visible = false
    @State private var wait1Dots = 1
    @State private var wait1Frame = 0
    @State private var wait1HideWork: DispatchWorkItem?

    @State private var analyze1Visible = false
    @State private var analyze1Dots = 1
    @State private var analyze1Frame = 0
    @State private var analyze1HideWork: DispatchWorkItem?
    @State private var analyze1ShowWork: DispatchWorkItem?

    // MARK: — Waiting/Analyzing under Paragraph 3 (after audio 3 ends)
    @State private var wait3Visible = false
    @State private var wait3Dots = 1
    @State private var wait3Frame = 0
    @State private var wait3HideWork: DispatchWorkItem?

    @State private var analyze3Visible = false
    @State private var analyze3Dots = 1
    @State private var analyze3Frame = 0
    @State private var analyze3HideWork: DispatchWorkItem?
    @State private var analyze3ShowWork: DispatchWorkItem?

    // MARK: — Flow & Timer
    @State private var lessonStarted = false
    private let timer = Timer.publish(every: 0.07, on: .main, in: .common).autoconnect()

    // MARK: — Audio
    @State private var audioPlayer: AVAudioPlayer?
    @State private var audioDelegate = AudioFinishDelegate()

    // MARK: — Layout
    @State private var canvasSize: CGSize = .zero

    // MARK: — Ask question glow state
    @State private var askGlowing = false
    @State private var askGlowWorkItem: DispatchWorkItem?

    // Rainbow gradient used when "Ask question" is tapped
    private var rainbowGradient: AngularGradient {
        AngularGradient(gradient: Gradient(colors: [
            .red, .orange, .yellow, .green, .blue, .purple, .red
        ]), center: .center)
    }

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
                        Button { pencilOnly.toggle() } label: {
                            Label(
                                pencilOnly ? "Pencil Only" : "Any Input",
                                systemImage: pencilOnly ? "pencil.and.outline" : "hand.draw"
                            )
                        }
                    }
                }

                // Start Lesson + Ask Question buttons (top-left)
                .overlay(
                    HStack(spacing: 12) {

                        // Start lesson button
                        Button("Start lesson") {
                            resetAll()
                            lessonStarted = true
                            // When audio 1 finishes, trigger waiting/analyzing for P1 and schedule P2.
                            playAudio(named: "lesson2_1") {
                                afterFirstAudioFinished()
                                scheduleSecond()
                            }
                        }
                        .font(.headline)
                        .padding(.vertical, 6).padding(.horizontal, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                        .shadow(radius: 2)
                        .accessibilityLabel("Start lesson")

                        // Ask question button — same style; rainbow glow for 2 seconds on tap
                        Button("Ask question") {
                            askButtonTapped()
                        }
                        .font(.headline)
                        .padding(.vertical, 6).padding(.horizontal, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule().fill(rainbowGradient).opacity(askGlowing ? 1 : 0)
                        )
                        .shadow(radius: 2)
                        .accessibilityLabel("Ask a question")
                    }
                    .padding(.top, 20)
                    .padding(.leading, 20),
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

                            // Waiting / Analyzing (under paragraph 1)
                            if wait1Visible {
                                Text("waiting" + String(repeating: ".", count: wait1Dots))
                                    .italic()
                                    .font(.system(size: 20, weight: .regular, design: .default))
                                    .frame(maxWidth: canvasSize.width * 0.9, alignment: .leading)
                                    .padding(.top, 6)
                                    .allowsHitTesting(false)
                            }
                            if analyze1Visible {
                                Text("analyzing answer" + String(repeating: ".", count: analyze1Dots))
                                    .italic()
                                    .font(.system(size: 20, weight: .regular, design: .default))
                                    .frame(maxWidth: canvasSize.width * 0.9, alignment: .leading)
                                    .padding(.top, 6)
                                    .allowsHitTesting(false)
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

                        // Paragraph 3 styled
                        if count3 > 0 {
                            VStack(alignment: .leading, spacing: 8) {
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

                                // Waiting / Analyzing (under paragraph 3)
                                if wait3Visible {
                                    Text("waiting" + String(repeating: ".", count: wait3Dots))
                                        .italic()
                                        .font(.system(size: 20, weight: .regular, design: .default))
                                        .frame(maxWidth: canvasSize.width * 0.9, alignment: .leading)
                                        .padding(.top, 6)
                                        .allowsHitTesting(false)
                                }
                                if analyze3Visible {
                                    Text("analyzing answer" + String(repeating: ".", count: analyze3Dots))
                                        .italic()
                                        .font(.system(size: 20, weight: .regular, design: .default))
                                        .frame(maxWidth: canvasSize.width * 0.9, alignment: .leading)
                                        .padding(.top, 6)
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

                        // Paragraph 5 — "saving progress..." directly below paragraph 4 (italic), 2s flash with moving dots
                        if savingVisible {
                            Text("saving progress" + String(repeating: ".", count: savingDots))
                                .italic()
                                .font(.system(size: 20, weight: .regular, design: .default))
                                .frame(maxWidth: canvasSize.width * 0.9, alignment: .leading)
                                .padding(.top, 8)
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
                    Button { toolPickerTrigger &+= 1 } label: {
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

                // Typewriter driver + dots animation
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

                    // Animate dots for visible indicators (~every 4 frames ≈ 0.28s)
                    if savingVisible {
                        savingFrame &+= 1
                        if savingFrame % 4 == 0 { savingDots = (savingDots % 3) + 1 }
                    }
                    if wait1Visible {
                        wait1Frame &+= 1
                        if wait1Frame % 4 == 0 { wait1Dots = (wait1Dots % 3) + 1 }
                    }
                    if analyze1Visible {
                        analyze1Frame &+= 1
                        if analyze1Frame % 4 == 0 { analyze1Dots = (analyze1Dots % 3) + 1 }
                    }
                    if wait3Visible {
                        wait3Frame &+= 1
                        if wait3Frame % 4 == 0 { wait3Dots = (wait3Dots % 3) + 1 }
                    }
                    if analyze3Visible {
                        analyze3Frame &+= 1
                        if analyze3Frame % 4 == 0 { analyze3Dots = (analyze3Dots % 3) + 1 }
                    }
                }
            }
        }
        .onChange(of: selection) { s in
            if let d = store.load(url: s!.url) { current = d }
        }
        .onAppear { store.loadAll() }
        .onChange(of: count4) { newVal in
            // When paragraph 4 finishes typing, trigger the 2-second "saving..." flash once.
            if newVal == fourthText.count && !savingScheduled {
                savingScheduled = true
                startSavingFlash()
            }
        }
        .navigationSplitViewColumnWidth(min: 260, ideal: 300)
    }

    // MARK: — Ask Question button behavior
    private func askButtonTapped() {
        askGlowWorkItem?.cancel()
        askGlowing = true
        let w = DispatchWorkItem { self.askGlowing = false }
        askGlowWorkItem = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: w)
    }

    // MARK: — After audio 1 finishes → show waiting (8s) then analyzing (2s before P2 starts)
    private func afterFirstAudioFinished() {
        // P2 is scheduled 10s after audio 1 → show waiting for 8s, then analyzing for 2s.
        showWaiting1(duration: 8.0)
        scheduleAnalyzing1(showAfter: 8.0, duration: 2.0)
    }

    private func showWaiting1(duration: Double) {
        wait1HideWork?.cancel()
        wait1Frame = 0
        wait1Dots = 1
        wait1Visible = true
        let hide = DispatchWorkItem { self.wait1Visible = false }
        wait1HideWork = hide
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: hide)
    }

    private func scheduleAnalyzing1(showAfter: Double, duration: Double) {
        analyze1ShowWork?.cancel()
        analyze1HideWork?.cancel()
        analyze1Frame = 0
        analyze1Dots = 1
        let show = DispatchWorkItem { self.analyze1Visible = true }
        analyze1ShowWork = show
        let hide = DispatchWorkItem { self.analyze1Visible = false }
        analyze1HideWork = hide
        DispatchQueue.main.asyncAfter(deadline: .now() + showAfter, execute: show)
        DispatchQueue.main.asyncAfter(deadline: .now() + showAfter + duration, execute: hide)
    }

    // MARK: — After audio 3 finishes (“REMINDER”) → waiting then analyzing before P4
    private func afterThirdAudioFinished() {
        // P4 is scheduled 8s after audio 3 → mirror behavior:
        // waiting for 6s, then analyzing for the last 2s before P4 starts.
        showWaiting3(duration: 6.0)
        scheduleAnalyzing3(showAfter: 6.0, duration: 2.0)
    }

    private func showWaiting3(duration: Double) {
        wait3HideWork?.cancel()
        wait3Frame = 0
        wait3Dots = 1
        wait3Visible = true
        let hide = DispatchWorkItem { self.wait3Visible = false }
        wait3HideWork = hide
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: hide)
    }

    private func scheduleAnalyzing3(showAfter: Double, duration: Double) {
        analyze3ShowWork?.cancel()
        analyze3HideWork?.cancel()
        analyze3Frame = 0
        analyze3Dots = 1
        let show = DispatchWorkItem { self.analyze3Visible = true }
        analyze3ShowWork = show
        let hide = DispatchWorkItem { self.analyze3Visible = false }
        analyze3HideWork = hide
        DispatchQueue.main.asyncAfter(deadline: .now() + showAfter, execute: show)
        DispatchQueue.main.asyncAfter(deadline: .now() + showAfter + duration, execute: hide)
    }

    // MARK: — Saving flash behavior (after paragraph 4 completes typing)
    private func startSavingFlash() {
        savingWorkItem?.cancel()
        savingVisible = true
        savingDots = 1
        savingFrame = 0
        let hide = DispatchWorkItem { self.savingVisible = false }
        savingWorkItem = hide
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: hide)
    }

    // MARK: — Flow & Scheduling

    private func resetAll() {
        // Cancel scheduled work
        secondWorkItem?.cancel()
        thirdWorkItem?.cancel()
        fourthWorkItem?.cancel()
        askGlowWorkItem?.cancel()
        savingWorkItem?.cancel()

        wait1HideWork?.cancel()
        analyze1HideWork?.cancel()
        analyze1ShowWork?.cancel()

        wait3HideWork?.cancel()
        analyze3HideWork?.cancel()
        analyze3ShowWork?.cancel()

        // Reset indicators
        askGlowing = false

        savingVisible = false
        savingScheduled = false
        savingDots = 1
        savingFrame = 0

        wait1Visible = false; wait1Dots = 1; wait1Frame = 0
        analyze1Visible = false; analyze1Dots = 1; analyze1Frame = 0

        wait3Visible = false; wait3Dots = 1; wait3Frame = 0
        analyze3Visible = false; analyze3Dots = 1; analyze3Frame = 0

        // Reset flow
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
        // When audio 3 finishes, trigger waiting/analyzing for P3 and schedule P4.
        playAudio(named: "answer_question") {
            afterThirdAudioFinished()
            scheduleFourth()
        }
    }

    private func scheduleFourth() {
        guard !scheduled4 else { return }
        scheduled4 = true

        let work = DispatchWorkItem {
            fourthStarted = true
            count4 = 0
            text4 = ""
            playAudio(named: "secondary_feedback")
        }
        fourthWorkItem = work

        // P4 starts 8 seconds after para-3 audio finishes
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

import UIKit
import PencilKit
import AVFoundation

class PracticeViewController: UIViewController {
    private let canvas = PKCanvasView()
    private let handwritingService = HandwritingRecognitionService()
    private let speechService = SpeechRecognitionService()
    private let llmService = LLMService()
    private let ttsService = ElevenLabsAPIService()
    private let question: String
    private let answer: String

    init(question: String, answer: String) {
        self.question = question
        self.answer = answer
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCanvas()
        startListeningLoop()
    }

    private func setupCanvas() {
        view.backgroundColor = .white
        canvas.frame = view.bounds.inset(by: .init(top:100,left:20,bottom:100,right:20))
        canvas.drawingPolicy = .anyInput
        view.addSubview(canvas)
    }

    private func startListeningLoop() {
        try? speechService.startListening { transcript in
            guard transcript.lowercased().contains("did i do it right") else { return }
            self.evaluateWork()
        }
    }

    private func evaluateWork() {
        let image = canvas.drawing.image(from: canvas.bounds, scale: UIScreen.main.scale)
        handwritingService.recognize(from: image) { steps in
            self.llmService.evaluate(steps: steps,
                                     question: self.question,
                                     expected: self.answer) { feedback in
                guard let fb = feedback else { return }
                let full = fb.diagnosis + (fb.suggestion.map { "\n\($0)" } ?? "")
                DispatchQueue.main.async {
                    self.ttsService.synthesize(text: full) { _ in }
                    let js = "window.postMessage({ type: 'render', text: '\(full)' }, '*');"
                    // render via embedded WKWebView (if using one)
                }
            }
        }
    }
}

import UIKit
import WebKit
import AVFoundation

extension Notification.Name {
    /// Posted by PracticeViewController when the user completes practice
    static let didFinishPractice = Notification.Name("didFinishPractice")
}

class LessonViewController: UIViewController {
    private let webView     = WKWebView()
    private let ttsService  = ElevenLabsAPIService()
    private let lesson      = LessonManager()
    private var audioPlayer: AVAudioPlayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()

        // Listen for practice-complete to resume the lesson
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(showNext),
                                               name: .didFinishPractice,
                                               object: nil)

        // Kick off
        lesson.loadLesson(named: "lesson1")
        showNext()
    }

    /// Layout and load calligraphy.html
    private func setupWebView() {
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        if let htmlURL = Bundle.main
                .url(forResource: "calligraphy", withExtension: "html", subdirectory: "Resources") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        }
    }

    /// Advances to the next segment: either speaks & renders narration, or presents practice
    @objc func showNext() {
        guard let segment = lesson.nextSegment() else { return }

        switch segment.type {
        case .narration:
            guard let text = segment.text else { return }
            renderText(text)
            ttsService.synthesize(text: text) { [weak self] url in
                guard let self = self, let url = url else { return }
                DispatchQueue.main.async {
                    do {
                        self.audioPlayer = try AVAudioPlayer(contentsOf: url)
                        self.audioPlayer?.delegate = self
                        self.audioPlayer?.play()
                    } catch {
                        // If playback fails, immediately go to next
                        self.showNext()
                    }
                }
            }

        case .practice:
            guard
                let question = segment.question,
                let answer   = segment.answer
            else { return }

            DispatchQueue.main.async {
                let pc = PracticeViewController(question: question, answer: answer)
                pc.modalPresentationStyle = .fullScreen
                self.present(pc, animated: true)
            }
        }
    }

    /// Sends text into the Calligraphy.js canvas via postMessage
    private func renderText(_ text: String) {
        let escaped = text
            .replacingOccurrences(of: "\\",  with: "\\\\")
            .replacingOccurrences(of: "\"",  with: "\\\"")
            .replacingOccurrences(of: "\n",  with: "\\n")
        let js = "window.postMessage({ type: 'render', text: \"\(escaped)\" }, '*');"
        DispatchQueue.main.async {
            self.webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}

// MARK: – AVAudioPlayerDelegate

extension LessonViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // When narration finishes, move on
        showNext()
    }
}

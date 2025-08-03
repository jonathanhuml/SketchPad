import Speech

class SpeechRecognitionService {
    private let audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer()
    private let request = SFSpeechAudioBufferRecognitionRequest()

    func startListening(onResult: @escaping (String) -> Void) throws {
        SFSpeechRecognizer.requestAuthorization { auth in
            guard auth == .authorized else { return }
            try? self.startSession(onResult: onResult)
        }
    }

    private func startSession(onResult: @escaping (String) -> Void) throws {
        let node = audioEngine.inputNode
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            self.request.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer?.recognitionTask(with: request) { result, _ in
            guard let result = result else { return }
            let transcript = result.bestTranscription.formattedString
            onResult(transcript)
        }
    }

    func stopListening() {
        audioEngine.stop()
        request.endAudio()
        recognitionTask?.cancel()
    }
}

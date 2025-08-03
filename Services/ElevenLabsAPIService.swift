import Foundation
import AVFoundation

class ElevenLabsAPIService {
    private let apiKey = "YOUR_ELEVENLABS_API_KEY"
    private let voiceId = "VOICE_ID"
    private let endpoint = URL(string: "https://api.elevenlabs.io/v1/text-to-speech")!

    func synthesize(text: String, completion: @escaping (URL?) -> Void) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "voice": voiceId,
            "input": text
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else { completion(nil); return }
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("speech.mp3")
            do {
                try data.write(to: tmp)
                completion(tmp)
            } catch {
                completion(nil)
            }
        }.resume()
    }
}

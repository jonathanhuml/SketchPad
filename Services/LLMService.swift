import Foundation

struct Feedback: Codable {
    let diagnosis: String
    let suggestion: String?
}

class LLMService {
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let apiKey = "YOUR_OPENAI_API_KEY"

    func evaluate(steps: [String], question: String, expected: String, completion: @escaping (Feedback?) -> Void) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = [
            "role": "system", "content": "You are a math tutor."
        ]
        let userMsg = [
            "role": "user",
            "content": "Question: \(question)\nSteps:\n\(steps.joined(separator:"\n"))\nAnswer: \(expected)\nRespond with JSON {diagnosis: ..., suggestion: ...}."
        ]
        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [prompt, userMsg]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let feedback = try? JSONDecoder().decode(Feedback.self, from: data) else {
                completion(nil)
                return
            }
            completion(feedback)
        }.resume()
    }
}
import Vision
import UIKit

class HandwritingRecognitionService {
    func recognize(from image: UIImage, completion: @escaping ([String]) -> Void) {
        guard let cgImage = image.cgImage else { completion([]); return }
        let request = VNRecognizeTextRequest { req, _ in
            let texts = req.results?
                .compactMap { ($0 as? VNRecognizedTextObservation)?.topCandidates(1).first?.string }
                .filter { !$0.isEmpty } ?? []
            completion(texts)
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true
        request.recognizesHandwriting = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
}
import Foundation

struct LessonSegment: Codable {
    enum SegmentType: String, Codable {
        case narration
        case practice
    }
    let type: SegmentType
    let text: String?
    let question: String?
    let answer: String?
}

private struct Lesson: Codable {
    let title: String
    let segments: [LessonSegment]
}

class LessonManager {
    private(set) var segments: [LessonSegment] = []
    private var currentIndex = 0

    /// Loads `Lessons/<name>.json` and resets the cursor
    func loadLesson(named name: String) {
        currentIndex = 0
        guard let url = Bundle.main
                .url(forResource: name, withExtension: "json", subdirectory: "Lessons") else
        {
            print("Lesson file not found: \(name).json")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let lesson = try JSONDecoder().decode(Lesson.self, from: data)
            self.segments = lesson.segments
        } catch {
            print("Failed to load lesson \(name): \(error)")
        }
    }

    /// Returns the next segment (narration or practice), or nil if done
    func nextSegment() -> LessonSegment? {
        guard currentIndex < segments.count else { return nil }
        let seg = segments[currentIndex]
        currentIndex += 1
        return seg
    }
}

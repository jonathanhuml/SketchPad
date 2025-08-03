import Foundation

struct LessonService {
    func fetchLessons() -> [Lesson] {
        guard
            let url = Bundle.main.url(forResource: "lessons", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let lessons = try? JSONDecoder().decode([Lesson].self, from: data)
        else {
            return []
        }
        return lessons
    }
}

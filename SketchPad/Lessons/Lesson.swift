import Foundation

struct Lesson: Identifiable, Codable {
    let id: UUID
    let title: String
    let content: String
}

import SwiftUI

struct LessonsView: View {
    private let service = LessonService()
    @State private var lessons: [Lesson] = []

    var body: some View {
        NavigationStack {
            List(lessons) { lesson in
                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson.title)
                        .font(.headline)
                    Text(lesson.content)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Lessons")
        }
        .onAppear {
            lessons = service.fetchLessons()
        }
    }
}

#Preview {
    LessonsView()
}

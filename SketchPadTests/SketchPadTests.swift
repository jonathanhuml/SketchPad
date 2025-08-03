//
//  SketchPadTests.swift
//  SketchPadTests
//
//  Created by Jonathan  Huml on 8/2/25.
//

import Testing
@testable import SketchPad

struct SketchPadTests {
    @Test func lessonsLoad() throws {
        let service = LessonService()
        let lessons = service.fetchLessons()
        #expect(!lessons.isEmpty)
    }

}

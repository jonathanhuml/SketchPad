// === Placement ===
// File: SketchPadApp.swift
// Xcode: Replace the auto-generated file of the same name at the project root (inside your app target).
// Purpose: App entry point that loads ContentView.
//
// Notes:
// - This file is created by Xcode automatically; just replace its contents with the below.

import SwiftUI

@main
struct SketchPadApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()   // now ContentView is your LessonViewController in disguise
        .edgesIgnoringSafeArea(.all)
    }
  }
}

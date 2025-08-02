//
//  SketchPadApp.swift
//  SketchPad
//
//  Created by Jonathan  Huml on 8/2/25.
//

import SwiftUI

@main
struct SketchPadApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

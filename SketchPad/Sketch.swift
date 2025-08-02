//
//  Sketch.swift
//  SketchPad
//
//  Created by Jonathan  Huml on 8/2/25.
//


// === Placement ===
// File: SketchStore.swift
// Xcode: Create a new Swift File in your app target (File ▸ New ▸ File… ▸ Swift File) and name it exactly this.
// Purpose: Persistence layer for saving/loading PKDrawing files and generating thumbnails.
// Storage: Saves .pkit files into the app's Documents directory (in-app gallery reads from there).
//
// Optional: The exportPNG method shows how to write a PNG for sharing.

import Foundation
import PencilKit
import UIKit

struct Sketch: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let thumbnail: UIImage
}

final class SketchStore: ObservableObject {
    @Published var sketches: [Sketch] = []

    private var docs: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private func thumb(for drawing: PKDrawing, size: CGSize = .init(width: 200, height: 200)) -> UIImage {
        let image = drawing.image(from: CGRect(origin: .zero, size: size), scale: UIScreen.main.scale)
        return image
    }

    func save(_ drawing: PKDrawing) throws {
        let id = UUID()
        let url = docs.appendingPathComponent("\(id.uuidString).pkit")
        try drawing.dataRepresentation().write(to: url, options: .atomic)
        let sketch = Sketch(id: id, url: url, thumbnail: thumb(for: drawing))
        sketches.insert(sketch, at: 0)
    }

    func loadAll() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) else { return }
        let drawings = files.filter { $0.pathExtension == "pkit" }
        sketches = drawings.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let drawing = try? PKDrawing(data: data) else { return nil }
            return Sketch(id: UUID(), url: url, thumbnail: thumb(for: drawing))
        }.sorted { $0.url.lastPathComponent > $1.url.lastPathComponent }
    }

    func load(url: URL) -> PKDrawing? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PKDrawing(data: data)
    }

    // Optional: export a PNG of the current drawing
    func exportPNG(_ drawing: PKDrawing, to url: URL, canvasSize: CGSize = .init(width: 2048, height: 1536), scale: CGFloat = 2.0) throws {
        let img = drawing.image(from: CGRect(origin: .zero, size: canvasSize), scale: scale)
        guard let png = img.pngData() else { throw NSError(domain: "PNGEncoding", code: -1) }
        try png.write(to: url, options: .atomic)
    }
}

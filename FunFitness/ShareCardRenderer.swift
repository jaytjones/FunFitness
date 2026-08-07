//
//  ShareCardRenderer.swift
//  FunFitness
//
//  Rasterizes a ShareCard to a PNG in the temp directory for sharing. Mirrors
//  the temp-file pattern used by ExportManager for CSV/JSON exports.
//

import SwiftUI

@MainActor
enum ShareCardRenderer {

    /// Renders `content` to a PNG at 3× and returns a temp-file URL, or nil on
    /// failure. `filename` should be stable per card kind so shares overwrite
    /// rather than accumulate.
    static func pngURL(for content: ShareCardContent, filename: String) -> URL? {
        let renderer = ImageRenderer(content: ShareCard(content: content))
        renderer.scale = 3

        guard let image = renderer.uiImage, let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

import Foundation
import Shared

/// Writes the shared MapLibre style (`MapStyle.json(dark)`) to Caches and hands out its file URL for `styleURL`.
/// The JSON is generated in shared from the token table, so there is nothing to bundle and nothing to keep in sync.
enum MapStyleStore {
    static func url(dark: Bool) -> URL {
        let directory = (try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let file = directory.appendingPathComponent(dark ? "map-style-dark.json" : "map-style-light.json")
        var json = MapStyle.shared.json(dark: dark)
        #if DEBUG
        json = MapDebug.transform(styleJSON: json)
        #endif
        // Rewrite only when the generated JSON changed (a new shared version), not on every launch.
        if (try? String(contentsOf: file, encoding: .utf8)) != json {
            try? json.write(to: file, atomically: true, encoding: .utf8)
        }
        return file
    }
}

import SwiftUI

/// The Map tab: creates the Swift `MapViewModel` (and the shared Kotlin one under it) when the tab is first shown.
struct MapTab: View {
    let app: AppDependencies
    let isMapEnabled: Bool
    @State private var model: MapViewModel?

    var body: some View {
        Group {
            if let model {
                MapScreen(model: model, isMapEnabled: isMapEnabled)
            } else {
                Color.tk.bg.ignoresSafeArea()
            }
        }
        .task {
            guard model == nil else { return }
            let made = app.makeMapViewModel()
            model = made
            #if DEBUG
            await MapDebug.run(on: made)
            #endif
        }
    }
}

import SwiftUI

/// The Map tab: creates the Swift `MapViewModel` (and the shared Kotlin one under it) when the tab is first shown.
struct MapTab: View {
    let app: AppDependencies
    let isMapEnabled: Bool
    /// Set while the task / new-task sheet is open: the root hides (not removes) the tab bar so the map shows through
    /// around the sheet's rounded corners, as on Android.
    @Binding var barHidden: Bool
    @State private var model: MapViewModel?

    var body: some View {
        Group {
            if let model {
                MapScreen(model: model, isMapEnabled: isMapEnabled, barHidden: $barHidden)
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

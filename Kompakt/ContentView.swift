import SwiftUI

struct ContentView: View {
    var body: some View {
        MainView()
            .environmentObject(AppModel.shared)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel.shared)
}

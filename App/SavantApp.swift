import SwiftUI
import SavantKit

@main
struct SavantUltimateApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup { RootView().environmentObject(model) }
    }
}

@MainActor
final class AppModel: ObservableObject {
    let client = SavantClient()
    @Published var season = Calendar.current.component(.year, from: Date())
}

enum Theme {
    static let navy = Color(red: 0.05, green: 0.15, blue: 0.30)
    static let red = Color(red: 0.78, green: 0.10, blue: 0.16)
}

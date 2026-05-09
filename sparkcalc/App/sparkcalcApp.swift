import SwiftUI

@main
struct sparkcalcApp: App {
    var body: some Scene {
        WindowGroup {
            CalculatorView()
                .frame(minWidth: 300, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
        }
        .defaultSize(width: 550, height: 550)
        .windowResizability(.contentMinSize)
    }
}

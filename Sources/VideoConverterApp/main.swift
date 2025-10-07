import SwiftUI

@main
struct VideoConverterApp: App {
    @StateObject private var viewModel = ConverterViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
        .commands {
            CommandMenu("Convert") {
                Button("Select Files…") {
                    viewModel.pickFilesAndConvert()
                }
                .disabled(viewModel.isProcessing)
            }
        }
    }
}

import SwiftUI

@main
struct KubexApp: App {
    @StateObject private var appModel = AppModel()

    init() {
        handleCommandLineArguments()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
        }
        .commands {
            SidebarCommands()
            CommandMenu("Clusters") {
                Button("Refresh") {
                    Task { await appModel.refreshClusters() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
        MenuBarExtra("Kubex", systemImage: "shippingbox") {
            MenuBarStatusView()
                .environmentObject(appModel)
        }
    }

    private func handleCommandLineArguments() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let dumpIndex = arguments.firstIndex(of: "--env-dump") else { return }

        var values: [String] = []
        var current = dumpIndex + 1
        while current < arguments.count {
            let argument = arguments[current]
            if argument.starts(with: "--") { break }
            values.append(argument)
            current += 1
        }

        if values.isEmpty {
            print(ProcessInfo.processInfo.environment["PATH"] ?? "")
        } else {
            for name in values {
                let value = ProcessInfo.processInfo.environment[name] ?? ""
                print("\(name)=\(value)")
            }
        }
        exit(EXIT_SUCCESS)
    }
}

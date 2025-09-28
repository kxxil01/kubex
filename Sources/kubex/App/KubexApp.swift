import SwiftUI
import AppKit

@main
struct KubexApp: App {
    @StateObject private var appModel = AppModel()

    init() {
        handleCommandLineArguments()
        NSApplication.shared.applicationIconImage = KubexApp.appIcon
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
            CommandGroup(after: .textEditing) {
                Button(appModel.isQuickSearchPresented ? "Hide Quick Search" : "Quick Search…") {
                    if appModel.isQuickSearchPresented {
                        appModel.dismissQuickSearch()
                    } else {
                        appModel.presentQuickSearch()
                    }
                }
                .keyboardShortcut("k", modifiers: [.command])
                .disabled(!appModel.isQuickSearchPresented && (appModel.selectedCluster?.isConnected != true))
            }
        }
        MenuBarExtra(isInserted: .constant(true)) {
            MenuBarStatusView()
                .environmentObject(appModel)
        } label: {
            Image(nsImage: KubexApp.menuBarIcon)
                .renderingMode(.original)
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

private extension KubexApp {
    static let menuBarIcon: NSImage = loadModuleImage(named: "MenuBarIcon")
    static let appIcon: NSImage = loadModuleImage(named: "AppIcon")

    static func loadModuleImage(named name: String) -> NSImage {
        if let asset = Bundle.module.image(forResource: NSImage.Name(name)) {
            return asset
        }

        if let url = Bundle.module.url(forResource: "Icons/\(name)", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }

        // Fallback to a simple system placeholder if the asset is missing.
        let fallback = NSImage(size: NSSize(width: 64, height: 64))
        fallback.lockFocus()
        NSColor.systemGray.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: fallback.size)).fill()
        fallback.unlockFocus()
        return fallback
    }
}

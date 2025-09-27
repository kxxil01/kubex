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
    static let menuBarIcon: NSImage = {
        let size = CGSize(width: 22, height: 22)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let rect = CGRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        NSColor.systemBlue.setFill()
        path.fill()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let font = NSFont.boldSystemFont(ofSize: 11)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]
        let text = "KBX" as NSString
        let textSize = text.size(withAttributes: attributes)
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attributes)

        image.isTemplate = false
        return image
    }()

    static let appIcon: NSImage = {
        let size = CGSize(width: 512, height: 512)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let rect = CGRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect, xRadius: 96, yRadius: 96)
        NSColor(calibratedRed: 0.12, green: 0.36, blue: 0.82, alpha: 1).setFill()
        path.fill()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let font = NSFont.boldSystemFont(ofSize: 220)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]
        let text = "KBX" as NSString
        let textSize = text.size(withAttributes: attributes)
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attributes)

        image.isTemplate = false
        return image
    }()
}

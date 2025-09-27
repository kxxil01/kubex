import AppKit
import SwiftUI

struct MenuBarStatusView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let cluster = model.connectedCluster {
                Label(cluster.name, systemImage: cluster.health.systemImage)
                    .foregroundStyle(cluster.health.tint)
                Text(cluster.contextName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if model.unhealthySummary.count > 0 {
                    ForEach(model.unhealthySummary, id: \.self) { message in
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                } else {
                    Label("All workloads healthy", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
                if !model.activePortForwards.isEmpty {
                    Divider()
                    Text("Port Forwards")
                        .font(.caption.smallCaps())
                        .foregroundStyle(.secondary)
                    ForEach(model.activePortForwards) { forward in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("pod/\(forward.request.podName)")
                                    .font(.caption)
                                Text("localhost:\(forward.request.localPort) → \(forward.request.remotePort)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                Task { await model.stopPortForward(id: forward.id) }
                            } label: {
                                Image(systemName: "xmark.circle")
                            }
                            .buttonStyle(.borderless)
                            .help("Stop port forward")
                        }
                    }
                }
            } else {
                Text("No cluster connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("Open Kubex") {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .padding(12)
        .frame(minWidth: 220)
    }
}

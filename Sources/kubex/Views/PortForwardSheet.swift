import SwiftUI

struct PortForwardSheet: View {
    let cluster: Cluster
    let namespace: Namespace
    let pod: PodSummary

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var entries: [ForwardEntry] = []
    @State private var isSubmitting = false
    @State private var validationMessage: String?
    @State private var isLoadingPorts = true
    @State private var loadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Port Forward · \(pod.name)")
                    .font(.title3.bold())
                Text("\(cluster.name) · Namespace \(namespace.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                if isLoadingPorts {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Discovering container ports…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if let loadError {
                    Label(loadError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.footnote)
                }

                ForEach($entries) { $entry in
                    ForwardEntryEditor(entry: $entry)
                        .disabled(isSubmitting)
                }

                Button {
                    addCustomEntry()
                } label: {
                    Label("Add Port Mapping", systemImage: "plus.circle")
                }
                .buttonStyle(.link)
                .disabled(isSubmitting)
            }
            .frame(width: 420)

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(action: startForward) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Start")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isSubmitting)
            }
        }
        .padding(20)
        .frame(minWidth: 420)
        .task { await loadDefaultEntries() }
    }

    private func startForward() {
        guard !isSubmitting else { return }
        validationMessage = nil

        let enabledEntries = entries.filter { $0.isEnabled }
        guard !enabledEntries.isEmpty else {
            validationMessage = "Select at least one port to forward."
            return
        }

        guard enabledEntries.allSatisfy({ $0.remotePort.isValidPort && $0.localPort.isValidPort }) else {
            validationMessage = "Ports must be between 1 and 65535."
            return
        }

        isSubmitting = true
        Task {
            for entry in enabledEntries {
                let request = PortForwardRequest(
                    clusterID: cluster.id,
                    contextName: cluster.contextName,
                    namespace: namespace.name,
                    podName: pod.name,
                    remotePort: entry.remotePort,
                    localPort: entry.localPort
                )
                await model.startPortForward(request: request)
                if model.error != nil { break }
            }
            await MainActor.run {
                isSubmitting = false
                if let errorMessage = model.error?.message {
                    validationMessage = errorMessage
                    model.error = nil
                } else {
                    dismiss()
                }
            }
        }
    }

    @MainActor
    private func loadDefaultEntries() async {
        isLoadingPorts = true
        defer { isLoadingPorts = false }

        let detailResult = await model.fetchPodDetail(cluster: cluster, namespace: namespace, pod: pod)
        switch detailResult {
        case .success(let detail):
            let discovered = ForwardEntry.entries(from: detail)
            if discovered.isEmpty {
                entries = [ForwardEntry.customDefault()]
                loadError = "No container ports declared. Add a mapping manually."
            } else {
                entries = discovered
                loadError = nil
            }
        case .failure(let error):
            entries = [ForwardEntry.customDefault()]
            loadError = error.message
        }
    }

    private func addCustomEntry() {
        let next = ForwardEntry(id: UUID(), sourceDescription: "Custom", remotePort: 80, localPort: 8080, protocol: "TCP", isEnabled: true, isCustom: true)
    entries.append(next)
}
}

private struct ForwardEntryEditor: View {
    @Binding var entry: ForwardEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Toggle(isOn: $entry.isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.sourceDescription)
                            .font(.subheadline.bold())
                        Text("Protocol: \(entry.protocol)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)

                Spacer()

                VStack(alignment: .leading) {
                    Text("Remote Port")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if entry.isCustom {
                        TextField("80", value: $entry.remotePort, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    } else {
                        Text("\(entry.remotePort)")
                            .font(.body.monospaced())
                    }
                }

                VStack(alignment: .leading) {
                    Text("Local Port")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("8080", value: $entry.localPort, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ForwardEntry: Identifiable, Equatable {
    let id: UUID
    let sourceDescription: String
    var remotePort: Int
    var localPort: Int
    let `protocol`: String
    var isEnabled: Bool
    let isCustom: Bool

    static func entries(from detail: PodDetailData) -> [ForwardEntry] {
        var seen = Set<String>()
        var results: [ForwardEntry] = []

        for container in detail.containers {
            for descriptor in container.ports {
                guard let parsed = parsePortDescriptor(descriptor) else { continue }
                let key = "\(container.name)-\(parsed.port)-\(parsed.protocol)"
                if seen.insert(key).inserted {
                    let description: String
                    if let name = parsed.name {
                        description = "\(container.name) · \(name)"
                    } else {
                        description = "\(container.name)"
                    }
                    results.append(
                        ForwardEntry(
                            id: UUID(),
                            sourceDescription: description,
                            remotePort: parsed.port,
                            localPort: parsed.port,
                            protocol: parsed.protocol,
                            isEnabled: true,
                            isCustom: false
                        )
                    )
                }
            }
        }

        return results.sorted { $0.remotePort < $1.remotePort }
    }

    static func customDefault() -> ForwardEntry {
        ForwardEntry(
            id: UUID(),
            sourceDescription: "Custom",
            remotePort: 80,
            localPort: 8080,
            protocol: "TCP",
            isEnabled: true,
            isCustom: true
        )
    }

    private static func parsePortDescriptor(_ descriptor: String) -> (name: String?, port: Int, protocol: String)? {
        let components = descriptor.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
        let remainder: String
        let name: String?
        if components.count == 2 {
            name = String(components[0]).trimmingCharacters(in: .whitespaces)
            remainder = String(components[1]).trimmingCharacters(in: .whitespaces)
        } else {
            name = nil
            remainder = descriptor.trimmingCharacters(in: .whitespaces)
        }

        let portParts = remainder.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)
        guard let portString = portParts.first, let port = Int(portString.trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        let proto = portParts.count > 1 ? portParts[1].trimmingCharacters(in: .whitespaces).uppercased() : "TCP"
        return (name: name, port: port, protocol: proto)
    }
}

private extension Int {
    var isValidPort: Bool { (1...65535).contains(self) }
}

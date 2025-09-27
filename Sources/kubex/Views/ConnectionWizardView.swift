import SwiftUI
import UniformTypeIdentifiers

struct ConnectionWizardView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var kubeconfigPath: String = ""
    @State private var statusMessage: String?
    @State private var statusKind: StatusKind = .idle
    @State private var isValidating = false
    @State private var showingFileImporter = false

    private enum StatusKind {
        case idle
        case success
        case failure
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Cluster Connection Wizard")
                .font(.title3.bold())

            Text("Select a kubeconfig file to use with Kubex. The wizard validates the configuration by running \"kubectl config view\" before applying it.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Text("Kubeconfig Path")
                    .font(.headline)
                HStack {
                    TextField("/Users/you/.kube/config", text: $kubeconfigPath)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isValidating)
                    Button("Browse…") {
                        showingFileImporter = true
                    }
                    .disabled(isValidating)
                }
                HStack(spacing: 12) {
                    Button("Use Default (~/.kube/config)") {
                        kubeconfigPath = "~/.kube/config"
                    }
                    .disabled(isValidating)

                    Button("Clear") {
                        kubeconfigPath = ""
                    }
                    .disabled(isValidating)
                }
                .font(.footnote)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Active Sources")
                    .font(.headline)
                if model.kubeconfigSources.isEmpty {
                    Text("No kubeconfig sources added yet. Validate a path below to register it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(model.kubeconfigSources.enumerated()), id: \.offset) { index, path in
                            HStack(alignment: .firstTextBaseline) {
                                Text(path)
                                    .font(.callout.monospaced())
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button(role: .destructive) {
                                    Task { await model.removeKubeconfigSource(at: index) }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                        .labelStyle(.iconOnly)
                                }
                                .buttonStyle(.plain)
                                .disabled(isValidating)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.gray.opacity(0.15))
                            )
                        }
                    }
                }
            }

            if let statusMessage {
                HStack(spacing: 8) {
                    switch statusKind {
                    case .success:
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    case .failure:
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    case .idle:
                        Image(systemName: "info.circle.fill").foregroundStyle(.secondary)
                    }
                    Text(statusMessage)
                        .font(.callout)
                        .foregroundStyle(statusKind == .failure ? .primary : .secondary)
                }
                .transition(.opacity)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isValidating)
                Button(action: validateAndApply) {
                    if isValidating {
                        ProgressView()
                    } else {
                        Text("Validate & Add")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isValidating)
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 320)
        .onAppear {
            kubeconfigPath = ""
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                kubeconfigPath = url.path
            }
        }
    }

    private func validateAndApply() {
        isValidating = true
        statusMessage = nil
        statusKind = .idle

        let path = kubeconfigPath
        Task {
            let outcome = await model.applyKubeconfig(at: path.isEmpty ? nil : path)
            await MainActor.run {
                isValidating = false
                switch outcome {
                case .success:
                    statusKind = .success
                    statusMessage = "Kubeconfig source added successfully."
                    kubeconfigPath = ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        dismiss()
                    }
                case .failure(let error):
                    statusKind = .failure
                    statusMessage = error.message
                }
            }
        }
    }
}

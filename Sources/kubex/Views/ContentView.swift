import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isProcessingConnection = false
    @State private var showingConnectionWizard = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if let banner = model.banner {
                BannerView(message: banner)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Divider()
            ClusterDetail()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            await model.refreshClusters()
        }
        .animation(.easeInOut(duration: 0.2), value: model.banner?.id)
        .alert(item: $model.error) { error in
            Alert(
                title: Text("Unable to Refresh"),
                message: Text(error.localizedDescription),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showingConnectionWizard) {
            ConnectionWizardView()
                .environmentObject(model)
        }
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            Text("Kubex")
                .font(.headline)

            Spacer()

            if let namespace = model.selectedNamespace {
                Text("Namespace: \(namespace.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            clusterMenu

            Button("Connection Wizard") {
                showingConnectionWizard = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isProcessingConnection)

            Button(model.selectedCluster?.isConnected == true ? "Disconnect" : "Connect") {
                Task {
                    isProcessingConnection = true
                    if model.selectedCluster?.isConnected == true {
                        await model.disconnectCurrentCluster()
                    } else {
                        await model.connectSelectedCluster()
                    }
                    isProcessingConnection = false
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isProcessingConnection || model.selectedCluster == nil)

            if isProcessingConnection {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var clusterMenu: some View {
        Menu {
            if model.clusters.isEmpty {
                Button("No clusters found", action: {})
                    .disabled(true)
            } else {
                ForEach(model.clusters) { cluster in
                    Button(cluster.name) {
                        if model.selectedClusterID != cluster.id {
                            model.selectedClusterID = cluster.id
                            model.selectedResourceTab = .overview
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(model.selectedCluster?.name ?? "Select Cluster")
                    .font(.body)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
    }
}

private struct BannerView: View {
    let message: BannerMessage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: message.style.icon)
                .foregroundStyle(message.style.tint)
            Text(message.text)
                .foregroundStyle(.primary)
                .font(.callout)
            Spacer()
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(message.style.tint.opacity(0.3), lineWidth: 1)
        )
        .padding(.bottom, 4)
    }
}

private struct ClusterDetail: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if let cluster = model.selectedCluster {
            ClusterDetailView(cluster: cluster, namespace: model.selectedNamespace, selectedTab: $model.selectedResourceTab)
        } else {
            ContentUnavailableView(
                "Select a Cluster",
                systemImage: "shippingbox",
                description: Text("Choose a cluster to inspect resources, logs, and events.")
            )
        }
    }
}

import SwiftUI

struct LogStreamSheet: View {
    let cluster: Cluster
    let namespace: Namespace
    let pod: PodSummary
    let request: LogStreamRequest

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PodLogsPane(
            cluster: cluster,
            namespace: namespace,
            pod: pod,
            presentation: DetailPresentationStyle.sheet,
            onClose: { dismiss() },
            initialRequest: request
        )
        .environmentObject(model)
        .padding(20)
        .frame(minWidth: 700, minHeight: 380)
    }
}

import SwiftUI


struct NodesSection: View {
    let cluster: Cluster
    @Binding var sortOption: NodeSortOption
    var filterState: NodeFilterState
    let isNodeBusy: (NodeInfo) -> Bool
    let nodeActionError: (NodeInfo) -> NodeActionFeedback?
    let onShowDetails: (NodeInfo) -> Void
    let onShell: (NodeInfo) -> Void
    let onCordon: (NodeInfo) -> Void
    let onDrain: (NodeInfo) -> Void
    let onEdit: (NodeInfo) -> Void
    let onDelete: (NodeInfo) -> Void

    private var isConnected: Bool { cluster.isConnected }
    private var nodes: [NodeInfo] { cluster.nodes }
    private var filteredNodes: [NodeInfo] {
        cluster.nodes.filter { filterState.matches($0) }
    }
    private var sortedNodes: [NodeInfo] {
        filteredNodes.sorted(by: compareNodes)
    }

    var body: some View {
        if !cluster.isConnected {
            centeredUnavailableView(
                "Not Connected",
                systemImage: "bolt.slash",
                description: Text("Connect to the cluster to inspect nodes.")
            )
        } else if nodes.isEmpty, cluster.nodeSummary.total > 0 {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView()
                Text("Loading nodes…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if nodes.isEmpty {
            centeredUnavailableView(
                "No Nodes",
                systemImage: "cpu",
                description: Text("Nodes will appear here once the cluster finishes loading.")
            )
        } else if filteredNodes.isEmpty {
            centeredUnavailableView(
                "No Matching Nodes",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text("Adjust filters to see node results.")
            )
        } else {
            VStack(alignment: .leading, spacing: 16) {
                metricsSummary
                nodeTable
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }

    private var metricsSummary: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], alignment: .leading, spacing: 16) {
            summaryTile(label: "Total", value: "\(cluster.nodeSummary.total)")
            summaryTile(label: "Ready", value: "\(cluster.nodeSummary.ready)")
            summaryTile(label: "CPU", value: PercentageFormatter.format(cluster.nodeSummary.cpuUsage))
            summaryTile(label: "Memory", value: PercentageFormatter.format(cluster.nodeSummary.memoryUsage))
            if let diskAverage = cluster.nodeSummary.diskUsage {
                summaryTile(label: "Disk", value: PercentageFormatter.format(diskAverage))
            }
        }
        .padding(.horizontal, 4)
    }

    private var nodeTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            nodeHeader
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color(nsColor: .underPageBackgroundColor))
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sortedNodes) { node in
                        nodeRow(for: node)
                        Divider()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            .frame(minHeight: 220)
        }
    }

    private var nodeHeader: some View {
        HStack(spacing: 8) {
            sortableHeader(title: "Name", field: .name)
                .frame(width: Column.name, alignment: .leading)
            sortableHeader(title: "Warnings", field: .warnings)
                .frame(width: Column.warnings, alignment: .leading)
            sortableHeader(title: "CPU", field: .cpu)
                .frame(width: Column.cpu, alignment: .leading)
            sortableHeader(title: "Memory", field: .memory)
                .frame(width: Column.memory, alignment: .leading)
            sortableHeader(title: "Disk", field: .disk)
                .frame(width: Column.disk, alignment: .leading)
            Text("Taints")
                .frame(width: Column.taints, alignment: .leading)
            Text("Version")
                .frame(width: Column.version, alignment: .leading)
            sortableHeader(title: "Age", field: .age)
                .frame(width: Column.age, alignment: .leading)
            Text("Conditions")
                .frame(width: Column.conditions, alignment: .leading)
            Spacer(minLength: 0)
            Text("")
                .frame(width: Column.actions, alignment: .trailing)
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
    }

    private func nodeRow(for node: NodeInfo) -> some View {
        let busy = isNodeBusy(node)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(node.name)
                    .font(.body.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: Column.name, alignment: .leading)

                Group {
                    if node.warningCount > 0 {
                        Text("\(node.warningCount)")
                            .foregroundStyle(Color.orange)
                    } else {
                        Text("—")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: Column.warnings, alignment: .leading)

                Text(node.cpuDisplay)
                    .foregroundStyle(.secondary)
                    .frame(width: Column.cpu, alignment: .leading)

                Text(node.memoryDisplay)
                    .foregroundStyle(.secondary)
                    .frame(width: Column.memory, alignment: .leading)

                Text(node.diskDisplay)
                    .foregroundStyle(.secondary)
                    .frame(width: Column.disk, alignment: .leading)

                Text(node.taintSummary)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .frame(width: Column.taints, alignment: .leading)

                Text(node.kubeletVersion)
                    .foregroundStyle(.secondary)
                    .frame(width: Column.version, alignment: .leading)

                Text(node.age?.displayText ?? "—")
                    .foregroundStyle(.secondary)
                    .frame(width: Column.age, alignment: .leading)

                Text(node.conditionSummary)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .frame(width: Column.conditions, alignment: .leading)

                nodeActions(for: node, busy: busy)
                    .frame(width: Column.actions, alignment: .trailing)
            }

            if let feedback = nodeActionError(node) {
                NodeInlineErrorView(feedback: feedback)
                    .padding(.leading, 4)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .opacity(busy ? 0.6 : 1)
    }

    @ViewBuilder
    private func nodeActions(for node: NodeInfo, busy: Bool) -> some View {
        if busy {
            ProgressView()
                .controlSize(.small)
        } else {
            Menu {
                Button("Show Details") { onShowDetails(node) }
                Button("Shell") { onShell(node) }
                    .disabled(!isConnected)
                Divider()
                Button("Cordon") { onCordon(node) }
                    .disabled(!isConnected)
                Button("Drain") { onDrain(node) }
                    .disabled(!isConnected)
                Button("Edit") { onEdit(node) }
                    .disabled(!isConnected)
                Button(role: .destructive) { onDelete(node) } label: {
                    Text("Delete")
                }
                .disabled(!isConnected)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .padding(4)
            }
            .menuStyle(.borderlessButton)
        }
    }

    private func summaryTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func sortableHeader(title: String, field: NodeSortField) -> some View {
        Button {
            if sortOption.field == field {
                sortOption.toggleDirection()
            } else {
                sortOption = NodeSortOption(field: field, direction: .ascending)
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                if sortOption.field == field {
                    Image(systemName: sortOption.direction.symbolName)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private func compareNodes(_ lhs: NodeInfo, _ rhs: NodeInfo) -> Bool {
        let ascending = sortOption.direction == SortDirection.ascending
        switch sortOption.field {
        case .name:
            return compareNames(lhs, rhs, ascending: ascending)
        case .warnings:
            return compareNumeric(Double(lhs.warningCount), Double(rhs.warningCount), lhs: lhs, rhs: rhs, ascending: ascending)
        case .cpu:
            return compareNumeric(lhs.cpuUsageRatio, rhs.cpuUsageRatio, lhs: lhs, rhs: rhs, ascending: ascending)
        case .memory:
            return compareNumeric(lhs.memoryUsageRatio, rhs.memoryUsageRatio, lhs: lhs, rhs: rhs, ascending: ascending)
        case .disk:
            return compareNumeric(lhs.diskRatio, rhs.diskRatio, lhs: lhs, rhs: rhs, ascending: ascending)
        case .age:
            return compareNumeric(lhs.age?.totalMinutes, rhs.age?.totalMinutes, lhs: lhs, rhs: rhs, ascending: ascending)
        }
    }

    private func compareNumeric(_ lhsValue: Double?, _ rhsValue: Double?, lhs: NodeInfo, rhs: NodeInfo, ascending: Bool) -> Bool {
        let left = normalizedNumeric(lhsValue, ascending: ascending)
        let right = normalizedNumeric(rhsValue, ascending: ascending)
        if left == right {
            return compareNames(lhs, rhs, ascending: ascending)
        }
        return ascending ? left < right : left > right
    }

    private func normalizedNumeric(_ value: Double?, ascending: Bool) -> Double {
        guard let value else {
            return ascending ? Double.greatestFiniteMagnitude : -Double.greatestFiniteMagnitude
        }
        return value
    }

    private func compareNames(_ lhs: NodeInfo, _ rhs: NodeInfo, ascending: Bool) -> Bool {
        let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if comparison == .orderedSame {
            let lhsID = lhs.id.uuidString
            let rhsID = rhs.id.uuidString
            if ascending {
                return lhsID < rhsID
            } else {
                return lhsID > rhsID
            }
        }
        if ascending {
            return comparison == .orderedAscending
        } else {
            return comparison == .orderedDescending
        }
    }

    private enum Column {
        static let name: CGFloat = 220
        static let warnings: CGFloat = 80
        static let cpu: CGFloat = 140
        static let memory: CGFloat = 160
        static let disk: CGFloat = 120
        static let taints: CGFloat = 200
        static let version: CGFloat = 120
        static let age: CGFloat = 80
        static let conditions: CGFloat = 220
        static let actions: CGFloat = 60
    }
}

private struct NodeInlineErrorView: View {
    let feedback: NodeActionFeedback

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.orange)
            Text(feedback.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
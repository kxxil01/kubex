import SwiftUI

private struct PendingPodFocus: Equatable {
    let namespaceID: Namespace.ID
    let podID: PodSummary.ID
    let tabValue: String

    func resolvedTab() -> ClusterDetailView.PodInspectorTab {
        ClusterDetailView.PodInspectorTab(rawValue: tabValue) ?? .summary
    }
}
import Charts

struct ClusterDetailView: View {
    enum Tab: Hashable, Identifiable, CaseIterable {
        case overview
        case applications
        case nodes
        case workloadsOverview
        case workloadsPods
        case workloadsDeployments
        case workloadsDaemonSets
        case workloadsStatefulSets
        case workloadsReplicaSets
        case workloadsReplicationControllers
        case workloadsJobs
        case workloadsCronJobs
        case configConfigMaps
        case configSecrets
        case configResourceQuotas
        case configLimitRanges
        case configHPAs
        case configPodDisruptionBudgets
        case helmReleases
        case helmRepositories
        case networkServices
        case networkEndpoints
        case networkIngresses
        case networkPolicies
        case networkLoadBalancers
        case networkPortForwards
        case storagePersistentVolumeClaims
        case storagePersistentVolumes
        case storageStorageClasses
        case namespaces
        case events
        case accessControl
        case customResources

        var id: Self { self }

        var title: String {
            switch self {
            case .overview: return "Overview"
            case .applications: return "Applications"
            case .nodes: return "Nodes"
            case .workloadsOverview: return "Overview"
            case .workloadsPods: return "Pods"
            case .workloadsDeployments: return "Deployments"
            case .workloadsDaemonSets: return "Daemon Sets"
            case .workloadsStatefulSets: return "Stateful Sets"
            case .workloadsReplicaSets: return "Replica Sets"
            case .workloadsReplicationControllers: return "Replication Controllers"
            case .workloadsJobs: return "Jobs"
            case .workloadsCronJobs: return "Cron Jobs"
            case .configConfigMaps: return "ConfigMaps"
            case .configSecrets: return "Secrets"
            case .configResourceQuotas: return "Resource Quotas"
            case .configLimitRanges: return "Limit Ranges"
            case .configHPAs: return "HPAs"
            case .configPodDisruptionBudgets: return "Pod Disruption Budgets"
            case .helmReleases: return "Helm Releases"
            case .helmRepositories: return "Helm Repositories"
            case .networkServices: return "Services"
            case .networkEndpoints: return "Endpoints"
            case .networkIngresses: return "Ingresses"
            case .networkPolicies: return "Network Policies"
            case .networkLoadBalancers: return "Load Balancers"
            case .networkPortForwards: return "Port Forwards"
            case .storagePersistentVolumeClaims: return "Persistent Volume Claims"
            case .storagePersistentVolumes: return "Persistent Volumes"
            case .storageStorageClasses: return "Storage Classes"
            case .namespaces: return "Namespaces"
            case .events: return "Events"
            case .accessControl: return "Access Control"
            case .customResources: return "Custom Resources"
            }
        }

        var icon: String {
            switch self {
            case .overview: return "rectangle.and.text.magnifyingglass"
            case .applications: return "app.connected.to.app.below.fill"
            case .nodes: return "cpu"
            case .workloadsOverview: return "shippingbox"
            case .workloadsPods: return "circle.grid.3x3.fill"
            case .workloadsDeployments: return "shippingbox.and.arrow.backward"
            case .workloadsDaemonSets: return "bolt.horizontal.circle"
            case .workloadsStatefulSets: return "cube.transparent"
            case .workloadsReplicaSets: return "rectangle.grid.2x2"
            case .workloadsReplicationControllers: return "wand.and.stars"
            case .workloadsJobs: return "clock.arrow.circlepath"
            case .workloadsCronJobs: return "calendar"
            case .configConfigMaps: return "doc.text"
            case .configSecrets: return "lock"
            case .configResourceQuotas: return "dial.medium"
            case .configLimitRanges: return "speedometer"
            case .configHPAs: return "gauge"
            case .configPodDisruptionBudgets: return "shield"
            case .helmReleases: return "shippingbox"
            case .helmRepositories: return "shippingbox.and.arrow.up"
            case .networkServices: return "switch.2"
            case .networkEndpoints: return "point.3.filled.connected.trianglepath.dotted"
            case .networkIngresses: return "cloud"
            case .networkPolicies: return "shield.lefthalf.fill"
            case .networkLoadBalancers: return "server.rack"
            case .networkPortForwards: return "bolt.horizontal"
            case .storagePersistentVolumeClaims: return "externaldrive"
            case .storagePersistentVolumes: return "externaldrive.connected.to.line.below"
            case .storageStorageClasses: return "internaldrive"
            case .namespaces: return "square.stack.3d.up.fill"
            case .events: return "bell"
            case .accessControl: return "lock.shield"
            case .customResources: return "puzzlepiece.extension"
            }
        }

        static let workloadTabs: [Tab] = [
            .workloadsOverview,
            .workloadsPods,
            .workloadsDeployments,
            .workloadsDaemonSets,
            .workloadsStatefulSets,
            .workloadsReplicaSets,
            .workloadsReplicationControllers,
            .workloadsJobs,
            .workloadsCronJobs
        ]

        var requiresConnection: Bool {
            switch self {
            case .overview:
                return false
            default:
                return true
            }
        }

        var usesResourceList: Bool {
            switch self {
            case .applications,
                 .workloadsOverview,
                 .workloadsPods,
                 .workloadsDeployments,
                 .workloadsDaemonSets,
                 .workloadsStatefulSets,
                 .workloadsReplicaSets,
                 .workloadsReplicationControllers,
                 .workloadsJobs,
                 .workloadsCronJobs,
                 .configConfigMaps,
                 .configSecrets,
                 .configResourceQuotas,
                 .configLimitRanges,
                 .configHPAs,
                 .configPodDisruptionBudgets,
                 .helmReleases,
                 .helmRepositories,
                 .networkServices,
                 .networkEndpoints,
                 .networkIngresses,
                 .networkPolicies,
                 .networkLoadBalancers,
                 .networkPortForwards,
                 .storagePersistentVolumeClaims,
                 .storagePersistentVolumes,
                 .storageStorageClasses:
                return true
            default:
                return false
            }
        }

        var isWorkload: Bool {
            Self.workloadTabs.contains(self)
        }

        var isPodFocused: Bool {
            self == .workloadsPods
        }

        var isConfigResource: Bool {
            switch self {
            case .configConfigMaps,
                 .configSecrets,
                 .configResourceQuotas,
                 .configLimitRanges,
                 .configHPAs,
                 .configPodDisruptionBudgets:
                return true
            default:
                return false
            }
        }

        var workloadMenuTitle: String {
            switch self {
            case .workloadsOverview: return "Overview"
            case .workloadsPods: return "Pods"
            case .workloadsDeployments: return "Deployments"
            case .workloadsDaemonSets: return "Daemon Sets"
            case .workloadsStatefulSets: return "Stateful Sets"
            case .workloadsReplicaSets: return "Replica Sets"
            case .workloadsReplicationControllers: return "Replication Controllers"
            case .workloadsJobs: return "Jobs"
            case .workloadsCronJobs: return "Cron Jobs"
            default: return title
            }
        }

        var primaryCategory: ResourceCategory {
            if isWorkload {
                return .workloads
            }
            switch self {
            case .overview: return .overview
            case .applications: return .applications
            case .nodes: return .nodes
            case .configConfigMaps,
                 .configSecrets,
                 .configResourceQuotas,
                 .configLimitRanges,
                 .configHPAs,
                 .configPodDisruptionBudgets:
                return .config
            case .helmReleases,
                 .helmRepositories:
                return .helm
            case .networkServices,
                 .networkEndpoints,
                 .networkIngresses,
                 .networkPolicies,
                 .networkLoadBalancers,
                 .networkPortForwards:
                return .network
            case .storagePersistentVolumeClaims,
                 .storagePersistentVolumes,
                 .storageStorageClasses:
                return .storage
            case .namespaces: return .namespaces
            case .events: return .events
            case .accessControl: return .accessControl
            case .customResources: return .customResources
            default: return .overview
            }
        }

        static func tab(for category: ResourceCategory) -> Tab {
            switch category {
            case .overview: return .overview
            case .applications: return .applications
            case .nodes: return .nodes
            case .config: return .configConfigMaps
            case .helm: return .helmReleases
            case .network: return .networkServices
            case .storage: return .storagePersistentVolumeClaims
            case .namespaces: return .namespaces
            case .events: return .events
            case .accessControl: return .accessControl
            case .customResources: return .customResources
            case .workloads: return .workloadsOverview
            }
        }

        var preferenceValue: String {
            switch self {
            case .overview: return "overview"
            case .applications: return "applications"
            case .nodes: return "nodes"
            case .workloadsOverview: return "workloads_overview"
            case .workloadsPods: return "workloads_pods"
            case .workloadsDeployments: return "workloads_deployments"
            case .workloadsDaemonSets: return "workloads_daemonsets"
            case .workloadsStatefulSets: return "workloads_statefulsets"
            case .workloadsReplicaSets: return "workloads_replicasets"
            case .workloadsReplicationControllers: return "workloads_replicationcontrollers"
            case .workloadsJobs: return "workloads_jobs"
            case .workloadsCronJobs: return "workloads_cronjobs"
            case .configConfigMaps: return "config_configmaps"
            case .configSecrets: return "config_secrets"
            case .configResourceQuotas: return "config_resourcequotas"
            case .configLimitRanges: return "config_limitranges"
            case .configHPAs: return "config_hpas"
            case .configPodDisruptionBudgets: return "config_pdbs"
            case .helmReleases: return "helm_releases"
            case .helmRepositories: return "helm_repositories"
            case .networkServices: return "network_services"
            case .networkEndpoints: return "network_endpoints"
            case .networkIngresses: return "network_ingresses"
            case .networkPolicies: return "network_policies"
            case .networkLoadBalancers: return "network_loadbalancers"
            case .networkPortForwards: return "network_portforwards"
            case .storagePersistentVolumeClaims: return "storage_pvcs"
            case .storagePersistentVolumes: return "storage_pvs"
            case .storageStorageClasses: return "storage_storageclasses"
            case .namespaces: return "namespaces"
            case .events: return "events"
            case .accessControl: return "access_control"
            case .customResources: return "custom_resources"
            }
        }

        init?(preferenceValue: String) {
            switch preferenceValue {
            case "overview": self = .overview
            case "applications": self = .applications
            case "nodes": self = .nodes
            case "workloads_overview": self = .workloadsOverview
            case "workloads_pods": self = .workloadsPods
            case "workloads_deployments": self = .workloadsDeployments
            case "workloads_daemonsets": self = .workloadsDaemonSets
            case "workloads_statefulsets": self = .workloadsStatefulSets
            case "workloads_replicasets": self = .workloadsReplicaSets
            case "workloads_replicationcontrollers": self = .workloadsReplicationControllers
            case "workloads_jobs": self = .workloadsJobs
            case "workloads_cronjobs": self = .workloadsCronJobs
            case "config_configmaps": self = .configConfigMaps
            case "config_secrets": self = .configSecrets
            case "config_resourcequotas": self = .configResourceQuotas
            case "config_limitranges": self = .configLimitRanges
            case "config_hpas": self = .configHPAs
            case "config_pdbs": self = .configPodDisruptionBudgets
            case "helm_releases": self = .helmReleases
            case "helm_repositories": self = .helmRepositories
            case "network_services": self = .networkServices
            case "network_endpoints": self = .networkEndpoints
            case "network_ingresses": self = .networkIngresses
            case "network_policies": self = .networkPolicies
            case "network_loadbalancers": self = .networkLoadBalancers
            case "network_portforwards": self = .networkPortForwards
            case "storage": self = .storagePersistentVolumeClaims
            case "storage_pvcs": self = .storagePersistentVolumeClaims
            case "storage_pvs": self = .storagePersistentVolumes
            case "storage_storageclasses": self = .storageStorageClasses
            case "namespaces": self = .namespaces
            case "events": self = .events
            case "access_control": self = .accessControl
            case "custom_resources": self = .customResources
            default: return nil
            }
        }
    }

    enum ResourceCategory: String, CaseIterable, Identifiable {
        case overview
        case nodes
        case applications
        case workloads
        case config
        case helm
        case network
        case storage
        case namespaces
        case events
        case accessControl
        case customResources

        var id: String { rawValue }

        static let navigationOrder: [ResourceCategory] = [
            .overview,
            .nodes,
            .applications,
            .workloads,
            .config,
            .network,
            .storage,
            .namespaces,
            .events,
            .helm,
            .accessControl,
            .customResources
        ]

        var menuTitle: String {
            switch self {
            case .overview: return "Overview"
            case .applications: return "Applications"
            case .nodes: return "Nodes"
            case .workloads: return "Workloads"
            case .config: return "Config"
            case .helm: return "Helm"
            case .network: return "Network"
            case .storage: return "Storage"
            case .namespaces: return "Namespaces"
            case .events: return "Events"
            case .accessControl: return "Access Control"
            case .customResources: return "Custom Resources"
            }
        }

        var systemImage: String? {
            switch self {
            case .overview: return "rectangle.and.text.magnifyingglass"
            case .applications: return "app.connected.to.app.below.fill"
            case .nodes: return "cpu"
            case .workloads: return "shippingbox"
            case .config: return "gearshape.2"
            case .helm: return "shippingbox.circle"
            case .network: return "point.3.connected.trianglepath.dotted"
            case .storage: return "externaldrive.stack"
            case .namespaces: return "square.stack.3d.up.fill"
            case .events: return "bell"
            case .accessControl: return "lock.shield"
            case .customResources: return "puzzlepiece.extension"
            }
        }

        var tabs: [ClusterDetailView.Tab] {
            switch self {
            case .overview: return [.overview]
            case .applications: return [.applications]
            case .nodes: return [.nodes]
            case .workloads: return Tab.workloadTabs
            case .config:
                return [
                    .configConfigMaps,
                    .configSecrets,
                    .configResourceQuotas,
                    .configLimitRanges,
                    .configHPAs,
                    .configPodDisruptionBudgets
                ]
            case .helm:
                return [
                    .helmReleases,
                    .helmRepositories
                ]
            case .network:
                return [
                    .networkServices,
                    .networkEndpoints,
                    .networkIngresses,
                    .networkPolicies,
                    .networkLoadBalancers,
                    .networkPortForwards
                ]
            case .storage:
                return [
                    .storagePersistentVolumeClaims,
                    .storagePersistentVolumes,
                    .storageStorageClasses
                ]
            case .namespaces: return [.namespaces]
            case .events: return [.events]
            case .accessControl: return [.accessControl]
            case .customResources: return [.customResources]
            }
        }
    }

    enum NetworkResourceKind: String, CaseIterable, Identifiable {
        case services
        case endpoints
        case ingresses
        case networkPolicies
        case loadBalancers
        case portForwards

        var id: String { rawValue }

        var title: String {
            switch self {
            case .services: return "Services"
            case .endpoints: return "Endpoints"
            case .ingresses: return "Ingresses"
            case .networkPolicies: return "Network Policies"
            case .loadBalancers: return "Load Balancers"
            case .portForwards: return "Port Forwards"
            }
        }

        var systemImage: String {
            switch self {
            case .services: return "switch.2"
            case .endpoints: return "point.3.filled.connected.trianglepath.dotted"
            case .ingresses: return "cloud"
            case .networkPolicies: return "shield.lefthalf.fill"
            case .loadBalancers: return "server.rack"
            case .portForwards: return "bolt.horizontal"
            }
        }
    }

    let cluster: Cluster
    let namespace: Namespace?

    @EnvironmentObject private var model: AppModel

    private static let annotationFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    @Binding var selectedTab: Tab
    @State private var selectedPodID: PodSummary.ID?
    @State private var selectedPodIDs: Set<PodSummary.ID> = []
    @State private var showingPortForward = false
    @State private var isProcessingConnection = false
    @State private var detailNode: NodeInfo?
    @State private var resourceSearchText: String = ""
    @State private var selectedWorkloadIDs: Set<WorkloadSummary.ID> = []
    @State private var selectedServiceIDs: Set<ServiceSummary.ID> = []
    @State private var selectedIngressIDs: Set<IngressSummary.ID> = []
    @State private var selectedPVCIDs: Set<PersistentVolumeClaimSummary.ID> = []
    @State private var selectedHelmIDs: Set<HelmRelease.ID> = []
    @State private var expandedCategories: Set<ResourceCategory> = []
    @State private var podInspectorTab: PodInspectorTab = .summary
    @State private var workloadInspectorTab: WorkloadInspectorTab = .summary
    @State private var inspectorWidth: CGFloat = 360
    @State private var inspectorDragBaseline: CGFloat?
    @State private var pendingQuickSearchTarget: AppModel.QuickSearchTarget?
    @State private var pendingPodFocus: PendingPodFocus?

    private var isConnected: Bool { cluster.isConnected }
    private let inspectorMinimumWidth: CGFloat = 320
    private let inspectorMaximumWidth: CGFloat = 600

    private var currentNetworkFocus: NetworkResourceKind? {
        switch selectedTab {
        case .networkServices: return .services
        case .networkEndpoints: return .endpoints
        case .networkIngresses: return .ingresses
        case .networkPolicies: return .networkPolicies
        case .networkLoadBalancers: return .loadBalancers
        case .networkPortForwards: return .portForwards
        default: return nil
        }
    }

    private var nodeSortBinding: Binding<NodeSortOption> {
        Binding(
            get: { model.nodeSortOption },
            set: { model.nodeSortOption = $0 }
        )
    }

    private var inspectorSelectionForCluster: AppModel.InspectorSelection {
        switch model.inspectorSelection {
        case let .workload(clusterID, namespaceID, workloadID) where clusterID == cluster.id:
            return .workload(clusterID: clusterID, namespaceID: namespaceID, workloadID: workloadID)
        case let .pod(clusterID, namespaceID, podID) where clusterID == cluster.id:
            return .pod(clusterID: clusterID, namespaceID: namespaceID, podID: podID)
        case let .helm(clusterID, releaseID) where clusterID == cluster.id:
            return .helm(clusterID: clusterID, releaseID: releaseID)
        case let .service(clusterID, namespaceID, serviceID) where clusterID == cluster.id:
            return .service(clusterID: clusterID, namespaceID: namespaceID, serviceID: serviceID)
        case let .ingress(clusterID, namespaceID, ingressID) where clusterID == cluster.id:
            return .ingress(clusterID: clusterID, namespaceID: namespaceID, ingressID: ingressID)
        case let .persistentVolumeClaim(clusterID, namespaceID, claimID) where clusterID == cluster.id:
            return .persistentVolumeClaim(clusterID: clusterID, namespaceID: namespaceID, claimID: claimID)
        default:
            return .none
        }
    }

    private var isWorkloadListTab: Bool {
        switch selectedTab {
        case .applications,
             .workloadsOverview,
             .workloadsDeployments,
             .workloadsDaemonSets,
             .workloadsStatefulSets,
             .workloadsReplicaSets,
             .workloadsReplicationControllers,
             .workloadsJobs,
             .workloadsCronJobs:
            return true
        default:
            return false
        }
    }

    private var selectedPod: PodSummary? {
        guard let namespace, let selectedPodID else { return nil }
        return namespace.pods.first(where: { $0.id == selectedPodID })
    }

    private var inspectorBottomInset: CGFloat { 0 }

    private var workloadQuickSearchFocusID: WorkloadSummary.ID? {
        guard let target = pendingQuickSearchTarget else { return nil }
        if case let .workload(_, _, workloadID) = target {
            return workloadID
        }
        return nil
    }

    private var podQuickSearchFocusID: PodSummary.ID? {
        guard let target = pendingQuickSearchTarget else { return nil }
        if case let .pod(_, podID) = target {
            return podID
        }
        return nil
    }

    private var workloadLabelSelectors: [LabelSelector] {
        guard let namespace, cluster.isConnected else { return [] }
        return selectorList(from: namespace.workloads.map { $0.labels })
    }

    private var podLabelSelectors: [LabelSelector] {
        guard let namespace, cluster.isConnected else { return [] }
        return selectorList(from: namespace.pods.map { $0.labels })
    }

    private var nodeLabelSelectors: [LabelSelector] {
        selectorList(from: cluster.nodes.map { $0.labels })
    }

    private var configLabelSelectors: [LabelSelector] {
        guard let namespace, cluster.isConnected else { return [] }
        return selectorList(from: namespace.configResources.map { $0.labels })
    }

    private var availableConfigKinds: [ConfigResourceKind] {
        guard let namespace else { return [] }
        let kinds = Set(namespace.configResources.map { $0.kind })
        return ConfigResourceKind.allCases.filter { kinds.contains($0) }
    }

    private func selectorList(from labelMaps: [[String: String]], limit: Int = 14) -> [LabelSelector] {
        var seen: Set<String> = []
        var selectors: [LabelSelector] = []
        for map in labelMaps {
            for (key, value) in map {
                guard !key.isEmpty else { continue }
                let selector = LabelSelector(key: key, value: value)
                let identifier = selector.id
                if seen.insert(identifier).inserted {
                    selectors.append(selector)
                }
            }
        }
        selectors.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        if selectors.count > limit {
            return Array(selectors.prefix(limit))
        }
        return selectors
    }

    private func toggleWorkloadStatus(_ status: WorkloadStatus) {
        var state = model.workloadFilterState
        if state.statuses.contains(status) {
            state.statuses.remove(status)
        } else {
            state.statuses.insert(status)
        }
        model.workloadFilterState = state
    }

    private func toggleWorkloadLabel(_ selector: LabelSelector) {
        var state = model.workloadFilterState
        if state.labelSelectors.contains(selector) {
            state.labelSelectors.remove(selector)
        } else {
            state.labelSelectors.insert(selector)
        }
        model.workloadFilterState = state
    }

    private func clearWorkloadFilters() {
        model.workloadFilterState = .empty
    }

    private func togglePodPhase(_ phase: PodPhase) {
        var state = model.podFilterState
        if state.phases.contains(phase) {
            state.phases.remove(phase)
        } else {
            state.phases.insert(phase)
        }
        model.podFilterState = state
    }

    private func togglePodWarnings() {
        var state = model.podFilterState
        state.onlyWithWarnings.toggle()
        model.podFilterState = state
    }

    private func togglePodLabel(_ selector: LabelSelector) {
        var state = model.podFilterState
        if state.labelSelectors.contains(selector) {
            state.labelSelectors.remove(selector)
        } else {
            state.labelSelectors.insert(selector)
        }
        model.podFilterState = state
    }

    private func clearPodFilters() {
        model.podFilterState = .empty
    }

    private func toggleNodeReady() {
        var state = model.nodeFilterState
        state.onlyReady.toggle()
        model.nodeFilterState = state
    }

    private func toggleNodeWarnings() {
        var state = model.nodeFilterState
        state.onlyWithWarnings.toggle()
        model.nodeFilterState = state
    }

    private func toggleNodeLabel(_ selector: LabelSelector) {
        var state = model.nodeFilterState
        if state.labelSelectors.contains(selector) {
            state.labelSelectors.remove(selector)
        } else {
            state.labelSelectors.insert(selector)
        }
        model.nodeFilterState = state
    }

    private func clearNodeFilters() {
        model.nodeFilterState = .empty
    }

    private func toggleConfigKind(_ kind: ConfigResourceKind) {
        var state = model.configFilterState
        if state.kinds.contains(kind) {
            state.kinds.remove(kind)
        } else {
            state.kinds.insert(kind)
        }
        model.configFilterState = state
    }

    private func toggleConfigLabel(_ selector: LabelSelector) {
        var state = model.configFilterState
        if state.labelSelectors.contains(selector) {
            state.labelSelectors.remove(selector)
        } else {
            state.labelSelectors.insert(selector)
        }
        model.configFilterState = state
    }

    private func clearConfigFilters() {
        model.configFilterState = .empty
    }

    @ViewBuilder
    private var filterControls: some View {
        if isWorkloadListTab {
            workloadFilterBar
        } else if selectedTab == .workloadsPods {
            podFilterBar
        } else if selectedTab == .nodes {
            nodeFilterBar
        } else if selectedTab.isConfigResource {
            configFilterBar
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var workloadFilterBar: some View {
        if cluster.isConnected, namespace != nil {
            let filter = model.workloadFilterState
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Status")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ForEach(WorkloadStatus.allCases, id: \.self) { status in
                        FilterChip(
                            title: status.displayName,
                            isSelected: filter.statuses.contains(status),
                            tint: status.tint
                        ) {
                            toggleWorkloadStatus(status)
                        }
                    }
                    if !filter.isEmpty {
                        Button("Reset") { clearWorkloadFilters() }
                            .buttonStyle(.borderless)
                            .font(.caption)
                    }
                }

                let labels = workloadLabelSelectors
                if !labels.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            Text("Labels")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            ForEach(labels) { selector in
                                FilterChip(
                                    title: selector.displayName,
                                    isSelected: filter.labelSelectors.contains(selector)
                                ) {
                                    toggleWorkloadLabel(selector)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .transition(.opacity)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var podFilterBar: some View {
        if cluster.isConnected, namespace != nil {
            let filter = model.podFilterState
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Phase")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ForEach(PodPhase.allCases, id: \.self) { phase in
                        FilterChip(
                            title: phase.displayName,
                            isSelected: filter.phases.contains(phase),
                            tint: phase.tint
                        ) {
                            togglePodPhase(phase)
                        }
                    }
                    FilterChip(
                        title: "Warnings",
                        isSelected: filter.onlyWithWarnings,
                        systemImage: "exclamationmark.triangle"
                    ) {
                        togglePodWarnings()
                    }
                    if !filter.isEmpty {
                        Button("Reset") { clearPodFilters() }
                            .buttonStyle(.borderless)
                            .font(.caption)
                    }
                }

                let labels = podLabelSelectors
                if !labels.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            Text("Labels")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            ForEach(labels) { selector in
                                FilterChip(
                                    title: selector.displayName,
                                    isSelected: filter.labelSelectors.contains(selector)
                                ) {
                                    togglePodLabel(selector)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .transition(.opacity)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var nodeFilterBar: some View {
        if cluster.isConnected {
            let filter = model.nodeFilterState
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Filters")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    FilterChip(
                        title: "Ready",
                        isSelected: filter.onlyReady,
                        systemImage: "checkmark.circle"
                    ) {
                        toggleNodeReady()
                    }
                    FilterChip(
                        title: "Warnings",
                        isSelected: filter.onlyWithWarnings,
                        systemImage: "exclamationmark.triangle"
                    ) {
                        toggleNodeWarnings()
                    }
                    if !filter.isEmpty {
                        Button("Reset") { clearNodeFilters() }
                            .buttonStyle(.borderless)
                            .font(.caption)
                    }
                }

                let labels = nodeLabelSelectors
                if !labels.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            Text("Labels")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            ForEach(labels) { selector in
                                FilterChip(
                                    title: selector.displayName,
                                    isSelected: filter.labelSelectors.contains(selector)
                                ) {
                                    toggleNodeLabel(selector)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var configFilterBar: some View {
        if cluster.isConnected, namespace != nil {
                let filter = model.configFilterState
            VStack(alignment: .leading, spacing: 6) {
                let kinds = availableConfigKinds
                if !kinds.isEmpty && !selectedTab.isConfigResource {
                    HStack(spacing: 6) {
                        Text("Type")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        ForEach(kinds, id: \.self) { kind in
                            FilterChip(
                                title: kind.displayName,
                                isSelected: filter.kinds.contains(kind)
                            ) {
                                toggleConfigKind(kind)
                            }
                        }
                        if !filter.isEmpty {
                            Button("Reset") { clearConfigFilters() }
                                .buttonStyle(.borderless)
                                .font(.caption)
                        }
                    }
                }

                let labels = configLabelSelectors
                if !labels.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            Text("Labels")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            ForEach(labels) { selector in
                                FilterChip(
                                    title: selector.displayName,
                                    isSelected: filter.labelSelectors.contains(selector)
                                ) {
                                    toggleConfigLabel(selector)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .transition(.opacity)
        } else {
            EmptyView()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ClusterHeaderView(cluster: cluster)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 12)

            Divider()

            HStack(spacing: 0) {
                NavigationSidebar(
                    selectedTab: $selectedTab,
                    expandedCategories: $expandedCategories,
                    isConnected: isConnected
                )
                    .frame(width: 200)

                Divider()

                mainContentArea
            }
        }
        .frame(minWidth: 960, minHeight: 560)
        .onChange(of: namespace?.id) { _, _ in
            selectedPodID = nil
            selectedPodIDs.removeAll()
            selectedWorkloadIDs.removeAll()
            selectedServiceIDs.removeAll()
            selectedIngressIDs.removeAll()
            selectedPVCIDs.removeAll()
            selectedHelmIDs.removeAll()
            if pendingPodFocus == nil {
                syncInspectorSelection()
            }
            applyPendingPodFocusIfPossible()
        }
        .onChange(of: selectedPodID) { _, newValue in
            if newValue == nil {
                showingPortForward = false
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            expandedCategories.insert(newValue.primaryCategory)
            if !newValue.isPodFocused {
                selectedPodID = nil
                selectedPodIDs.removeAll()
                showingPortForward = false
            }
            if newValue.usesResourceList {
                resourceSearchText = ""
                selectedWorkloadIDs.removeAll()
                selectedServiceIDs.removeAll()
                selectedIngressIDs.removeAll()
                selectedPVCIDs.removeAll()
                selectedHelmIDs.removeAll()
            }
            if newValue != .workloadsPods {
                podInspectorTab = .summary
            }
            if !newValue.isWorkload {
                workloadInspectorTab = .summary
            }
            syncInspectorSelection()
        }
        .onAppear {
            expandedCategories.insert(selectedTab.primaryCategory)
        }
        .onChange(of: selectedPodIDs) { _, newValue in
            if let current = selectedPodID, newValue.contains(current) {
                return
            }
            selectedPodID = newValue.first
            syncInspectorSelection()
        }
        .onChange(of: selectedWorkloadIDs) { _, _ in
            syncInspectorSelection()
        }
        .onChange(of: selectedHelmIDs) { _, _ in
            syncInspectorSelection()
        }
        .onChange(of: selectedServiceIDs) { _, _ in
            syncInspectorSelection()
        }
        .onChange(of: selectedIngressIDs) { _, _ in
            syncInspectorSelection()
        }
        .onChange(of: selectedPVCIDs) { _, _ in
            syncInspectorSelection()
        }
        .onChange(of: namespace?.workloads) { _, _ in
            syncInspectorSelection()
        }
        .onChange(of: namespace?.pods) { _, _ in
            applyPendingPodFocusIfPossible()
            syncInspectorSelection()
        }
        .onChange(of: model.quickSearchFocus) { _, selection in
            guard let selection, selection.clusterID == cluster.id else { return }
            applyQuickSearchSelection(selection.target)
            model.consumeQuickSearchFocus()
        }
        .sheet(isPresented: $showingPortForward) {
            if let namespace, let pod = selectedPod {
                PortForwardSheet(cluster: cluster, namespace: namespace, pod: pod)
                    .environmentObject(model)
            } else {
                Text("Select a pod to port-forward.")
                    .padding()
            }
        }
        .sheet(item: $detailNode) { node in
            NodeDetailSheetView(node: node)
        }
        .task(id: namespace?.id) {
            if let namespace, !namespace.isLoaded {
                await model.loadNamespaceIfNeeded(clusterID: cluster.id, namespaceName: namespace.name)
            }
            syncInspectorSelection()
        }
    }

    @ViewBuilder
    private var mainContentArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            namespaceToolbar
            Divider()
            if selectedTab.usesResourceList {
                resourceListLayout
            } else {
                legacyScrollLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var legacyScrollLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                resourceContent
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var resourceListLayout: some View {
        let hasInspector = cluster.isConnected && inspectorSelectionForCluster != .none
        HStack(alignment: .top, spacing: hasInspector ? 16 : 0) {
            VStack(spacing: 0) {
                resourceListToolbar
                Divider()
                resourceListBody
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if hasInspector {
                inspectorDock
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.trailing, hasInspector ? 24 : 0)
        .padding(.bottom, hasInspector ? 24 : 0)
    }

    private var resourceListToolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                TextField("Filter resources", text: $resourceSearchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)

                if selectedTab == .nodes {
                    nodeSortMenu
                }

                if isWorkloadListTab {
                    workloadSortMenu
                }

                Spacer()

                if selectedTab == .helmReleases {
                    if model.helmLoadingContexts.contains(cluster.contextName) {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Button {
                        Task { await model.reloadHelmReleases(for: cluster) }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(!cluster.isConnected || model.helmLoadingContexts.contains(cluster.contextName))
                }
            }

            filterControls
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var nodeSortMenu: some View {
        Menu {
            Button(action: { model.nodeSortOption.toggleDirection() }) {
                Label(model.nodeSortOption.direction.toggleLabel, systemImage: model.nodeSortOption.direction.symbolName)
            }
            Divider()
            ForEach(NodeSortField.allCases) { field in
                Button(action: { selectNodeSort(field: field) }) {
                    if model.nodeSortOption.field == field {
                        Label(field.title, systemImage: "checkmark")
                    } else {
                        Text(field.title)
                    }
                }
            }
        } label: {
            Label("Sort \(model.nodeSortOption.description)", systemImage: "arrow.up.arrow.down")
        }
        .menuStyle(.borderlessButton)
    }

    private var workloadSortMenu: some View {
        Menu {
            Button(action: { model.workloadSortOption.toggleDirection() }) {
                Label(model.workloadSortOption.direction.toggleLabel, systemImage: model.workloadSortOption.direction.symbolName)
            }
            Divider()
            ForEach(WorkloadSortField.allCases) { field in
                Button(action: { selectWorkloadSort(field: field) }) {
                    if model.workloadSortOption.field == field {
                        Label(field.title, systemImage: "checkmark")
                    } else {
                        Text(field.title)
                    }
                }
            }
        } label: {
            Label("Sort \(model.workloadSortOption.description)", systemImage: "arrow.up.arrow.down")
        }
        .menuStyle(.borderlessButton)
    }

    @ViewBuilder
    private var resourceListBody: some View {
        switch selectedTab {
        case .applications, .workloadsOverview:
            WorkloadListView(
                namespace: namespace,
                isConnected: isConnected,
                kind: nil,
                showsKindColumn: true,
                searchText: resourceSearchText,
                sortOption: model.workloadSortOption,
                filter: model.workloadFilterState,
                focusID: workloadQuickSearchFocusID,
                selection: $selectedWorkloadIDs,
                onInspect: { handleWorkloadSelection($0) },
                onFocusPods: { focusPods(for: $0) }
            )
        case .workloadsDeployments:
            WorkloadListView(
                namespace: namespace,
                isConnected: isConnected,
                kind: .deployment,
                showsKindColumn: false,
                searchText: resourceSearchText,
                sortOption: model.workloadSortOption,
                filter: model.workloadFilterState,
                focusID: workloadQuickSearchFocusID,
                selection: $selectedWorkloadIDs,
                onInspect: { handleWorkloadSelection($0) },
                onFocusPods: { focusPods(for: $0) }
            )
        case .workloadsDaemonSets:
            WorkloadListView(
                namespace: namespace,
                isConnected: isConnected,
                kind: .daemonSet,
                showsKindColumn: false,
                searchText: resourceSearchText,
                sortOption: model.workloadSortOption,
                filter: model.workloadFilterState,
                focusID: workloadQuickSearchFocusID,
                selection: $selectedWorkloadIDs,
                onInspect: { handleWorkloadSelection($0) },
                onFocusPods: { focusPods(for: $0) }
            )
        case .workloadsStatefulSets:
            WorkloadListView(
                namespace: namespace,
                isConnected: isConnected,
                kind: .statefulSet,
                showsKindColumn: false,
                searchText: resourceSearchText,
                sortOption: model.workloadSortOption,
                filter: model.workloadFilterState,
                focusID: workloadQuickSearchFocusID,
                selection: $selectedWorkloadIDs,
                onInspect: { handleWorkloadSelection($0) },
                onFocusPods: { focusPods(for: $0) }
            )
        case .workloadsReplicaSets:
            WorkloadListView(
                namespace: namespace,
                isConnected: isConnected,
                kind: .replicaSet,
                showsKindColumn: false,
                searchText: resourceSearchText,
                sortOption: model.workloadSortOption,
                filter: model.workloadFilterState,
                focusID: workloadQuickSearchFocusID,
                selection: $selectedWorkloadIDs,
                onInspect: { handleWorkloadSelection($0) },
                onFocusPods: { focusPods(for: $0) }
            )
        case .workloadsReplicationControllers:
            WorkloadListView(
                namespace: namespace,
                isConnected: isConnected,
                kind: .replicationController,
                showsKindColumn: false,
                searchText: resourceSearchText,
                sortOption: model.workloadSortOption,
                filter: model.workloadFilterState,
                focusID: workloadQuickSearchFocusID,
                selection: $selectedWorkloadIDs,
                onInspect: { handleWorkloadSelection($0) },
                onFocusPods: { focusPods(for: $0) }
            )
        case .workloadsJobs:
            WorkloadListView(
                namespace: namespace,
                isConnected: isConnected,
                kind: .job,
                showsKindColumn: false,
                searchText: resourceSearchText,
                sortOption: model.workloadSortOption,
                filter: model.workloadFilterState,
                focusID: workloadQuickSearchFocusID,
                selection: $selectedWorkloadIDs,
                onInspect: { handleWorkloadSelection($0) },
                onFocusPods: { focusPods(for: $0) }
            )
        case .workloadsCronJobs:
            WorkloadListView(
                namespace: namespace,
                isConnected: isConnected,
                kind: .cronJob,
                showsKindColumn: false,
                searchText: resourceSearchText,
                sortOption: model.workloadSortOption,
                filter: model.workloadFilterState,
                focusID: workloadQuickSearchFocusID,
                selection: $selectedWorkloadIDs,
                onInspect: { handleWorkloadSelection($0) },
                onFocusPods: { focusPods(for: $0) }
            )
        case .workloadsPods:
            PodListView(
                namespace: namespace,
                isConnected: isConnected,
                filter: model.podFilterState,
                selection: $selectedPodIDs,
                focusedID: $selectedPodID,
                searchText: resourceSearchText,
                onShowDetails: { handleShowDetails($0) },
                onShowLogs: { handleLogs($0) },
                onShowExec: { handleShell($0) },
                onShowYAML: { handleEdit($0) },
                onPortForward: { handlePortForward($0) },
                onEvict: { handleEvict($0) },
                onDelete: { handleDelete($0) },
                focusID: podQuickSearchFocusID
            )
        case .configConfigMaps:
            ConfigResourceListView(
                cluster: cluster,
                namespace: namespace,
                isConnected: isConnected,
                kind: .configMap,
                filterState: model.configFilterState,
                searchText: resourceSearchText
            )
        case .configSecrets:
            ConfigResourceListView(
                cluster: cluster,
                namespace: namespace,
                isConnected: isConnected,
                kind: .secret,
                filterState: model.configFilterState,
                searchText: resourceSearchText
            )
        case .configResourceQuotas:
            ConfigResourceListView(
                cluster: cluster,
                namespace: namespace,
                isConnected: isConnected,
                kind: .resourceQuota,
                filterState: model.configFilterState,
                searchText: resourceSearchText
            )
        case .configLimitRanges:
            ConfigResourceListView(
                cluster: cluster,
                namespace: namespace,
                isConnected: isConnected,
                kind: .limitRange,
                filterState: model.configFilterState,
                searchText: resourceSearchText
            )
        case .configHPAs:
            centeredUnavailableView(
                "Horizontal Pod Autoscalers",
                systemImage: "gauge",
                description: Text("HPA details are coming soon to Kubex.")
            )
        case .configPodDisruptionBudgets:
            centeredUnavailableView(
                "Pod Disruption Budgets",
                systemImage: "shield",
                description: Text("PDB insights are coming soon to Kubex.")
            )
        case .helmReleases:
            HelmListView(
                cluster: cluster,
                isLoading: model.helmLoadingContexts.contains(cluster.contextName),
                errorMessage: model.helmErrors[cluster.contextName],
                selection: $selectedHelmIDs,
                searchText: resourceSearchText
            )
        case .helmRepositories:
            centeredUnavailableView(
                "Helm Repositories",
                systemImage: "shippingbox.and.arrow.up",
                description: Text("Helm repository management is coming soon to Kubex.")
            )
        case .networkServices:
            NetworkListView(
                cluster: cluster,
                namespace: namespace,
                isConnected: isConnected,
                focus: .services,
                serviceSelection: $selectedServiceIDs,
                ingressSelection: $selectedIngressIDs,
                searchText: resourceSearchText,
                servicePermissions: { service in servicePermissions(for: service) },
                onInspectService: { handleServiceInspect($0) },
                onEditService: { handleServiceEdit($0) },
                onDeleteService: { handleServiceDelete($0) }
            )
        case .networkEndpoints:
            NetworkListView(
                cluster: cluster,
                namespace: namespace,
                isConnected: isConnected,
                focus: .endpoints,
                serviceSelection: $selectedServiceIDs,
                ingressSelection: $selectedIngressIDs,
                searchText: resourceSearchText,
                servicePermissions: { service in servicePermissions(for: service) },
                onInspectService: { handleServiceInspect($0) },
                onEditService: { handleServiceEdit($0) },
                onDeleteService: { handleServiceDelete($0) }
            )
        case .networkIngresses:
            NetworkListView(
                cluster: cluster,
                namespace: namespace,
                isConnected: isConnected,
                focus: .ingresses,
                serviceSelection: $selectedServiceIDs,
                ingressSelection: $selectedIngressIDs,
                searchText: resourceSearchText,
                servicePermissions: { service in servicePermissions(for: service) },
                onInspectService: { handleServiceInspect($0) },
                onEditService: { handleServiceEdit($0) },
                onDeleteService: { handleServiceDelete($0) }
            )
        case .networkPolicies:
            NetworkListView(
                cluster: cluster,
                namespace: namespace,
                isConnected: isConnected,
                focus: .networkPolicies,
                serviceSelection: $selectedServiceIDs,
                ingressSelection: $selectedIngressIDs,
                searchText: resourceSearchText,
                servicePermissions: { service in servicePermissions(for: service) },
                onInspectService: { handleServiceInspect($0) },
                onEditService: { handleServiceEdit($0) },
                onDeleteService: { handleServiceDelete($0) }
            )
        case .networkLoadBalancers:
            NetworkListView(
                cluster: cluster,
                namespace: namespace,
                isConnected: isConnected,
                focus: .loadBalancers,
                serviceSelection: $selectedServiceIDs,
                ingressSelection: $selectedIngressIDs,
                searchText: resourceSearchText,
                servicePermissions: { service in servicePermissions(for: service) },
                onInspectService: { handleServiceInspect($0) },
                onEditService: { handleServiceEdit($0) },
                onDeleteService: { handleServiceDelete($0) }
            )
        case .networkPortForwards:
            NetworkListView(
                cluster: cluster,
                namespace: namespace,
                isConnected: isConnected,
                focus: .portForwards,
                serviceSelection: $selectedServiceIDs,
                ingressSelection: $selectedIngressIDs,
                searchText: resourceSearchText,
                servicePermissions: { service in servicePermissions(for: service) },
                onInspectService: { handleServiceInspect($0) },
                onEditService: { handleServiceEdit($0) },
                onDeleteService: { handleServiceDelete($0) }
            )
        case .storagePersistentVolumeClaims:
            StorageListView(
                namespace: namespace,
                isConnected: isConnected,
                selection: $selectedPVCIDs,
                searchText: resourceSearchText,
                claimPermissions: { claim in pvcPermissions(for: claim) },
                onInspectClaim: { handlePVCInspect($0) },
                onEditClaim: { handlePVCEdit($0) },
                onDeleteClaim: { handlePVCDelete($0) }
            )
        case .storagePersistentVolumes:
            centeredUnavailableView(
                "Persistent Volumes",
                systemImage: "externaldrive.connected.to.line.below",
                description: Text("Cluster-scoped PVs will appear here once data wiring is complete.")
            )
        case .storageStorageClasses:
            centeredUnavailableView(
                "Storage Classes",
                systemImage: "internaldrive",
                description: Text("Storage classes will surface here in a future update.")
            )
        default:
            Color.clear
        }
    }

    @ViewBuilder
    private var inspectorDock: some View {
        let selection = inspectorSelectionForCluster
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 0) {
                inspectorResizeHandle
                ResourceInspector(
                    cluster: cluster,
                    namespace: namespace,
                    selectedTab: selectedTab,
                    networkFocus: currentNetworkFocus ?? .services,
                    onFocusPods: { focusPods(for: $0) },
                    podActions: PodInspectorActions(
                        onPortForward: { handlePortForward($0) },
                        onEvict: { handleEvict($0) },
                        onDelete: { handleDelete($0) }
                    ),
                    podTabSelection: $podInspectorTab,
                    workloadTabSelection: $workloadInspectorTab,
                    selection: selection
                )
                .environmentObject(model)
                .frame(width: inspectorWidth)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)

            Button {
                closeInspector()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.white.opacity(0.95), Color.black.opacity(0.25))
                    .padding(6)
            }
            .buttonStyle(.plain)
            .offset(x: 8, y: -8)
        }
    }

    private var inspectorResizeHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 12)
            .overlay(
                Capsule()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 4)
            )
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if inspectorDragBaseline == nil {
                            inspectorDragBaseline = inspectorWidth
                        }
                        let baseline = inspectorDragBaseline ?? inspectorWidth
                        let proposed = baseline - value.translation.width
                        inspectorWidth = min(max(proposed, inspectorMinimumWidth), inspectorMaximumWidth)
                    }
                    .onEnded { _ in
                        inspectorDragBaseline = nil
                    }
            )
    }

private struct PodInspectorActions {
    var onPortForward: (PodSummary) -> Void
    var onEvict: (PodSummary) -> Void
    var onDelete: (PodSummary) -> Void
}

private struct PodExecPane: View {
    let cluster: Cluster
    let namespace: Namespace
    let pod: PodSummary

    @EnvironmentObject private var model: AppModel
    @State private var selectedContainer: String
    @State private var command: String = "env"
    @State private var entries: [ExecEntry] = []
    @State private var isRunning = false
    @State private var errorMessage: String?

    private let maxEntries = 20
    private var canExec: Bool {
        cluster.isConnected && namespace.permissions.canExecPods
    }
    private var execReason: String? {
        namespace.permissions.reason(for: .execPods)
    }

    init(
        cluster: Cluster,
        namespace: Namespace,
        pod: PodSummary
    ) {
        self.cluster = cluster
        self.namespace = namespace
        self.pod = pod
        _selectedContainer = State(initialValue: pod.primaryContainer ?? pod.containerNames.first ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            controlRow
            if !canExec {
                Label(execReason ?? "Exec disabled by RBAC (pods/exec)", systemImage: "hand.raised")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let message = errorMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
            historyView
            Text("Commands run via /bin/sh -lc inside \(displayContainerDescription).")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controlRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    containerPicker
                    TextField("Command", text: $command, prompt: Text("ls -lah /"))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(runCommand)
                        .disabled(isRunning || !canExec)
                        .font(.system(.body, design: .monospaced))
                        .frame(minWidth: 220)
                        .frame(maxWidth: .infinity)
                    Button {
                        runCommand()
                    } label: {
                        Label("Run", systemImage: "play.fill")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(isRunning || command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !canExec)
                    .help(!canExec ? (execReason ?? "Requires pods/exec permission.") : "Execute command inside the container.")
                    Button("Clear") { entries.removeAll() }
                        .disabled(entries.isEmpty)
                    if isRunning {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var containerPicker: some View {
        if pod.containerNames.count > 1 {
            Picker("Container", selection: $selectedContainer) {
                ForEach(pod.containerNames, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 160)
        } else if let only = pod.containerNames.first {
            Label(only, systemImage: "shippingbox")
                .labelStyle(.titleAndIcon)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            EmptyView()
        }
    }

    private var historyView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(entry.command)
                                    .font(.caption.bold())
                                    .textSelection(.enabled)
                                Spacer()
                                Text(entry.result.displayExitCode)
                                    .font(.caption2)
                                    .foregroundStyle(entry.result.isError ? Color.orange : .secondary)
                                Text(entry.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Text(entry.result.output)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(entry.result.isError ? Color.primary : .secondary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(entry.result.isError ? Color.orange.opacity(0.08) : Color(nsColor: .underPageBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .padding(10)
                        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.gray.opacity(0.12))
                        )
                        .id(entry.id)
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .underPageBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
            .onChange(of: entries.count) { _, _ in
                if let lastID = entries.last?.id {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func runCommand() {
        guard !isRunning else { return }
        guard canExec else {
            errorMessage = execReason ?? "You do not have permission to run exec commands in this namespace."
            return
        }
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter a command to execute."
            return
        }

        errorMessage = nil
        isRunning = true
        let containerArg = selectedContainer.isEmpty ? nil : selectedContainer
        Task {
            let result = await model.executePodCommand(
                cluster: cluster,
                namespace: namespace,
                pod: pod,
                container: containerArg,
                command: trimmed
            )

            await MainActor.run {
                isRunning = false
                switch result {
                case .success(let output):
                    appendEntry(command: trimmed, output: output)
                case .failure(let error):
                    errorMessage = error.message
                }
            }
        }
    }

    @MainActor
    private func appendEntry(command: String, output: AppModel.ExecCommandOutput) {
        var bounded = entries
        if bounded.count >= maxEntries {
            bounded.removeFirst(bounded.count - maxEntries + 1)
        }
        bounded.append(ExecEntry(command: command, result: output, timestamp: Date()))
        entries = bounded
    }

    private var displayContainerDescription: String {
        if !selectedContainer.isEmpty {
            return "container \(selectedContainer)"
        }
        if let fallback = pod.containerNames.first, !fallback.isEmpty {
            return "container \(fallback)"
        }
        return "the pod"
    }

    private struct ExecEntry: Identifiable, Equatable {
        let id = UUID()
        let command: String
        let result: AppModel.ExecCommandOutput
        let timestamp: Date
    }
}

fileprivate enum PodInspectorTab: String, CaseIterable, Identifiable {
    case summary
    case logs
    case exec
    case yaml

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summary: return "Summary"
        case .logs: return "Logs"
        case .exec: return "Exec"
        case .yaml: return "YAML"
        }
    }

    var systemImage: String {
        switch self {
        case .summary: return "square.grid.2x2"
        case .logs: return "text.justifyleft"
        case .exec: return "terminal"
        case .yaml: return "doc.plaintext"
        }
    }
}

private struct YAMLEditResult: Equatable {
    var message: String
    var timestamp: Date
    var isSuccess: Bool
}

private struct YAMLEditorState: Equatable {
    var original: String
    var edited: String
    var lastResult: YAMLEditResult?
}

private struct InspectorYAMLEditor: View {
    @Binding var editor: YAMLEditorState?
    var isLoading: Bool
    var isApplying: Bool
    var errorMessage: String?
    var onApply: () -> Void
    var onRevert: () -> Void
    var onReload: () -> Void
    var loadAction: (() -> Void)?

    var body: some View {
        if isLoading && editor == nil {
            ProgressView("Loading YAML…")
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .task { loadAction?() }
        } else if let message = errorMessage {
            VStack(spacing: 8) {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                HStack(spacing: 12) {
                    Button("Retry") { onReload() }
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        } else if editor != nil {
            editorPane
        } else {
            ProgressView("Preparing editor…")
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .task { loadAction?() }
        }
    }

    private var editorPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button("Apply", action: onApply)
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasUnsavedChanges || isApplying)
                Button("Revert", action: onRevert)
                    .disabled(!hasUnsavedChanges || isApplying)
                Button("Reload", action: onReload)
                    .disabled(isLoading)
                if isApplying {
                    ProgressView()
                        .controlSize(.small)
                }
                if hasUnsavedChanges {
                    Text("Unsaved changes")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Spacer()
            }

            TextEditor(text: Binding(
                get: { editor?.edited ?? "" },
                set: { newValue in editor?.edited = newValue }
            ))
            .font(.system(.body, design: .monospaced))
            .padding(12)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .frame(maxWidth: .infinity, minHeight: 260, alignment: .leading)

            if let result = editor?.lastResult {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: result.isSuccess ? "checkmark.seal" : "exclamationmark.triangle")
                        .foregroundStyle(result.isSuccess ? Color.green : Color.orange)
                    Text(result.message)
                        .font(.caption.monospaced())
                        .foregroundStyle(result.isSuccess ? .secondary : .primary)
                        .lineLimit(nil)
                    Spacer()
                    Text(result.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var hasUnsavedChanges: Bool {
        guard let editor else { return false }
        return editor.edited != editor.original
    }
}

private struct PodInspectorView: View {
    let cluster: Cluster
    let namespace: Namespace
    let pod: PodSummary
    @Binding var tab: PodInspectorTab
    let actions: PodInspectorActions

    @EnvironmentObject private var model: AppModel
    @State private var yamlEditor: YAMLEditorState?
    @State private var yamlError: String?
    @State private var isLoadingYAML = false
    @State private var isApplyingYAML = false

    private var activePortForwardsForPod: [ActivePortForward] {
        model.activePortForwards.filter {
            $0.request.clusterID == cluster.id &&
            $0.request.namespace == effectiveNamespace.name &&
            $0.request.podName == pod.name
        }
    }

    private var permissions: NamespacePermissions { effectiveNamespace.permissions }
    private var canViewLogs: Bool { cluster.isConnected && permissions.canViewPodLogs }
    private var canExec: Bool { cluster.isConnected && permissions.canExecPods }
    private var canViewYaml: Bool { cluster.isConnected && permissions.canGetPods }
    private var canDelete: Bool { cluster.isConnected && permissions.canDeletePods }
    private var canPortForward: Bool { cluster.isConnected && permissions.canPortForwardPods }
    private var podEvents: [EventSummary] {
        effectiveNamespace.events.filter { $0.message.localizedCaseInsensitiveContains(pod.name) }
    }
    private var podEventCounts: (warnings: Int, errors: Int) {
        var warnings = 0
        var errors = 0
        for event in podEvents {
            let count = max(event.count, 1)
            switch event.type {
            case .warning: warnings += count
            case .error: errors += count
            default: break
            }
        }
        return (warnings, errors)
    }
    private var availableTabs: [PodInspectorTab] {
        PodInspectorTab.allCases.filter { isTabEnabled($0) }
    }

    private func isTabEnabled(_ tab: PodInspectorTab) -> Bool {
        switch tab {
        case .logs: return canViewLogs
        case .exec: return canExec
        case .yaml: return canViewYaml
        case .summary: return true
        }
    }

    private func permissionTip(for tab: PodInspectorTab) -> String? {
        guard !isTabEnabled(tab) else { return nil }
        switch tab {
        case .logs:
            return permissionHelp(.viewPodLogs, fallback: "Requires pods/log permission.")
        case .exec:
            return permissionHelp(.execPods, fallback: "Requires pods/exec permission.")
        case .yaml:
            return permissionHelp(.getPods, fallback: "Requires get pods permission.")
        case .summary:
            return nil
        }
    }

    private func permissionHelp(_ action: NamespacePermissionAction, fallback: String) -> String? {
        guard !permissions.allows(action) else { return nil }
        return permissions.reason(for: action) ?? fallback
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            actionToolbar

            Divider()

            switch tab {
            case .summary:
                ScrollView {
                    PodDetailSheetView(
                        cluster: cluster,
                        namespace: effectiveNamespace,
                        pod: pod,
                        events: effectiveNamespace.events.filter { $0.message.contains(pod.name) },
                        presentation: .inspector
                    )
                    .environmentObject(model)
                }
            case .logs:
                if canViewLogs {
                    PodLogsPane(
                        cluster: cluster,
                        namespace: effectiveNamespace,
                        pod: pod,
                        presentation: .inspector
                    )
                    .environmentObject(model)
                    .frame(minHeight: 260)
                } else {
                    centeredUnavailableView(
                        "Logs unavailable",
                        systemImage: "lock",
                        description: Text("You do not have permission to view pod logs.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .exec:
                if canExec {
                    PodExecPane(
                        cluster: cluster,
                        namespace: effectiveNamespace,
                        pod: pod
                    )
                    .environmentObject(model)
                    .frame(minHeight: 260)
                } else {
                    centeredUnavailableView(
                        "Exec unavailable",
                        systemImage: "hand.raised",
                        description: Text("Your RBAC policy blocks creating pods/exec sessions.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .yaml:
                if canViewYaml {
                    yamlContent
                } else {
                    centeredUnavailableView(
                        "YAML unavailable",
                        systemImage: "doc",
                        description: Text("You do not have permission to retrieve this pod manifest.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(16)
        .onChange(of: tab) { _, newValue in
            if newValue == .logs && !canViewLogs {
                tab = .summary
                return
            }
            if newValue == .exec && !canExec {
                tab = .summary
                return
            }
            if newValue == .yaml && !canViewYaml {
                tab = .summary
                return
            }
            if newValue == .yaml {
                Task { await loadYAMLIfNeeded() }
            }
        }
        .onChange(of: pod.id) { _, _ in
            yamlEditor = nil
            yamlError = nil
            isLoadingYAML = false
            isApplyingYAML = false
        }
        .task(id: tab) {
            if tab == .yaml && canViewYaml {
                await loadYAMLIfNeeded()
            }
        }
        .onAppear {
            if !availableTabs.contains(tab) {
                tab = .summary
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pod · \(pod.name)")
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
            Text("Namespace \(effectiveNamespace.name)")
                .font(.caption)
                .foregroundStyle(.secondary)
            let counts = podEventCounts
            if counts.errors > 0 || counts.warnings > 0 {
                HStack(spacing: 8) {
                    if counts.errors > 0 {
                        Label("\(counts.errors) errors", systemImage: "exclamationmark.octagon.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.red)
                    }
                    if counts.warnings > 0 {
                        Label("\(counts.warnings) warnings", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.orange)
                    }
                }
            }
            if !activePortForwardsForPod.isEmpty {
                HStack(spacing: 6) {
                    ForEach(activePortForwardsForPod) { forward in
                        PortForwardStatusBadge(forward: forward) { forward in
                            Task { await model.stopPortForward(id: forward.id) }
                        }
                    }
                }
            }
            inspectorTabPicker
        }
    }

    private var actionToolbar: some View {
        HStack(spacing: 12) {
            Spacer()

            Button { actions.onPortForward(pod) } label: {
                Label("Port Forward", systemImage: "arrow.left.and.right")
            }
            .disabled(!canPortForward)
            .optionalHelp(permissionHelp(.portForwardPods, fallback: "Requires pods/portforward permission."))

            Menu {
                Button("Evict") { actions.onEvict(pod) }
                    .disabled(!canDelete)
                    .optionalHelp(permissionHelp(.deletePods, fallback: "Requires delete pods permission."))
                Button(role: .destructive) {
                    actions.onDelete(pod)
                } label: {
                    Text("Delete")
                }
                .disabled(!canDelete)
                .optionalHelp(permissionHelp(.deletePods, fallback: "Requires delete pods permission."))
            } label: {
                Label("Actions", systemImage: "ellipsis.circle")
            }
        }
        .labelStyle(.titleAndIcon)
        .font(.caption)
    }

    private var inspectorTabPicker: some View {
        Picker("", selection: $tab) {
            ForEach(PodInspectorTab.allCases) { candidate in
                Label(candidate.title, systemImage: candidate.systemImage)
                    .tag(candidate)
                    .disabled(!isTabEnabled(candidate))
                    .opacity(isTabEnabled(candidate) ? 1 : 0.35)
                    .optionalHelp(permissionTip(for: candidate))
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .labelsHidden()
    }

    private var yamlContent: some View {
        InspectorYAMLEditor(
            editor: $yamlEditor,
            isLoading: isLoadingYAML,
            isApplying: isApplyingYAML,
            errorMessage: yamlError,
            onApply: applyYAML,
            onRevert: revertYAML,
            onReload: { Task { await loadYAML(force: true) } },
            loadAction: { Task { await loadYAMLIfNeeded() } }
        )
    }

    private var hasUnsavedChanges: Bool {
        guard let editor = yamlEditor else { return false }
        return editor.edited != editor.original
    }

    @MainActor
    private func loadYAMLIfNeeded() async {
        await loadYAML(force: false)
    }

    @MainActor
    private func loadYAML(force: Bool) async {
        if isLoadingYAML && !force { return }
        if yamlEditor != nil && !force { return }
        isLoadingYAML = true
        yamlError = nil
        if force {
            yamlEditor = nil
        }
        defer { isLoadingYAML = false }

        let result = await model.fetchPodYAML(cluster: cluster, namespace: effectiveNamespace, pod: pod)
        switch result {
        case .success(let yaml):
            yamlEditor = YAMLEditorState(original: yaml, edited: yaml, lastResult: nil)
        case .failure(let error):
            yamlError = error.message
        }
    }

    private func applyYAML() {
        guard !isApplyingYAML, hasUnsavedChanges, let current = yamlEditor else { return }
        let edited = current.edited
        isApplyingYAML = true
        Task {
            let result = await model.applyPodYAML(cluster: cluster, namespace: effectiveNamespace, pod: pod, yaml: edited)
            await MainActor.run {
                isApplyingYAML = false
                switch result {
                case .success(let output):
                    var updated = yamlEditor ?? current
                    updated.original = edited
                    let message = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    let display = message.isEmpty ? "kubectl apply succeeded" : message
                    updated.lastResult = YAMLEditResult(message: display, timestamp: Date(), isSuccess: true)
                    yamlEditor = updated
                case .failure(let error):
                    var updated = yamlEditor ?? current
                    updated.lastResult = YAMLEditResult(message: error.message, timestamp: Date(), isSuccess: false)
                    yamlEditor = updated
                }
            }
        }
    }

    private var effectiveNamespace: Namespace {
        if namespace.id != AppModel.allNamespacesNamespaceID {
            return namespace
        }
        return model.namespace(clusterID: cluster.id, named: pod.namespace) ?? namespace
    }

    private func revertYAML() {
        guard !isApplyingYAML, var editor = yamlEditor else { return }
        editor.edited = editor.original
        editor.lastResult = nil
        yamlEditor = editor
    }
}

private struct PortForwardStatusBadge: View {
    let forward: ActivePortForward
    var onStop: (ActivePortForward) -> Void

    @State private var isHovering = false

    private var displayText: String {
        "localhost:\(forward.request.localPort) → \(forward.request.podName):\(forward.request.remotePort)"
    }

    private var status: PortForwardStatus {
        forward.status
    }

    private var statusColor: Color {
        switch status {
        case .active: return .green
        case .establishing: return .blue
        case .failed: return .orange
        }
    }

    private var statusIcon: String {
        switch status {
        case .active: return "bolt.horizontal.circle"
        case .establishing: return "hourglass"
        case .failed: return "exclamationmark.triangle"
        }
    }

    private var statusHelp: String? {
        if case let .failed(message) = status {
            return message
        }
        return nil
    }

    private var canStop: Bool {
        switch status {
        case .establishing:
            return false
        case .active, .failed:
            return true
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: statusIcon)
            Text(displayText)
                .lineLimit(1)
                .truncationMode(.middle)
            if canStop {
                Button {
                    onStop(forward)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .opacity(isHovering ? 1 : 0.6)
                .help("Stop port forward")
            }
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(statusColor)
        .background(statusColor.opacity(0.14), in: Capsule())
        .help(statusHelp ?? {
            switch status {
            case .active: return "Port forward established"
            case .establishing: return "Setting up port forward"
            case .failed: return "Port forward failed"
            }
        }())
        .onHover { isHovering = $0 }
    }
}

private struct WorkloadInspectorView: View {
    let cluster: Cluster
    let namespace: Namespace
    let workload: WorkloadSummary
    let pods: [PodSummary]
    @Binding var tab: WorkloadInspectorTab
    let onFocusPods: (WorkloadSummary) -> Void
    let onSelectPod: (PodSummary) -> Void

    @EnvironmentObject private var model: AppModel
    @State private var yamlEditor: YAMLEditorState?
    @State private var yamlError: String?
    @State private var isLoadingYAML = false
    @State private var isApplyingYAML = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Picker("", selection: $tab) {
                ForEach(WorkloadInspectorTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            Divider()

            switch tab {
            case .summary:
                ScrollView {
                    WorkloadDetailSheetView(
                        cluster: cluster,
                        namespace: namespace,
                        workload: workload,
                        pods: pods,
                        onFocusPods: { onFocusPods(workload) },
                        presentation: .inspector
                    )
                    .environmentObject(model)
                }
            case .rollout:
                WorkloadRolloutPane(
                    clusterID: cluster.id,
                    namespace: namespace,
                    workload: workload,
                    pods: pods,
                    onFocusPods: { onFocusPods(workload) },
                    onSelectPod: onSelectPod,
                    selectedPodID: selectedPodID
                )
                .environmentObject(model)
            case .yaml:
                yamlContent
            }
        }
        .padding(16)
        .onChange(of: tab) { _, newValue in
            if newValue == .yaml {
                Task { await loadYAMLIfNeeded() }
            }
        }
        .onChange(of: workload.id) { _, _ in
            yamlEditor = nil
            yamlError = nil
            isLoadingYAML = false
            isApplyingYAML = false
        }
        .task(id: tab) {
            if tab == .yaml {
                await loadYAMLIfNeeded()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(workload.kind.displayName) · \(workload.name)")
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
            Text("Namespace \(namespace.name)")
                .font(.caption)
                .foregroundStyle(.secondary)
            let counts = workloadEventCounts
            if counts.errors > 0 || counts.warnings > 0 {
                HStack(spacing: 8) {
                    if counts.errors > 0 {
                        Label("\(counts.errors) errors", systemImage: "exclamationmark.octagon.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.red)
                    }
                    if counts.warnings > 0 {
                        Label("\(counts.warnings) warnings", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.orange)
                    }
                }
            }
        }
    }

    private var workloadEvents: [EventSummary] {
        let workloadName = workload.name.lowercased()
        let podNames = Set(pods.map { $0.name.lowercased() })
        return namespace.events.filter { event in
            let message = event.message.lowercased()
            if message.contains(workloadName) { return true }
            return podNames.contains { message.contains($0) }
        }
    }

    private var workloadEventCounts: (warnings: Int, errors: Int) {
        var warnings = 0
        var errors = 0
        for event in workloadEvents {
            let count = max(event.count, 1)
            switch event.type {
            case .warning: warnings += count
            case .error: errors += count
            default: break
            }
        }
        return (warnings, errors)
    }

    private var yamlContent: some View {
        InspectorYAMLEditor(
            editor: $yamlEditor,
            isLoading: isLoadingYAML,
            isApplying: isApplyingYAML,
            errorMessage: yamlError,
            onApply: applyYAML,
            onRevert: revertYAML,
            onReload: { Task { await loadYAML(force: true) } },
            loadAction: { Task { await loadYAMLIfNeeded() } }
        )
    }

    private var hasUnsavedChanges: Bool {
        guard let editor = yamlEditor else { return false }
        return editor.edited != editor.original
    }

    private var selectedPodID: PodSummary.ID? {
        if case let .pod(clusterID, namespaceID, podID) = model.inspectorSelection,
           clusterID == cluster.id,
           namespaceID == namespace.id {
            return podID
        }
        return nil
    }

    @MainActor
    private func loadYAMLIfNeeded() async {
        await loadYAML(force: false)
    }

    @MainActor
    private func loadYAML(force: Bool) async {
        if isLoadingYAML && !force { return }
        if yamlEditor != nil && !force { return }
        isLoadingYAML = true
        yamlError = nil
        if force {
            yamlEditor = nil
        }
        defer { isLoadingYAML = false }

        let result = await model.fetchWorkloadYAML(cluster: cluster, namespace: namespace, workload: workload)
        switch result {
        case .success(let yaml):
            yamlEditor = YAMLEditorState(original: yaml, edited: yaml, lastResult: nil)
        case .failure(let error):
            yamlError = error.message
        }
    }

    private func applyYAML() {
        guard !isApplyingYAML, hasUnsavedChanges, let current = yamlEditor else { return }
        let edited = current.edited
        isApplyingYAML = true
        Task {
            let result = await model.applyWorkloadYAML(cluster: cluster, namespace: namespace, workload: workload, yaml: edited)
            await MainActor.run {
                isApplyingYAML = false
                switch result {
                case .success(let output):
                    var updated = yamlEditor ?? current
                    updated.original = edited
                    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    let message = trimmed.isEmpty ? "kubectl apply succeeded" : trimmed
                    updated.lastResult = YAMLEditResult(message: message, timestamp: Date(), isSuccess: true)
                    yamlEditor = updated
                case .failure(let error):
                    var updated = yamlEditor ?? current
                    updated.lastResult = YAMLEditResult(message: error.message, timestamp: Date(), isSuccess: false)
                    yamlEditor = updated
                }
            }
        }
    }

    private func revertYAML() {
        guard !isApplyingYAML, var editor = yamlEditor else { return }
        editor.edited = editor.original
        editor.lastResult = nil
        yamlEditor = editor
    }
}

private struct WorkloadRolloutPane: View {
    let clusterID: Cluster.ID
    let namespace: Namespace
    let workload: WorkloadSummary
    let pods: [PodSummary]
    let onFocusPods: () -> Void
    let onSelectPod: (PodSummary) -> Void
    let selectedPodID: PodSummary.ID?

    @EnvironmentObject private var model: AppModel

    private static let annotationFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private var rolloutSeries: WorkloadRolloutSeries? {
        model.workloadRolloutSeries(for: clusterID, namespace: namespace.name, workloadName: workload.name, kind: workload.kind)
    }

    private var servicesByPod: [String: [ServiceSummary]] {
        var mapping: [String: [ServiceSummary]] = [:]
        for service in namespace.services where !service.targetPods.isEmpty {
            for podName in service.targetPods {
                mapping[podName, default: []].append(service)
            }
        }
        return mapping
    }

    private var eventsByPod: [String: (warnings: Int, errors: Int)] {
        var mapping: [String: (Int, Int)] = [:]
        let lowercasedPods = pods.map { $0.name.lowercased() }
        for event in namespace.events where event.type != .normal {
            let message = event.message.lowercased()
            let count = max(event.count, 1)
            for (index, podName) in lowercasedPods.enumerated() {
                guard message.contains(podName) else { continue }
                var entry = mapping[pods[index].name, default: (0, 0)]
                switch event.type {
                case .warning: entry.0 += count
                case .error: entry.1 += count
                default: break
                }
                mapping[pods[index].name] = entry
            }
        }
        return mapping
    }

    private var rolloutChartData: [RolloutChartSample] {
        guard let series = rolloutSeries else { return [] }
        var samples: [RolloutChartSample] = []
        for point in series.ready {
            samples.append(RolloutChartSample(series: .ready, point: point))
        }
        for point in series.updated {
            samples.append(RolloutChartSample(series: .updated, point: point))
        }
        for point in series.available {
            samples.append(RolloutChartSample(series: .available, point: point))
        }
        return samples.sorted { $0.point.timestamp < $1.point.timestamp }
    }

    private var chartTimeRange: ClosedRange<Date>? {
        guard let first = rolloutChartData.first?.point.timestamp,
              let last = rolloutChartData.last?.point.timestamp else {
            return nil
        }
        return first...last
    }

    private var maxReplicaValue: Double {
        let historyMax = rolloutChartData.map { $0.point.value }.max() ?? 0
        return max(historyMax, Double(workload.replicas), 1)
    }

    private var seriesColorScale: KeyValuePairs<String, Color> {
        KeyValuePairs(dictionaryLiteral:
            (RolloutSeriesLabel.ready.displayName, RolloutSeriesLabel.ready.color),
            (RolloutSeriesLabel.updated.displayName, RolloutSeriesLabel.updated.color),
            (RolloutSeriesLabel.available.displayName, RolloutSeriesLabel.available.color)
        )
    }

    private var rolloutAnnotations: [RolloutEventAnnotation] {
        guard let timeRange = chartTimeRange else { return [] }
        let annotations = relatedEvents.compactMap { event -> RolloutEventAnnotation? in
            guard let timestamp = event.timestamp, timeRange.contains(timestamp) else { return nil }
            let category: RolloutEventAnnotation.Category = (event.type == .normal) ? .success : .failure
            return RolloutEventAnnotation(timestamp: timestamp, category: category, message: event.message, count: event.count)
        }
        return Array(annotations.sorted { $0.timestamp < $1.timestamp }.suffix(8))
    }

    private var rolloutAlertCounts: (warnings: Int, errors: Int) {
        var warnings = 0
        var errors = 0
        for event in relatedEvents {
            let count = max(event.count, 1)
            switch event.type {
            case .warning: warnings += count
            case .error: errors += count
            default: break
            }
        }
        return (warnings, errors)
    }

    private func serviceLine(for services: [ServiceSummary]) -> some View {
        let names = services.map(\.name).sorted()
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: "link")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(names.joined(separator: ", "))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    @ViewBuilder
    private func rolloutAnnotationLabel(_ annotation: RolloutEventAnnotation) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: annotation.category.icon)
                    .font(.caption2)
                    .foregroundStyle(annotation.category.tint)
                Text(annotation.category == .success ? "Success" : "Attention")
                    .font(.caption2.bold())
                    .foregroundStyle(annotation.category.tint)
                Text(Self.annotationFormatter.localizedString(for: annotation.timestamp, relativeTo: Date()))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if annotation.count > 1 {
                    Text("×\(annotation.count)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            Text(annotation.message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(6)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func statusChangeLabel(_ marker: RolloutStatusChange) -> some View {
        HStack(spacing: 6) {
            Image(systemName: marker.state.icon)
                .font(.caption2)
                .foregroundStyle(marker.state.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(marker.state.label)
                    .font(.caption2.bold())
                    .foregroundStyle(marker.state.tint)
                Text("Ready \(marker.readinessRatio.formatted(.percent.precision(.fractionLength(0...1))))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(6)
        .background(.thinMaterial, in: Capsule())
    }

    private var relatedEvents: [EventSummary] {
        let workloadName = workload.name.lowercased()
        let podNames = Set(pods.map { $0.name.lowercased() })
        return namespace.events
            .filter { event in
                let message = event.message.lowercased()
                if message.contains(workloadName) { return true }
                return podNames.contains { message.contains($0) }
            }
            .sorted { lhs, rhs in
                switch (lhs.timestamp, rhs.timestamp) {
                case let (lhsDate?, rhsDate?):
                    return lhsDate > rhsDate
                case (nil, nil):
                    return ageValue(lhs.age) < ageValue(rhs.age)
                case (nil, _):
                    return false
                case (_, nil):
                    return true
                }
            }
    }

    private var timedEvents: [EventSummary] {
        relatedEvents
            .filter { $0.timestamp != nil }
            .sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
    }

    private var rolloutHealthSegments: [RolloutHealthSegment] {
        guard let readyPoints = rolloutSeries?.ready.sorted(by: { $0.timestamp < $1.timestamp }), !readyPoints.isEmpty,
              let range = chartTimeRange else { return [] }
        var segments: [RolloutHealthSegment] = []
        let timelineEnd = range.upperBound

        for (index, point) in readyPoints.enumerated() {
            let start = point.timestamp
            let end: Date
            if index < readyPoints.count - 1 {
                end = max(start, readyPoints[index + 1].timestamp)
            } else {
                end = max(start, timelineEnd)
            }
            guard end > start else { continue }

            var state = healthState(for: readinessRatio(forValue: point.value))
            if containsEvent(in: start..<end, matching: { $0.type == .error }) {
                state = .failing
            } else if containsEvent(in: start..<end, matching: { $0.type == .warning }) && state != .failing {
                state = .warning
            }

            segments.append(RolloutHealthSegment(start: start, end: end, state: state))
        }
        return segments
    }

    private var statusChangeMarkers: [RolloutStatusChange] {
        let segments = rolloutHealthSegments
        guard segments.count > 1 else { return [] }
        var markers: [RolloutStatusChange] = []
        var previousState = segments.first!.state
        for segment in segments.dropFirst() {
            guard segment.state != previousState else { continue }
            let ratio = readinessRatio(at: segment.start)
            markers.append(RolloutStatusChange(timestamp: segment.start, state: segment.state, readinessRatio: ratio))
            previousState = segment.state
            if markers.count >= 5 { break }
        }
        return markers
    }

    private var statusBreakdown: [(label: String, count: Int, color: Color)] {
        statusSummary(for: pods)
    }

    private var restartsSummary: (total: Int, max: Int) {
        let restarts = pods.map { $0.restarts }
        return (restarts.reduce(0, +), restarts.max() ?? 0)
    }

    private var topologyColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    private var podsGroupedByNode: [(node: String, pods: [PodSummary])] {
        let grouped = Dictionary(grouping: pods) { summary -> String in
            let node = summary.nodeName.trimmingCharacters(in: .whitespacesAndNewlines)
            return node.isEmpty ? "Unscheduled" : node
        }

        return grouped.keys.sorted().map { key in
            (node: key, pods: grouped[key]!.sorted { $0.name < $1.name })
        }
    }

    private func ageValue(_ age: EventAge?) -> Int {
        guard let age else { return Int.max }
        switch age {
        case .minutes(let value): return max(value, 0)
        case .hours(let value): return max(value, 0) * 60
        case .days(let value): return max(value, 0) * 1_440
        }
    }

    private func healthState(for ratio: Double) -> RolloutHealthState {
        if ratio >= 0.88 { return .healthy }
        if ratio >= 0.65 { return .warning }
        return .failing
    }

    private func readinessRatio(forValue value: Double) -> Double {
        guard maxReplicaValue > 0 else { return 0 }
        return min(max(value / maxReplicaValue, 0), 1)
    }

    private func readinessRatio(at timestamp: Date) -> Double {
        guard let readyPoints = rolloutSeries?.ready.sorted(by: { $0.timestamp < $1.timestamp }), !readyPoints.isEmpty else {
            return 0
        }
        var latest = readyPoints.first!
        for point in readyPoints {
            if point.timestamp <= timestamp {
                latest = point
            } else {
                break
            }
        }
        return readinessRatio(forValue: latest.value)
    }

    private func containsEvent(in range: Range<Date>, matching predicate: (EventSummary) -> Bool) -> Bool {
        guard !range.isEmpty else { return false }
        for event in timedEvents {
            guard let timestamp = event.timestamp else { continue }
            if timestamp < range.lowerBound { continue }
            if timestamp >= range.upperBound { break }
            if predicate(event) { return true }
        }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                rolloutSection
                rolloutHistorySection
                podsSection
                topologySection
                eventsSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var rolloutSection: some View {
        SectionBox(title: "Rollout Progress") {
            VStack(alignment: .leading, spacing: 12) {
                rolloutProgressRow(
                    label: "Ready",
                    current: Double(workload.readyReplicas),
                    total: Double(max(1, workload.replicas)),
                    tint: .green
                )
                if let updated = workload.updatedReplicas {
                    rolloutProgressRow(
                        label: "Updated",
                        current: Double(updated),
                        total: Double(max(1, workload.replicas)),
                        tint: .blue
                    )
                }
                if let available = workload.availableReplicas {
                    rolloutProgressRow(
                        label: "Available",
                        current: Double(available),
                        total: Double(max(1, workload.replicas)),
                        tint: .teal
                    )
                }

                if workload.kind == .job {
                    jobSummary
                } else if workload.kind == .cronJob {
                    cronSummary
                }

                if rolloutAlertCounts.warnings > 0 || rolloutAlertCounts.errors > 0 {
                    HStack(spacing: 12) {
                        if rolloutAlertCounts.errors > 0 {
                            Label("\(rolloutAlertCounts.errors) errors", systemImage: "exclamationmark.octagon.fill")
                                .font(.caption.bold())
                                .foregroundStyle(Color.red)
                        }
                        if rolloutAlertCounts.warnings > 0 {
                            Label("\(rolloutAlertCounts.warnings) warnings", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption.bold())
                                .foregroundStyle(Color.orange)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private var rolloutHistorySection: some View {
        SectionBox(title: "Replica History") {
            let data = rolloutChartData
            if data.isEmpty {
                Text("History will populate after a few refresh cycles.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(rolloutHealthSegments) { segment in
                        RectangleMark(
                            xStart: .value("Start", segment.start),
                            xEnd: .value("End", segment.end),
                            yStart: .value("Min", 0),
                            yEnd: .value("Max", maxReplicaValue)
                        )
                        .foregroundStyle(segment.state.tint.opacity(0.08))
                        .zIndex(-1)
                    }

                    ForEach(data) { sample in
                        LineMark(
                            x: .value("Time", sample.point.timestamp),
                            y: .value("Replicas", sample.point.value)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(by: .value("Series", sample.series.displayName))

                        AreaMark(
                            x: .value("Time", sample.point.timestamp),
                            y: .value("Replicas", sample.point.value)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(by: .value("Series", sample.series.displayName))
                        .opacity(0.12)
                    }

                    ForEach(rolloutAnnotations) { annotation in
                        RuleMark(x: .value("Time", annotation.timestamp))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(annotation.category.tint.opacity(0.6))
                            .annotation(position: .topLeading) {
                                rolloutAnnotationLabel(annotation)
                            }

                        PointMark(
                            x: .value("Time", annotation.timestamp),
                            y: .value("Replicas", maxReplicaValue)
                        )
                        .symbol(annotation.category == .failure ? .triangle : .circle)
                        .symbolSize(annotation.category == .failure ? 120 : 70)
                        .foregroundStyle(annotation.category.tint)
                    }

                    ForEach(statusChangeMarkers) { marker in
                        RuleMark(x: .value("Time", marker.timestamp))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                            .foregroundStyle(marker.state.tint.opacity(0.35))
                            .annotation(position: .bottomLeading) {
                                statusChangeLabel(marker)
                            }
                    }
                }
                .chartForegroundStyleScale(seriesColorScale)
                .chartYScale(domain: 0...maxReplicaValue)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisTick()
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.hour().minute())
                            }
                        }
                    }
                }
                .frame(minHeight: 160)
            }
        }
    }

    private var jobSummary: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
            GridRow {
                metric(label: "Active", value: workload.activeDisplay)
                metric(label: "Succeeded", value: workload.succeededDisplay)
                metric(label: "Failed", value: workload.failedDisplay)
            }
        }
    }

    private var cronSummary: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
            GridRow {
                metric(label: "Schedule", value: workload.scheduleDisplay)
                metric(label: "Mode", value: workload.suspensionDisplay)
                metric(label: "Ready", value: workload.readyDisplay)
            }
        }
    }

    private var podsSection: some View {
        SectionBox(title: "Pods (\(pods.count))") {
            if pods.isEmpty {
                centeredUnavailableView(
                    "No Pods",
                    systemImage: "circle.grid.3x3",
                    description: Text("Pods managed by this workload will appear when the rollout starts.")
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if !statusBreakdown.isEmpty {
                        HStack(spacing: 10) {
                            ForEach(statusBreakdown, id: \.label) { item in
                                Label("\(item.count)", systemImage: "circle.fill")
                                    .labelStyle(.titleAndIcon)
                                    .font(.caption)
                                    .foregroundStyle(item.color)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(item.color.opacity(0.12), in: Capsule())
                            }
                            Spacer()
                            Button("Focus Pods") { onFocusPods() }
                                .buttonStyle(.bordered)
                        }
                    }

                    restartSummaryView

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Name")
                                .font(.caption.smallCaps())
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Status")
                                .font(.caption.smallCaps())
                                .frame(width: 70, alignment: .leading)
                            Text("Ready")
                                .font(.caption.smallCaps())
                                .frame(width: 60, alignment: .trailing)
                            Text("Restarts")
                                .font(.caption.smallCaps())
                                .frame(width: 70, alignment: .trailing)
                            Text("Node")
                                .font(.caption.smallCaps())
                                .frame(width: 120, alignment: .leading)
                        }
                        .foregroundStyle(.secondary)

                        ForEach(pods.sorted { $0.name < $1.name }) { pod in
                            let isSelected = selectedPodID == pod.id
                            let alertState = alertState(for: pod)
                            Button {
                                onSelectPod(pod)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(pod.name)
                                            .font(.caption.monospaced())
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(pod.phase.displayName)
                                            .font(.caption)
                                            .foregroundStyle(pod.phase.tint)
                                            .frame(width: 70, alignment: .leading)
                                        Text("\(pod.readyContainers)/\(pod.totalContainers)")
                                            .font(.caption.monospaced())
                                            .frame(width: 60, alignment: .trailing)
                                        Text("\(pod.restarts)")
                                            .font(.caption.monospaced())
                                            .foregroundStyle(pod.restarts > 0 ? Color.orange : .secondary)
                                            .frame(width: 70, alignment: .trailing)
                                        Text(pod.nodeName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 120, alignment: .leading)
                                    }

                                    if let owner = pod.controlledBy {
                                        Label(owner, systemImage: "person.crop.square")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }

                                    if let services = servicesByPod[pod.name], !services.isEmpty {
                                        serviceLine(for: services)
                                    }
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(backgroundColor(for: pod, isSelected: isSelected, alertState: alertState))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(borderColor(for: alertState, isSelected: isSelected), lineWidth: isSelected ? 1.5 : 1)
                            )
                        }
                    }
                }
            }
        }
    }

    private var restartSummaryView: some View {
        let stats = restartsSummary
        return HStack(spacing: 16) {
            Label("Total Restarts: \(stats.total)", systemImage: "arrow.clockwise")
                .font(.caption)
                .foregroundStyle(stats.total > 0 ? Color.orange : .secondary)
            Label("Max Pod Restarts: \(stats.max)", systemImage: "flame")
                .font(.caption)
                .foregroundStyle(stats.max > 0 ? Color.orange : .secondary)
        }
    }

    private var topologySection: some View {
        SectionBox(title: "Topology") {
            if pods.isEmpty {
                Text("Pods will appear here once the workload schedules them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: topologyColumns, spacing: 12) {
                    ForEach(podsGroupedByNode, id: \.node) { group in
                        topologyCard(for: group.node, pods: group.pods)
                    }
                }
            }
        }
    }

    private var eventsSection: some View {
        SectionBox(title: "Recent Events") {
            if relatedEvents.isEmpty {
                Text("No recent events for this workload")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                EventTimelineView(events: Array(relatedEvents.prefix(12)))
            }
        }
    }

    private func rolloutProgressRow(label: String, current: Double, total: Double, tint: Color) -> some View {
        let percentage = min(max(current / max(total, 1), 0), 1)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text("\(Int(current))/\(Int(total))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: percentage)
                .accentColor(tint)
            Text(percentage.formatted(.percent.precision(.fractionLength(1))))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospaced())
        }
    }

    private func statusSummary(for pods: [PodSummary]) -> [(label: String, count: Int, color: Color)] {
        let groups = Dictionary(grouping: pods) { $0.phase }
        return PodPhase.allCases.compactMap { phase in
            let count = groups[phase]?.count ?? 0
            guard count > 0 else { return nil }
            return (phase.displayName, count, phase.tint)
        }
    }

    private func topologyCard(for node: String, pods: [PodSummary]) -> some View {
        let containsSelection = selectedPodID.map { id in pods.contains(where: { $0.id == id }) } ?? false
        let nodeState = nodeAlertState(for: pods)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(node)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text("\(pods.count) pod\(pods.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            let summary = statusSummary(for: pods)
            if !summary.isEmpty {
                HStack(spacing: 8) {
                    ForEach(summary, id: \.label) { item in
                        Label("\(item.count)", systemImage: "circle.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.caption2)
                            .foregroundStyle(item.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(item.color.opacity(0.12), in: Capsule())
                    }
                }
            }

            Divider()

            ForEach(Array(pods.prefix(4))) { pod in
                let isSelected = selectedPodID == pod.id
                let alertState = alertState(for: pod)
                Button {
                    onSelectPod(pod)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(color(for: alertState, default: pod.phase.tint))
                                .frame(width: 8, height: 8)
                            Text(pod.name)
                                .font(.caption.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            if pod.restarts > 0 {
                                Label("\(pod.restarts)", systemImage: "arrow.clockwise")
                                    .labelStyle(.iconOnly)
                                    .font(.caption2)
                                    .foregroundStyle(Color.orange)
                                    .accessibilityLabel("\(pod.restarts) restarts")
                            }
                        }

                        if let owner = pod.controlledBy {
                            Label(owner, systemImage: "person.crop.square")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        if let services = servicesByPod[pod.name], !services.isEmpty {
                            serviceLine(for: services)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(backgroundColor(for: pod, isSelected: isSelected, alertState: alertState, base: Color(nsColor: .underPageBackgroundColor)))
                    )
                }
                .buttonStyle(.plain)
            }

            if pods.count > 4 {
                Text("+\(pods.count - 4) more pods")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            let stats = serviceStats(for: pods)
            if !stats.isEmpty {
                Divider()
                servicesSummary(stats)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(nodeHighlight(for: nodeState))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(nodeBorderColor(for: nodeState, highlighted: containsSelection), lineWidth: containsSelection ? 1.5 : 1)
        )
    }

    private func serviceStats(for pods: [PodSummary]) -> [ServiceCardStat] {
        var counts: [ServiceSummary.ID: Int] = [:]
        var serviceLookup: [ServiceSummary.ID: ServiceSummary] = [:]

        for pod in pods {
            guard let services = servicesByPod[pod.name], !services.isEmpty else { continue }
            for service in services {
                counts[service.id, default: 0] += 1
                if serviceLookup[service.id] == nil {
                    serviceLookup[service.id] = service
                }
            }
        }

        return counts.compactMap { id, nodeCount in
            guard let service = serviceLookup[id] else { return nil }
            return ServiceCardStat(service: service, nodeEndpointCount: nodeCount)
        }
        .sorted { $0.service.name < $1.service.name }
    }

    @ViewBuilder
    private func servicesSummary(_ stats: [ServiceCardStat]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Services")
                .font(.caption2)
                .foregroundStyle(.secondary)

            ForEach(stats) { stat in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(stat.service.name)
                            .font(.caption.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        serviceHealthChip(for: stat.service)
                            .font(.caption2)

                        Text("p50 \(formatLatency(stat.service.latencyP50))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("p95 \(formatLatency(stat.service.latencyP95))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .underPageBackgroundColor))
                )
            }
        }
    }

    private func formatLatency(_ latency: TimeInterval?) -> String {
        guard let latency else { return "—" }
        if latency >= 1 {
            return latency.formatted(.number.precision(.fractionLength(2))) + "s"
        }
        let milliseconds = latency * 1_000
        return milliseconds.formatted(.number.precision(.fractionLength(0...1))) + "ms"
    }

    @ViewBuilder
    private func serviceHealthChip(for service: ServiceSummary) -> some View {
        let total = service.totalEndpointCount
        if total == 0 {
            Text("No endpoints")
                .foregroundStyle(.secondary)
        } else {
            let state = service.healthState
            HStack(spacing: 6) {
                Circle()
                    .fill(state.tint)
                    .frame(width: 6, height: 6)
                Text("\(service.endpointHealthDisplay) ready")
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(state.tint.opacity(0.12), in: Capsule())
        }
    }

    private struct ServiceCardStat: Identifiable {
        let service: ServiceSummary
        let nodeEndpointCount: Int

        var id: ServiceSummary.ID { service.id }
    }

    private enum PodAlertState {
        case none
        case warning
        case error
    }

    private func alertState(for pod: PodSummary) -> PodAlertState {
        guard let entry = eventsByPod[pod.name] else { return .none }
        if entry.errors > 0 { return .error }
        if entry.warnings > 0 { return .warning }
        return .none
    }

    private func nodeAlertState(for pods: [PodSummary]) -> PodAlertState {
        var state: PodAlertState = .none
        for pod in pods {
            let podState = alertState(for: pod)
            if podState == .error { return .error }
            if podState == .warning { state = .warning }
        }
        return state
    }

    private func backgroundColor(for pod: PodSummary, isSelected: Bool, alertState: PodAlertState, base: Color = Color(nsColor: .textBackgroundColor)) -> Color {
        if isSelected { return Color.accentColor.opacity(0.18) }
        switch alertState {
        case .error: return Color.red.opacity(0.18)
        case .warning: return Color.orange.opacity(0.14)
        case .none: return base
        }
    }

    private func borderColor(for alertState: PodAlertState, isSelected: Bool) -> Color {
        if isSelected { return Color.accentColor.opacity(0.6) }
        switch alertState {
        case .error: return Color.red.opacity(0.5)
        case .warning: return Color.orange.opacity(0.4)
        case .none: return Color.gray.opacity(0.15)
        }
    }

    private func nodeHighlight(for state: PodAlertState) -> Color {
        switch state {
        case .error: return Color.red.opacity(0.12)
        case .warning: return Color.orange.opacity(0.08)
        case .none: return Color.clear
        }
    }

    private func nodeBorderColor(for state: PodAlertState, highlighted: Bool) -> Color {
        if highlighted { return Color.accentColor.opacity(0.6) }
        switch state {
        case .error: return Color.red.opacity(0.5)
        case .warning: return Color.orange.opacity(0.4)
        case .none: return Color.gray.opacity(0.12)
        }
    }

    private func color(for alertState: PodAlertState, default tint: Color) -> Color {
        switch alertState {
        case .error: return .red
        case .warning: return .orange
        case .none: return tint
        }
    }

    private enum RolloutSeriesLabel: String, CaseIterable {
        case ready
        case updated
        case available

        var displayName: String {
            switch self {
            case .ready: return "Ready"
            case .updated: return "Updated"
            case .available: return "Available"
            }
        }

        var color: Color {
            switch self {
            case .ready: return .green
            case .updated: return .blue
            case .available: return .teal
            }
        }
    }

    private struct RolloutChartSample: Identifiable {
        let id = UUID()
        let series: RolloutSeriesLabel
        let point: MetricPoint
    }

    private struct RolloutEventAnnotation: Identifiable {
        enum Category {
            case success
            case failure

            var tint: Color {
                switch self {
                case .success: return .green
                case .failure: return .orange
                }
            }

            var icon: String {
                switch self {
                case .success: return "checkmark.circle"
                case .failure: return "exclamationmark.triangle"
                }
            }
        }

        let id = UUID()
        let timestamp: Date
        let category: Category
        let message: String
        let count: Int
    }

    private enum RolloutHealthState: String {
        case healthy
        case warning
        case failing

        var tint: Color {
            switch self {
            case .healthy: return .green
            case .warning: return .orange
            case .failing: return .red
            }
        }

        var icon: String {
            switch self {
            case .healthy: return "checkmark.seal.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .failing: return "xmark.octagon.fill"
            }
        }

        var label: String {
            switch self {
            case .healthy: return "Healthy"
            case .warning: return "Warning"
            case .failing: return "Failing"
            }
        }
    }

    private struct RolloutHealthSegment: Identifiable {
        let id = UUID()
        let start: Date
        let end: Date
        let state: RolloutHealthState
    }

    private struct RolloutStatusChange: Identifiable {
        let id = UUID()
        let timestamp: Date
        let state: RolloutHealthState
        let readinessRatio: Double
    }
}
private enum WorkloadInspectorTab: String, CaseIterable, Identifiable {
    case summary
    case rollout
    case yaml

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summary: return "Summary"
        case .rollout: return "Rollout"
        case .yaml: return "YAML"
        }
    }
}

private struct ResourceInspector: View {
    let cluster: Cluster
    let namespace: Namespace?
    let selectedTab: ClusterDetailView.Tab
    let networkFocus: ClusterDetailView.NetworkResourceKind
    let onFocusPods: (WorkloadSummary) -> Void
    let podActions: PodInspectorActions
    @Binding var podTabSelection: PodInspectorTab
    @Binding var workloadTabSelection: WorkloadInspectorTab
    let selection: AppModel.InspectorSelection

    @EnvironmentObject private var model: AppModel

        var body: some View {
            Group {
                if !cluster.isConnected {
                    placeholder(
                        title: "Cluster Disconnected",
                        message: "Connect to inspect resource details."
                    )
                } else {
                    inspectorContent
                }
            }
        }

        @ViewBuilder
        private var inspectorContent: some View {
            switch selection {
            case .none:
                placeholder(title: "No Selection", message: defaultPrompt)

            case let .workload(_, namespaceID, workloadID):
                if let namespace = namespace(for: namespaceID) ?? namespaceForWorkloadID(workloadID),
                   let workload = namespace.workloads.first(where: { $0.id == workloadID }) {
                    WorkloadInspectorView(
                        cluster: cluster,
                        namespace: namespace,
                        workload: workload,
                        pods: podsMatching(workload: workload, namespace: namespace),
                        tab: $workloadTabSelection,
                        onFocusPods: onFocusPods,
                        onSelectPod: { pod in
                            podTabSelection = .summary
                            model.setInspectorSelection(
                                .pod(
                                    clusterID: cluster.id,
                                    namespaceID: namespaceForPodID(pod.id)?.id ?? namespace.id,
                                    podID: pod.id
                                )
                            )
                        }
                    )
                    .environmentObject(model)
                } else {
                    placeholder(title: "Workload Unavailable", message: "The selected workload is no longer present.")
                }

            case let .pod(_, namespaceID, podID):
                if let namespace = namespace(for: namespaceID) ?? namespaceForPodID(podID),
                   let pod = namespace.pods.first(where: { $0.id == podID }) {
                    PodInspectorView(
                        cluster: cluster,
                        namespace: namespace,
                        pod: pod,
                        tab: $podTabSelection,
                        actions: podActions
                    )
                    .environmentObject(model)
                } else {
                    placeholder(title: "Pod Unavailable", message: "The selected pod may have terminated.")
                }

            case let .helm(_, releaseID):
                if let release = cluster.helmReleases.first(where: { $0.id == releaseID }) {
                    ScrollView {
                        HelmInspectorView(release: release)
                            .padding(16)
                    }
                } else {
                    placeholder(title: "Release Unavailable", message: "Refresh Helm releases to continue.")
                }

            case let .service(_, namespaceID, serviceID):
                if let namespace = namespace(for: namespaceID),
                   let service = namespace.services.first(where: { $0.id == serviceID }) {
                    ScrollView {
                        ServiceInspectorView(namespace: namespace, service: service)
                            .padding(16)
                    }
                } else {
                    placeholder(title: "Service Unavailable", message: "Select another service.")
                }

            case let .ingress(_, namespaceID, ingressID):
                if let namespace = namespace(for: namespaceID),
                   let ingress = namespace.ingresses.first(where: { $0.id == ingressID }) {
                    ScrollView {
                        IngressInspectorView(namespace: namespace, ingress: ingress)
                            .padding(16)
                    }
                } else {
                    placeholder(title: "Ingress Unavailable", message: "Select another ingress.")
                }

            case let .persistentVolumeClaim(_, namespaceID, claimID):
                if let namespace = namespace(for: namespaceID),
                   let claim = namespace.persistentVolumeClaims.first(where: { $0.id == claimID }) {
                    ScrollView {
                        PersistentVolumeClaimInspectorView(namespace: namespace, claim: claim)
                            .padding(16)
                    }
                } else {
                    placeholder(title: "PersistentVolumeClaim Unavailable", message: "Select another claim.")
                }
            }
        }

        private func namespace(for id: Namespace.ID) -> Namespace? {
            if let namespace, namespace.id == id { return namespace }
            return cluster.namespaces.first(where: { $0.id == id })
        }

        private func placeholder(title: String, message: String) -> some View {
            centeredUnavailableView(
                title,
                systemImage: "rectangle.dashed",
                description: Text(message)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }

        private var defaultPrompt: String {
            switch selectedTab {
            case .helmReleases:
                return "Select a Helm release to preview metadata."
            case .helmRepositories:
                return "Helm repositories will appear here soon."
            case .networkServices,
                 .networkEndpoints,
                 .networkIngresses,
                 .networkPolicies,
                 .networkLoadBalancers,
                 .networkPortForwards:
                switch networkFocus {
                case .services:
                    return "Select a service to view endpoints and ports."
                case .endpoints:
                    return "Review endpoints to verify service-to-pod mappings."
                case .ingresses:
                    return "Select an ingress to inspect host rules."
                case .networkPolicies:
                    return "Inspect network policies controlling pod traffic."
                case .loadBalancers:
                    return "Select a load balancer to review external endpoints."
                case .portForwards:
                    return "Review active port forwards or start a new session from the pod inspector."
                }
            case .storagePersistentVolumeClaims:
                return "Select a persistent volume claim to view capacity and binding details."
            case .storagePersistentVolumes:
                return "Persistent volumes summary coming soon."
            case .storageStorageClasses:
                return "Storage class coverage is coming soon."
            case .workloadsPods:
                return "Select a pod to inspect status, metrics, and events."
            case .applications, .workloadsOverview, .workloadsDeployments, .workloadsDaemonSets, .workloadsStatefulSets, .workloadsReplicaSets, .workloadsReplicationControllers, .workloadsJobs, .workloadsCronJobs:
                return "Select a workload to inspect its details below."
            default:
                return "Choose a resource from the list to see its details."
            }
        }

        private func namespaceForWorkloadID(_ id: WorkloadSummary.ID) -> Namespace? {
            if let namespace, namespace.id != AppModel.allNamespacesNamespaceID,
               namespace.workloads.contains(where: { $0.id == id }) {
                return namespace
            }
            return cluster.namespaces.first(where: { $0.workloads.contains { $0.id == id } })
        }

        private func namespaceForPodID(_ id: PodSummary.ID) -> Namespace? {
            if let namespace, namespace.id != AppModel.allNamespacesNamespaceID,
               namespace.pods.contains(where: { $0.id == id }) {
                return namespace
            }
            return cluster.namespaces.first(where: { $0.pods.contains { $0.id == id } })
        }
    }

    private struct InspectorField: View {
        let label: String
        var value: String
        var valueColor: Color? = nil
        var monospaced: Bool = false
        var lineLimit: Int? = nil

        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                valueView
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        @ViewBuilder
        private var valueView: some View {
            let base = Text(value)
                .font(monospaced ? .system(.body, design: .monospaced) : .body)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.leading)
            if let valueColor {
                base.foregroundStyle(valueColor)
            } else {
                base
            }
        }
    }

    private struct InspectorSection<Content: View>: View {
        let title: String
        @ViewBuilder var content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private struct HelmInspectorView: View {
        let release: HelmRelease

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                InspectorSection(title: "Helm Release") {
                    InspectorField(label: "Name", value: release.name)
                    InspectorField(label: "Namespace", value: release.namespace)
                    InspectorField(label: "Status", value: release.status.capitalized, valueColor: release.statusColor)
                }

                InspectorSection(title: "Revision & Chart") {
                    InspectorField(label: "Revision", value: "\(release.revision)")
                    InspectorField(label: "Chart", value: release.chart)
                    InspectorField(label: "App Version", value: release.appVersion ?? "—")
                }

                InspectorSection(title: "Last Updated") {
                    InspectorField(label: "Updated", value: release.updatedDisplay)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private struct ServiceInspectorView: View {
        let namespace: Namespace
        let service: ServiceSummary

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                InspectorSection(title: "Service") {
                    InspectorField(label: "Name", value: service.name)
                    InspectorField(label: "Namespace", value: namespace.name)
                    InspectorField(label: "Type", value: service.type)
                }

                InspectorSection(title: "Networking") {
                    InspectorField(label: "Cluster IP", value: service.clusterIP)
                    InspectorField(label: "Ports", value: service.ports.isEmpty ? "—" : service.ports)
                }

                InspectorSection(title: "Traffic") {
                    InspectorField(
                        label: "Endpoint Health",
                        value: service.totalEndpointCount > 0 ? service.endpointHealthDisplay : "—",
                        valueColor: service.totalEndpointCount > 0 ? service.healthState.tint : .secondary,
                        monospaced: true
                    )
                    InspectorField(label: "Latency p50", value: formatLatency(service.latencyP50))
                    InspectorField(label: "Latency p95", value: formatLatency(service.latencyP95))
                }

                if !service.readyPods.isEmpty || !service.notReadyPods.isEmpty {
                    InspectorSection(title: "Endpoints") {
                        if !service.readyPods.isEmpty {
                            InspectorField(label: "Ready", value: service.readyPods.joined(separator: ", "), lineLimit: 3)
                        }
                        if !service.notReadyPods.isEmpty {
                            InspectorField(label: "Not Ready", value: service.notReadyPods.joined(separator: ", "), valueColor: Color.orange, lineLimit: 3)
                        }
                    }
                }

                InspectorSection(title: "Age") {
                    InspectorField(label: "Created", value: service.age?.displayText ?? "—")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private func formatLatency(_ latency: TimeInterval?) -> String {
            guard let latency else { return "—" }
            if latency >= 1 {
                return latency.formatted(.number.precision(.fractionLength(2))) + "s"
            } else {
                let milliseconds = latency * 1_000
                return milliseconds.formatted(.number.precision(.fractionLength(0...1))) + "ms"
            }
        }
    }

    private struct IngressInspectorView: View {
        let namespace: Namespace
        let ingress: IngressSummary

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                InspectorSection(title: "Ingress") {
                    InspectorField(label: "Name", value: ingress.name)
                    InspectorField(label: "Namespace", value: namespace.name)
                    InspectorField(label: "Class", value: ingress.className ?? "—")
                    InspectorField(label: "TLS", value: ingress.tls ? "Enabled" : "Disabled", valueColor: ingress.tls ? Color.green : .secondary)
                }

                InspectorSection(title: "Routing") {
                    InspectorField(label: "Hosts", value: ingress.hostRules.isEmpty ? "—" : ingress.hostRules)
                    InspectorField(label: "Service Targets", value: ingress.serviceTargets.isEmpty ? "—" : ingress.serviceTargets)
                }

                if !ingress.routes.isEmpty {
                    InspectorSection(title: "Routes") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(ingress.routes) { route in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(route.host)
                                        .font(.caption.monospaced())
                                    Image(systemName: "arrow.right")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(route.path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(route.service)
                                        .font(.caption.monospaced())
                                    if let port = route.port {
                                        Text(":\(port)")
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color(nsColor: .underPageBackgroundColor))
                                )
                            }
                        }
                    }
                }

                InspectorSection(title: "Age") {
                    InspectorField(label: "Created", value: ingress.age?.displayText ?? "—")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private struct PersistentVolumeClaimInspectorView: View {
        let namespace: Namespace
        let claim: PersistentVolumeClaimSummary

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                InspectorSection(title: "Persistent Volume Claim") {
                    InspectorField(label: "Name", value: claim.name)
                    InspectorField(label: "Namespace", value: namespace.name)
                    InspectorField(label: "Status", value: claim.status)
                }

                InspectorSection(title: "Capacity & Storage") {
                    InspectorField(label: "Capacity", value: claim.capacity ?? "—")
                    InspectorField(label: "Storage Class", value: claim.storageClass ?? "—")
                    InspectorField(label: "Volume", value: claim.volumeName ?? "—")
                }

                InspectorSection(title: "Age") {
                    InspectorField(label: "Created", value: claim.age?.displayText ?? "—")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var namespaceToolbar: some View {
        if !cluster.isConnected {
            HStack {
                Text("Cluster is disconnected. Connect to explore resources.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        } else {
            let namespaces = model.currentNamespaces ?? []
            if namespaces.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading namespaces…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            } else {
                let namespaceBinding = Binding<Namespace.ID> {
                    if let current = model.selectedNamespaceID,
                       namespaces.contains(where: { $0.id == current }) {
                        return current
                    }
                    let fallback = namespaces.first!.id
                    DispatchQueue.main.async {
                        model.selectedNamespaceID = fallback
                        if let selection = namespaces.first(where: { $0.id == fallback }) {
                            if selection.id == AppModel.allNamespacesNamespaceID {
                                Task {
                                    await model.ensureAllNamespacesLoaded(clusterID: cluster.id, contextName: cluster.contextName)
                                }
                            } else {
                                Task {
                                    await model.loadNamespaceIfNeeded(clusterID: cluster.id, namespaceName: selection.name)
                                }
                            }
                        }
                    }
                    return fallback
                } set: { newValue in
                    model.selectedNamespaceID = newValue
                    if let selection = namespaces.first(where: { $0.id == newValue }) {
                        if selection.id == AppModel.allNamespacesNamespaceID {
                            Task {
                                await model.ensureAllNamespacesLoaded(clusterID: cluster.id, contextName: cluster.contextName)
                            }
                        } else {
                            Task {
                                await model.loadNamespaceIfNeeded(clusterID: cluster.id, namespaceName: selection.name)
                            }
                        }
                    }
                }

                HStack(spacing: 16) {
                    Picker("Namespace", selection: namespaceBinding) {
                        ForEach(namespaces) { namespace in
                            Text(namespace.name)
                                .tag(namespace.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 220)

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder
    private var resourceContent: some View {
        switch selectedTab {
        case .overview:
            OverviewSection(cluster: cluster, namespace: namespace)
        case .nodes:
            NodesSection(
                cluster: cluster,
                sortOption: nodeSortBinding,
                filterState: model.nodeFilterState,
                isNodeBusy: { model.isNodeActionInProgress(contextName: cluster.contextName, nodeName: $0.name) },
                nodeActionError: { model.nodeActionError(contextName: cluster.contextName, nodeName: $0.name) },
                onShowDetails: { handleNodeDetails($0) },
                onShell: { handleNodeShell($0) },
                onCordon: { handleNodeCordon($0) },
                onDrain: { handleNodeDrain($0) },
                onEdit: { handleNodeEdit($0) },
                onDelete: { handleNodeDelete($0) }
            )
        case .configConfigMaps,
             .configSecrets,
             .configResourceQuotas,
             .configLimitRanges,
             .configHPAs,
             .configPodDisruptionBudgets,
             .helmReleases,
             .helmRepositories,
             .networkServices,
             .networkEndpoints,
             .networkIngresses,
             .networkPolicies,
             .networkLoadBalancers,
             .networkPortForwards,
             .storagePersistentVolumeClaims,
             .storagePersistentVolumes,
             .storageStorageClasses:
            EmptyView()
        case .namespaces:
            let namespaces = model.currentNamespaces ?? []
            NamespacesSection(
                isConnected: cluster.isConnected,
                namespaces: namespaces,
                selectedNamespaceID: model.selectedNamespaceID
            ) { namespace in
                model.selectedNamespaceID = namespace.id
                if namespace.id == AppModel.allNamespacesNamespaceID {
                    Task {
                        await model.ensureAllNamespacesLoaded(clusterID: cluster.id, contextName: cluster.contextName)
                    }
                } else {
                    Task {
                        await model.loadNamespaceIfNeeded(clusterID: cluster.id, namespaceName: namespace.name)
                    }
                }
            }
        case .events:
            EventsSection(namespace: namespace, isConnected: isConnected)
        case .accessControl:
            AccessControlSection(namespace: namespace, isConnected: isConnected)
        case .customResources:
            CustomResourcesSection(cluster: cluster, isConnected: isConnected)
        default:
            EmptyView()
        }
    }
}

extension ClusterDetailView {
    private func syncInspectorSelection() {
        guard cluster.isConnected else {
            model.clearInspectorSelection()
            return
        }

        switch selectedTab {
        case .applications, .workloadsOverview, .workloadsDeployments, .workloadsDaemonSets, .workloadsStatefulSets, .workloadsReplicaSets, .workloadsReplicationControllers, .workloadsJobs, .workloadsCronJobs:
            guard let workloadID = selectedWorkloadIDs.first,
                  let targetNamespace = namespace(forWorkloadID: workloadID) else {
                model.clearInspectorSelection()
                workloadInspectorTab = .summary
                return
            }
            model.setInspectorSelection(
                .workload(
                    clusterID: cluster.id,
                    namespaceID: targetNamespace.id,
                    workloadID: workloadID
                )
            )

        case .workloadsPods:
            guard let podID = selectedPodIDs.first ?? selectedPodID,
                  let targetNamespace = namespace(forPodID: podID) else {
                model.clearInspectorSelection()
                podInspectorTab = .summary
                return
            }
            model.setInspectorSelection(
                .pod(
                    clusterID: cluster.id,
                    namespaceID: targetNamespace.id,
                    podID: podID
                )
            )

        case .helmReleases:
            guard let releaseID = selectedHelmIDs.first else {
                model.clearInspectorSelection()
                return
            }
            model.setInspectorSelection(.helm(clusterID: cluster.id, releaseID: releaseID))
        case .helmRepositories:
            model.clearInspectorSelection()

        case .networkServices, .networkEndpoints, .networkIngresses, .networkPolicies, .networkLoadBalancers, .networkPortForwards:
            guard let namespace, let focus = currentNetworkFocus else {
                model.clearInspectorSelection()
                return
            }
            switch focus {
            case .services:
                guard let serviceID = selectedServiceIDs.first else {
                    model.clearInspectorSelection()
                    return
                }
                model.setInspectorSelection(
                    .service(
                        clusterID: cluster.id,
                        namespaceID: namespace.id,
                        serviceID: serviceID
                    )
                )
            case .endpoints:
                model.clearInspectorSelection()
            case .ingresses:
                guard let ingressID = selectedIngressIDs.first else {
                    model.clearInspectorSelection()
                    return
                }
                model.setInspectorSelection(
                    .ingress(
                        clusterID: cluster.id,
                        namespaceID: namespace.id,
                        ingressID: ingressID
                    )
                )
            case .networkPolicies:
                model.clearInspectorSelection()
            case .loadBalancers:
                guard let serviceID = selectedServiceIDs.first else {
                    model.clearInspectorSelection()
                    return
                }
                model.setInspectorSelection(
                    .service(
                        clusterID: cluster.id,
                        namespaceID: namespace.id,
                        serviceID: serviceID
                    )
                )
            case .portForwards:
                model.clearInspectorSelection()
            }

        case .storagePersistentVolumeClaims:
            guard let namespace, let claimID = selectedPVCIDs.first else {
                model.clearInspectorSelection()
                return
            }
            model.setInspectorSelection(
                .persistentVolumeClaim(
                    clusterID: cluster.id,
                    namespaceID: namespace.id,
                    claimID: claimID
                )
            )

        case .storagePersistentVolumes,
             .storageStorageClasses:
            model.clearInspectorSelection()

        default:
            model.clearInspectorSelection()
            podInspectorTab = .summary
            workloadInspectorTab = .summary
        }
    }

    private func handleShowDetails(_ pod: PodSummary) {
        focusPod(pod, tab: .summary)
    }

    private func handleWorkloadSelection(_ workload: WorkloadSummary) {
        focusWorkload(workload, tab: .summary)
    }

    private func handleShell(_ pod: PodSummary) {
        guard let sourceNamespace = namespace(forPod: pod), sourceNamespace.permissions.canExecPods else {
            let reason = namespace(forPod: pod)?.permissions.reason(for: .execPods) ?? "You do not have permission to exec into pods in this namespace."
            model.error = AppModelError(message: reason)
            return
        }
        focusPod(pod, tab: .exec)
    }

    private func handleEvict(_ pod: PodSummary) {
        guard let sourceNamespace = namespace(forPod: pod), sourceNamespace.permissions.canDeletePods else {
            let reason = namespace(forPod: pod)?.permissions.reason(for: .deletePods) ?? "You do not have permission to evict pods in this namespace."
            model.error = AppModelError(message: reason)
            return
        }
        model.selectedNamespaceID = sourceNamespace.id
        selectedTab = .workloadsPods
        selectedPodIDs = Set([pod.id])
        selectedPodID = pod.id
        Task {
            await model.deletePod(cluster: cluster, namespace: sourceNamespace, pod: pod, force: true)
        }
    }

    private func handleLogs(_ pod: PodSummary) {
        guard let sourceNamespace = namespace(forPod: pod), sourceNamespace.permissions.canViewPodLogs else {
            let reason = namespace(forPod: pod)?.permissions.reason(for: .viewPodLogs) ?? "You do not have permission to view pod logs in this namespace."
            model.error = AppModelError(message: reason)
            return
        }
        focusPod(pod, tab: .logs)
    }

    private func handleEdit(_ pod: PodSummary) {
        guard let sourceNamespace = namespace(forPod: pod), sourceNamespace.permissions.canGetPods else {
            let reason = namespace(forPod: pod)?.permissions.reason(for: .getPods) ?? "You do not have permission to fetch pod manifests in this namespace."
            model.error = AppModelError(message: reason)
            return
        }
        focusPod(pod, tab: .yaml)
    }

    private func selectNodeSort(field: NodeSortField) {
        if model.nodeSortOption.field == field {
            model.nodeSortOption.toggleDirection()
        } else {
            model.nodeSortOption = NodeSortOption(field: field, direction: .ascending)
        }
    }

    private func selectWorkloadSort(field: WorkloadSortField) {
        if model.workloadSortOption.field == field {
            model.workloadSortOption.toggleDirection()
        } else {
            model.workloadSortOption = WorkloadSortOption(field: field, direction: .ascending)
        }
    }

    private func handleDelete(_ pod: PodSummary) {
        guard let sourceNamespace = namespace(forPod: pod), sourceNamespace.permissions.canDeletePods else {
            let reason = namespace(forPod: pod)?.permissions.reason(for: .deletePods) ?? "You do not have permission to delete pods in this namespace."
            model.error = AppModelError(message: reason)
            return
        }
        model.selectedNamespaceID = sourceNamespace.id
        selectedTab = .workloadsPods
        selectedPodIDs = Set([pod.id])
        selectedPodID = pod.id
        Task {
            await model.deletePod(cluster: cluster, namespace: sourceNamespace, pod: pod, force: false)
        }
    }

    private func handlePortForward(_ pod: PodSummary) {
        guard let sourceNamespace = namespace(forPod: pod), sourceNamespace.permissions.canPortForwardPods else {
            let reason = namespace(forPod: pod)?.permissions.reason(for: .portForwardPods) ?? "You do not have permission to port-forward pods in this namespace."
            model.error = AppModelError(message: reason)
            return
        }
        model.selectedNamespaceID = sourceNamespace.id
        selectedTab = .workloadsPods
        selectedPodIDs = [pod.id]
        selectedPodID = pod.id
        showingPortForward = true
    }

    private func servicePermissions(for service: ServiceSummary) -> NamespacePermissions? {
        namespace(forService: service)?.permissions
    }

    private func pvcPermissions(for claim: PersistentVolumeClaimSummary) -> NamespacePermissions? {
        namespace(forPVC: claim)?.permissions
    }

    private func handleServiceInspect(_ service: ServiceSummary) {
        guard let sourceNamespace = namespace(forService: service) else { return }
        model.selectedNamespaceID = sourceNamespace.id
        selectedTab = .networkServices
        selectedServiceIDs = [service.id]
        syncInspectorSelection()
    }

    private func handleServiceEdit(_ service: ServiceSummary) {
        guard let sourceNamespace = namespace(forService: service) else { return }
        guard sourceNamespace.permissions.canEditServices else {
            let reason = sourceNamespace.permissions.reason(for: .editServices) ?? "You do not have permission to edit services in this namespace."
            model.error = AppModelError(message: reason)
            return
        }
        Task {
            await model.editServiceResource(cluster: cluster, namespace: sourceNamespace, service: service)
        }
    }

    private func handleServiceDelete(_ service: ServiceSummary) {
        guard let sourceNamespace = namespace(forService: service) else { return }
        guard sourceNamespace.permissions.canDeleteServices else {
            let reason = sourceNamespace.permissions.reason(for: .deleteServices) ?? "You do not have permission to delete services in this namespace."
            model.error = AppModelError(message: reason)
            return
        }
        Task {
            await model.deleteServiceResource(cluster: cluster, namespace: sourceNamespace, service: service)
        }
    }

    private func handlePVCInspect(_ claim: PersistentVolumeClaimSummary) {
        guard let sourceNamespace = namespace(forPVC: claim) else { return }
        model.selectedNamespaceID = sourceNamespace.id
        selectedTab = .storagePersistentVolumeClaims
        selectedPVCIDs = [claim.id]
        syncInspectorSelection()
    }

    private func handlePVCEdit(_ claim: PersistentVolumeClaimSummary) {
        guard let sourceNamespace = namespace(forPVC: claim) else { return }
        guard sourceNamespace.permissions.canEditPersistentVolumeClaims else {
            let reason = sourceNamespace.permissions.reason(for: .editPersistentVolumeClaims) ?? "You do not have permission to edit persistent volume claims in this namespace."
            model.error = AppModelError(message: reason)
            return
        }
        Task {
            await model.editPersistentVolumeClaim(cluster: cluster, namespace: sourceNamespace, claim: claim)
        }
    }

    private func handlePVCDelete(_ claim: PersistentVolumeClaimSummary) {
        guard let sourceNamespace = namespace(forPVC: claim) else { return }
        guard sourceNamespace.permissions.canDeletePersistentVolumeClaims else {
            let reason = sourceNamespace.permissions.reason(for: .deletePersistentVolumeClaims) ?? "You do not have permission to delete persistent volume claims in this namespace."
            model.error = AppModelError(message: reason)
            return
        }
        Task {
            await model.deletePersistentVolumeClaim(cluster: cluster, namespace: sourceNamespace, claim: claim)
        }
    }

    private func focusPod(_ pod: PodSummary, tab: PodInspectorTab) {
        guard let sourceNamespace = namespace(forPod: pod) else { return }
        podInspectorTab = tab
        selectedTab = .workloadsPods
        model.setInspectorSelection(
            .pod(
                clusterID: cluster.id,
                namespaceID: sourceNamespace.id,
                podID: pod.id
            )
        )

        let needsNamespaceSwitch = namespace?.id != sourceNamespace.id
        if needsNamespaceSwitch {
            pendingPodFocus = PendingPodFocus(namespaceID: sourceNamespace.id, podID: pod.id, tabValue: tab.rawValue)
        } else {
            pendingPodFocus = nil
        }

        model.selectedNamespaceID = sourceNamespace.id

        if !needsNamespaceSwitch {
            selectedPodIDs = [pod.id]
            selectedPodID = pod.id
            syncInspectorSelection()
        } else {
            Task { @MainActor in
                _ = await model.loadNamespaceIfNeeded(clusterID: cluster.id, namespaceName: sourceNamespace.name)
                applyPendingPodFocusIfPossible()
            }
        }
    }

    private func applyPendingPodFocusIfPossible() {
        guard let pending = pendingPodFocus else { return }
        let candidateNamespace: Namespace? = {
            if let namespace, namespace.id == pending.namespaceID {
                return namespace
            }
            return cluster.namespaces.first(where: { $0.id == pending.namespaceID })
        }()

        guard let targetNamespace = candidateNamespace else { return }
        guard targetNamespace.pods.contains(where: { $0.id == pending.podID }) else { return }

        selectedPodIDs = [pending.podID]
        selectedPodID = pending.podID
        podInspectorTab = pending.resolvedTab()
        model.setInspectorSelection(
            .pod(
                clusterID: cluster.id,
                namespaceID: targetNamespace.id,
                podID: pending.podID
            )
        )
        syncInspectorSelection()
        pendingPodFocus = nil
    }

    private func closeInspector() {
        pendingPodFocus = nil
        selectedPodID = nil
        selectedPodIDs.removeAll()
        selectedWorkloadIDs.removeAll()
        selectedServiceIDs.removeAll()
        selectedIngressIDs.removeAll()
        selectedPVCIDs.removeAll()
        selectedHelmIDs.removeAll()
        model.clearInspectorSelection()
    }

    private func focusWorkload(_ workload: WorkloadSummary, tab: WorkloadInspectorTab) {
        if let sourceNamespace = namespace(forWorkload: workload) {
            model.selectedNamespaceID = sourceNamespace.id
        }
        selectedWorkloadIDs = [workload.id]
        workloadInspectorTab = tab
        syncInspectorSelection()
    }

    private func handleNodeDetails(_ node: NodeInfo) {
        detailNode = node
    }

    private func handleNodeShell(_ node: NodeInfo) {
        Task { await model.openNodeShell(cluster: cluster, node: node) }
    }

    private func handleNodeCordon(_ node: NodeInfo) {
        Task { await model.cordonNode(cluster: cluster, node: node) }
    }

    private func handleNodeDrain(_ node: NodeInfo) {
        Task { await model.drainNode(cluster: cluster, node: node) }
    }

    private func handleNodeEdit(_ node: NodeInfo) {
        Task { await model.editNode(cluster: cluster, node: node) }
    }

    private func handleNodeDelete(_ node: NodeInfo) {
        Task { await model.deleteNode(cluster: cluster, node: node) }
    }

    private func focusPods(for workload: WorkloadSummary) {
        guard let sourceNamespace = namespace(forWorkload: workload) else { return }
        model.selectedNamespaceID = sourceNamespace.id
        let matching = podsMatching(workload: workload, namespace: sourceNamespace)
        guard !matching.isEmpty else { return }
        selectedTab = .workloadsPods
        selectedPodIDs = Set(matching.map { $0.id })
        selectedPodID = matching.first?.id
        syncInspectorSelection()
    }

}

private func podsMatching(workload: WorkloadSummary, namespace: Namespace) -> [PodSummary] {
    namespace.pods.filter { podBelongs(to: workload, pod: $0) }
}

private func podBelongs(to workload: WorkloadSummary, pod: PodSummary) -> Bool {
    guard let controller = pod.controlledBy?.lowercased() else { return false }
    let name = workload.name.lowercased()

    switch workload.kind {
    case .deployment:
        if controller == "deployment/\(name)" { return true }
        if controller.hasPrefix("replicaset/") {
            if let replica = controller.split(separator: "/").last {
                return replica.lowercased().hasPrefix(name + "-")
            }
        }
        return false
    case .statefulSet:
        return controller == "statefulset/\(name)"
    case .daemonSet:
        return controller == "daemonset/\(name)"
    case .replicaSet:
        return controller == "replicaset/\(name)"
    case .replicationController:
        return controller == "replicationcontroller/\(name)" || pod.name.lowercased().hasPrefix(name)
    case .job:
        return controller == "job/\(name)"
    case .cronJob:
        if controller == "cronjob/\(name)" { return true }
        if controller.hasPrefix("job/") {
            if let jobName = controller.split(separator: "/").last {
                return jobName.lowercased().hasPrefix(name)
            }
        }
        return false
    }
}

private extension ClusterDetailView {
    func applyQuickSearchSelection(_ target: AppModel.QuickSearchTarget) {
        resourceSearchText = ""
        pendingQuickSearchTarget = target
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            pendingQuickSearchTarget = nil
        }

        switch target {
        case let .tab(tab):
            selectedTab = tab

        case .namespace:
            selectedTab = .namespaces

        case let .workload(kind, _, workloadID):
            selectedTab = workloadTab(for: kind)
            selectedWorkloadIDs = Set([workloadID])
            workloadInspectorTab = .summary

        case let .pod(_, podID):
            selectedTab = .workloadsPods
            selectedPodIDs = Set([podID])
            selectedPodID = podID
            podInspectorTab = .summary

        case let .node(nodeID):
            selectedTab = .nodes
            detailNode = cluster.nodes.first(where: { $0.id == nodeID })

        case let .helm(releaseID):
            selectedTab = .helmReleases
            selectedHelmIDs = Set([releaseID])

        case let .service(_, serviceID):
            selectedTab = .networkServices
            selectedServiceIDs = Set([serviceID])
            selectedIngressIDs.removeAll()

        case let .ingress(_, ingressID):
            selectedTab = .networkIngresses
            selectedIngressIDs = Set([ingressID])
            selectedServiceIDs.removeAll()

        case let .persistentVolumeClaim(_, claimID):
            selectedTab = .storagePersistentVolumeClaims
            selectedPVCIDs = Set([claimID])

        case let .configResource(kind, _, _):
            selectedTab = configTab(for: kind)
        }
    }

    func workloadTab(for kind: WorkloadKind) -> ClusterDetailView.Tab {
        switch kind {
        case .deployment: return .workloadsDeployments
        case .statefulSet: return .workloadsStatefulSets
        case .daemonSet: return .workloadsDaemonSets
        case .cronJob: return .workloadsCronJobs
        case .replicaSet: return .workloadsReplicaSets
        case .replicationController: return .workloadsReplicationControllers
        case .job: return .workloadsJobs
        }
    }

    func configTab(for kind: ConfigResourceKind) -> ClusterDetailView.Tab {
        switch kind {
        case .configMap: return .configConfigMaps
        case .secret: return .configSecrets
        case .resourceQuota: return .configResourceQuotas
        case .limitRange: return .configLimitRanges
        }
    }

    func namespace(forWorkload workload: WorkloadSummary) -> Namespace? {
        if let namespace, namespace.id != AppModel.allNamespacesNamespaceID {
            return namespace
        }
        return cluster.namespaces.first(where: { ns in
            ns.workloads.contains { $0.id == workload.id }
        })
    }

    func namespace(forWorkloadID workloadID: WorkloadSummary.ID) -> Namespace? {
        if let namespace, namespace.id != AppModel.allNamespacesNamespaceID,
           namespace.workloads.contains(where: { $0.id == workloadID }) {
            return namespace
        }
        return cluster.namespaces.first(where: { ns in
            ns.workloads.contains { $0.id == workloadID }
        })
    }

    func namespace(forPod pod: PodSummary) -> Namespace? {
        if let namespace, namespace.id != AppModel.allNamespacesNamespaceID {
            return namespace
        }
        if let byName = cluster.namespaces.first(where: { $0.name == pod.namespace }) {
            return byName
        }
        return cluster.namespaces.first(where: { ns in
            ns.pods.contains { $0.id == pod.id }
        })
    }

    func namespace(forPodID podID: PodSummary.ID) -> Namespace? {
        if let namespace, namespace.id != AppModel.allNamespacesNamespaceID,
           namespace.pods.contains(where: { $0.id == podID }) {
            return namespace
        }
        return cluster.namespaces.first(where: { ns in
            ns.pods.contains { $0.id == podID }
        })
    }

    func namespace(forService service: ServiceSummary) -> Namespace? {
        if let namespace,
           namespace.id != AppModel.allNamespacesNamespaceID,
           namespace.services.contains(where: { $0.id == service.id }) {
            return namespace
        }
        return cluster.namespaces.first(where: { ns in
            ns.services.contains { $0.id == service.id }
        })
    }

    func namespace(forPVC claim: PersistentVolumeClaimSummary) -> Namespace? {
        if let namespace,
           namespace.id != AppModel.allNamespacesNamespaceID,
           namespace.persistentVolumeClaims.contains(where: { $0.id == claim.id }) {
            return namespace
        }
        return cluster.namespaces.first(where: { ns in
            ns.persistentVolumeClaims.contains { $0.id == claim.id }
        })
    }
}

enum DetailPresentationStyle {
    case sheet
    case inspector
}

private struct PodDetailSheetView: View {
    enum LoadState {
        case loading
        case loaded(PodDetailData)
        case failed(String)
    }

    let cluster: Cluster
    let namespace: Namespace
    let pod: PodSummary
    let events: [EventSummary]
    let presentation: DetailPresentationStyle
    private let closeAction: (() -> Void)?

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var loadState: LoadState = .loading

    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    init(
        cluster: Cluster,
        namespace: Namespace,
        pod: PodSummary,
        events: [EventSummary],
        presentation: DetailPresentationStyle = .sheet,
        onClose: (() -> Void)? = nil
    ) {
        self.cluster = cluster
        self.namespace = namespace
        self.pod = pod
        self.events = events
        self.presentation = presentation
        self.closeAction = onClose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            content
        }
        .padding(presentation == .sheet ? 24 : 16)
        .frame(
            minWidth: presentation == .sheet ? 820 : nil,
            maxWidth: .infinity,
            minHeight: presentation == .sheet ? 520 : nil,
            alignment: .topLeading
        )
        .onAppear(perform: load)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pod · \(pod.name)")
                    .font(.title3.bold())
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(cluster.name) · Namespace \(namespace.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if presentation == .sheet {
                Button("Close") { close() }
                    .keyboardShortcut(.cancelAction)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading pod details…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

        case .failed(let message):
            VStack(spacing: 12) {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.leading)
                Button("Retry", action: load)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

        case .loaded(let detail):
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    metricsSection
                    propertiesSection(detail)
                    statusSection(detail)
                    volumeSection(detail)
                    initContainerSection(detail)
                    containersSection(title: "Containers", containers: detail.containers)
                    eventsSection()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var metricsSection: some View {
        SectionBox(title: "Metrics") {
            Text("Charts powered by Prometheus (monitoring/prometheus-operated:9090) coming soon.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func propertiesSection(_ detail: PodDetailData) -> some View {
        SectionBox(title: "Properties") {
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(label: "Created", value: createdString(from: detail.createdAt))
                DetailRow(label: "Name", value: detail.name)
                DetailRow(label: "Namespace", value: detail.namespace)
                keyValueGroup(title: "Labels", values: detail.labels)
                keyValueGroup(title: "Annotations", values: detail.annotations)
                DetailRow(label: "Controlled By", value: detail.controlledBy ?? "—")
            }
        }
    }

    private func statusSection(_ detail: PodDetailData) -> some View {
        SectionBox(title: "Status") {
            VStack(alignment: .leading, spacing: 10) {
                DetailRow(label: "Phase", value: detail.status)
                DetailRow(label: "Node", value: detail.nodeName)
                DetailRow(label: "Pod IP", value: formattedIPs(detail.podIP, extra: detail.podIPs))
                DetailRow(label: "Service Account", value: detail.serviceAccount ?? "—")
                DetailRow(label: "QoS Class", value: detail.qosClass ?? "—")

                if !detail.conditions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Conditions")
                            .font(.caption.bold())
                        ForEach(detail.conditions, id: \.type) { condition in
                            Text("• \(condition.type): \(condition.status)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !detail.tolerations.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tolerations (\(detail.tolerations.count))")
                            .font(.caption.bold())
                        ForEach(detail.tolerations.indices, id: \.self) { index in
                            let toleration = detail.tolerations[index]
                            Text("• \(tolerationDescription(toleration))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func volumeSection(_ detail: PodDetailData) -> some View {
        SectionBox(title: "Pod Volumes (\(detail.volumes.count))") {
            if detail.volumes.isEmpty {
                Text("No volumes declared")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(detail.volumes.indices, id: \.self) { index in
                    let volume = detail.volumes[index]
                    DetailRow(label: volume.name, value: volume.type)
                }
            }
        }
    }

    private func initContainerSection(_ detail: PodDetailData) -> some View {
        SectionBox(title: "Init Containers (\(detail.initContainers.count))") {
            if detail.initContainers.isEmpty {
                Text("No init containers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                containersList(detail.initContainers)
            }
        }
    }

    private func containersSection(title: String, containers: [ContainerDetail]) -> some View {
        SectionBox(title: "\(title) (\(containers.count))") {
            if containers.isEmpty {
                Text("None")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                containersList(containers)
            }
        }
    }

    private func containersList(_ containers: [ContainerDetail]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(containers, id: \.name) { container in
                ContainerDetailView(detail: container)
                    .padding(12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func eventsSection() -> some View {
        SectionBox(title: "Events") {
            if events.isEmpty {
                Text("No recent events for this pod")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                EventTimelineView(events: events)
            }
        }
    }

    private func close() {
        if let closeAction {
            closeAction()
        } else {
            dismiss()
        }
    }

    private func load() {
        loadState = .loading
        Task {
            let result = await model.fetchPodDetail(cluster: cluster, namespace: namespace, pod: pod)
            await MainActor.run {
                switch result {
                case .success(let detail):
                    loadState = .loaded(detail)
                case .failure(let error):
                    loadState = .failed(error.message)
                }
            }
        }
    }

    private func createdString(from date: Date?) -> String {
        guard let date else { return "—" }
        let relative = relativeFormatter.localizedString(for: date, relativeTo: Date())
        let formatted = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .medium)
        return "\(relative) · \(formatted)"
    }

    private func formattedIPs(_ primary: String?, extra: [String]) -> String {
        var ips: [String] = []
        if let primary, !primary.isEmpty { ips.append(primary) }
        ips.append(contentsOf: extra.filter { $0 != primary })
        return ips.isEmpty ? "—" : ips.joined(separator: ", ")
    }

    private func tolerationDescription(_ toleration: PodToleration) -> String {
        var parts: [String] = []
        if let key = toleration.key { parts.append(key) }
        if let op = toleration.operator { parts.append(op) }
        if let value = toleration.value { parts.append(value) }
        if let effect = toleration.effect { parts.append("effect=\(effect)") }
        if let seconds = toleration.tolerationSeconds { parts.append("seconds=\(seconds)") }
        return parts.isEmpty ? "(unspecified)" : parts.joined(separator: " · ")
    }

    private func keyValueGroup(title: String, values: [String: String]) -> some View {
        DisclosureGroup("\(title) (\(values.count))") {
            if values.isEmpty {
                Text("None")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(values.keys).sorted(), id: \.self) { key in
                        if let value = values[key] {
                            Text("\(key)=\(value)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .font(.caption)
    }
}

struct PodLogsPane: View {
    let cluster: Cluster
    let namespace: Namespace
    let pod: PodSummary
    let presentation: DetailPresentationStyle
    var onClose: (() -> Void)? = nil

    @EnvironmentObject private var model: AppModel
    @State private var activeRequest: LogStreamRequest
    @State private var entries: [LogEntry] = []
    @State private var streamTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var selectedContainer: String?

    private var canStreamLogs: Bool {
        cluster.isConnected && namespace.permissions.canViewPodLogs
    }

    private var deniedReason: String? {
        namespace.permissions.reason(for: .viewPodLogs)
    }

    init(
        cluster: Cluster,
        namespace: Namespace,
        pod: PodSummary,
        presentation: DetailPresentationStyle,
        onClose: (() -> Void)? = nil,
        initialRequest: LogStreamRequest? = nil
    ) {
        self.cluster = cluster
        self.namespace = namespace
        self.pod = pod
        self.presentation = presentation
        self.onClose = onClose
        let defaultRequest = LogStreamRequest(
            clusterID: cluster.id,
            contextName: cluster.contextName,
            namespace: namespace.name,
            podName: pod.name,
            containerName: initialRequest?.containerName ?? pod.primaryContainer,
            includeTimestamps: true,
            follow: initialRequest?.follow ?? true
        )
        _activeRequest = State(initialValue: initialRequest ?? defaultRequest)
        _selectedContainer = State(initialValue: defaultRequest.containerName)
    }

    var body: some View {
        Group {
            if canStreamLogs {
                VStack(alignment: .leading, spacing: 12) {
            header
            if pod.containerNames.count > 1 {
                Picker("Container", selection: containerBinding) {
                    Text("All Containers").tag(Optional<String>.none)
                    ForEach(pod.containerNames, id: \.self) { name in
                        Text(name).tag(Optional(name))
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(entries) { entry in
                            Text(entry.formatted)
                                .font(.system(.footnote, design: .monospaced))
                                .textSelection(.enabled)
                                .id(entry.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onChange(of: entries) { _, values in
                    guard let lastID = values.last?.id else { return }
                    withAnimation {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }

            if let errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(errorMessage)
                }
                .font(.caption)
                .foregroundStyle(.red)
            }
                }
            } else {
                centeredUnavailableView(
                    "Logs unavailable",
                    systemImage: "lock",
                    description: Text(deniedReason ?? "Your account lacks permission to read pod logs (pods/log).")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { if canStreamLogs { restartStreaming() } }
        .onDisappear { streamTask?.cancel() }
        .onChange(of: selectedContainer) { _, _ in
            applySelectedContainer()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Logs · \(pod.name)")
                    .font(.headline)
                Text("Namespace \(namespace.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if presentation == .sheet {
                Button("Close") { close() }
                    .keyboardShortcut(.cancelAction)
            }
        }
    }

    private var containerBinding: Binding<String?> {
        Binding(
            get: { selectedContainer },
            set: { selectedContainer = $0 }
        )
    }

    private func applySelectedContainer() {
        var request = activeRequest
        request.containerName = selectedContainer
        activeRequest = request
        restartStreaming()
    }

    private func restartStreaming() {
        guard canStreamLogs else { return }
        streamTask?.cancel()
        entries.removeAll()
        errorMessage = nil

        let request = activeRequest
        streamTask = Task {
            let stream = await MainActor.run { model.makeLogStream(for: request) }
            do {
                for try await event in stream {
                    guard !Task.isCancelled else { break }
                    await MainActor.run {
                        switch event {
                        case .line(let line, let date):
                            entries.append(LogEntry(text: line, timestamp: date))
                        case .truncated:
                            entries.append(LogEntry(text: "--- log truncated ---", timestamp: Date(), isSystem: true))
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            await MainActor.run {
                streamTask = nil
            }
        }
    }

    private func close() {
        if let onClose {
            onClose()
        }
    }

    private struct LogEntry: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let timestamp: Date
        var isSystem: Bool = false

        var formatted: String {
            "[\(LogEntry.formatter.string(from: timestamp))] \(text)"
        }

        private static let formatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter
        }()
    }
}

private struct NodeDetailSheetView: View {
    let node: NodeInfo

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    basics
                    if !node.taints.isEmpty {
                        LabeledContent("Taints") {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(node.taints, id: \.self) { taint in
                                    Text(taint)
                                }
                            }
                        }
                    } else {
                        LabeledContent("Taints") { Text("—") }
                    }
                    LabeledContent("Conditions") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(node.conditions, id: \.self) { condition in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(condition.type): \(condition.status)")
                                        .fontWeight(.semibold)
                                    if let reason = condition.reason, !reason.isEmpty {
                                        Text(reason)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let message = condition.message, !message.isEmpty {
                                        Text(message)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .frame(minWidth: 640, minHeight: 420)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Node · \(node.name)")
                    .font(.title3.bold())
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("Kubelet \(node.kubeletVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
    }

    private var basics: some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent("Warnings") {
                Text(node.warningCount > 0 ? "\(node.warningCount)" : "—")
            }
            LabeledContent("CPU") {
                Text(node.cpuDisplay)
            }
            LabeledContent("Memory") {
                Text(node.memoryDisplay)
            }
            LabeledContent("Disk") {
                Text(node.diskDisplay)
            }
            LabeledContent("Age") {
                Text(node.age?.displayText ?? "—")
            }
        }
    }
}

private struct SecretDetailSheet: View {
    let cluster: Cluster
    let namespace: Namespace
    let secret: ConfigResourceSummary

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var editors: [SecretEntryEditor]
    @State private var isSaving = false

    private var canReveal: Bool { secret.permissions.canReveal }
    private var canEditSecret: Bool { secret.permissions.canEdit }
    private var revealReason: String? { secret.permissions.revealReason }
    private var editReason: String? { secret.permissions.editReason }
    private var pendingDiffs: [SecretDiffSummary] { SecretDiffSummary.compute(original: secret.secretEntries, updated: editors) }
    private var hasPendingChanges: Bool { !pendingDiffs.isEmpty }
    private var actionFeedback: SecretActionFeedback? {
        guard let feedback = model.secretActionFeedback,
              feedback.secretName == secret.name,
              feedback.namespace == namespace.name else { return nil }
        return feedback
    }

    init(cluster: Cluster, namespace: Namespace, secret: ConfigResourceSummary) {
        self.cluster = cluster
        self.namespace = namespace
        self.secret = secret
        _editors = State(initialValue: secret.secretEntries?.map { SecretEntryEditor(entry: $0) } ?? [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            permissionBanner
            if editors.isEmpty {
                centeredUnavailableView(
                    "No Data",
                    systemImage: "lock",
                    description: Text("This secret does not contain any key/value pairs.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach($editors) { $entry in
                            SecretEntryEditorView(
                                entry: $entry,
                                canReveal: canReveal,
                                canEdit: canEditSecret,
                                revealReason: revealReason,
                                editReason: editReason
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if canEditSecret {
                diffPreview
            }
            if let actionFeedback {
                feedbackPanel(actionFeedback)
            }
            Divider()
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving || editors.isEmpty || !canEditSecret || !hasPendingChanges)
                    .optionalHelp(!canEditSecret ? (editReason ?? "Editing disabled by RBAC policy.") : nil)
            }
        }
        .padding(24)
        .frame(minWidth: 600, minHeight: 420)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Secret · \(secret.name)")
                    .font(.title3.bold())
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("Namespace \(namespace.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let type = secret.typeDescription, !type.isEmpty {
                Text(type)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1), in: Capsule())
            }
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
    }

    private func save() {
        guard !isSaving, canEditSecret, hasPendingChanges else { return }
        isSaving = true
        Task { @MainActor in
            await model.updateSecret(
                cluster: cluster,
                namespace: namespace,
                secret: secret,
                entries: editors
            )
            isSaving = false
            if model.error == nil {
                dismiss()
            }
        }
    }

    @ViewBuilder
    private var permissionBanner: some View {
        if !canReveal || !canEditSecret {
            VStack(alignment: .leading, spacing: 4) {
                if !canReveal {
                    Label(revealReason ?? "You do not have permission to reveal this secret's plaintext values.", systemImage: "lock.slash")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if !canEditSecret {
                    Label(editReason ?? "Editing is disabled by Kubernetes RBAC for your account.", systemImage: "hand.raised")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var diffPreview: some View {
        SectionBox(title: "Pending Changes") {
            if pendingDiffs.isEmpty {
                Text("No modifications detected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(pendingDiffs) { diff in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(diff.key)
                                    .font(.subheadline.weight(.semibold))
                                    .textSelection(.enabled)
                                badge(for: diff.kind)
                                if diff.isBinary {
                                    Label("Binary", systemImage: "exclamationmark.triangle")
                                        .labelStyle(.iconOnly)
                                        .foregroundStyle(.orange)
                                        .help("Value includes non-text data and will be applied as base64.")
                                }
                            }
                            if let previous = diff.previousPlaintext, let current = diff.currentPlaintext {
                                DiffRow(before: previous, after: current)
                            } else {
                                DiffRow(before: diff.previousBase64 ?? "—", after: diff.currentBase64 ?? "—", isBase64: true)
                            }
                        }
                        .padding(8)
                        .background(Color(nsColor: .underPageBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func feedbackPanel(_ feedback: SecretActionFeedback) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: feedback.status == .success ? "checkmark.circle" : "exclamationmark.triangle")
                    .foregroundStyle(feedback.status == .success ? Color.green : Color.orange)
                Text(feedback.message)
                    .font(.subheadline)
            }
            if let output = feedback.kubectlOutput {
                Text(output)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if !feedback.diff.isEmpty, feedback.status == .success {
                Text("Applied \(feedback.diff.count) change\(feedback.diff.count == 1 ? "" : "s").")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill((feedback.status == .success ? Color.green.opacity(0.12) : Color.orange.opacity(0.12)))
        )
    }

    @ViewBuilder
    private func badge(for kind: SecretDiffSummary.ChangeKind) -> some View {
        let result: (String, Color) = {
            switch kind {
            case .added: return ("Added", .green)
            case .removed: return ("Removed", .red)
            case .modified: return ("Modified", .blue)
            }
        }()

        Text(result.0)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(result.1.opacity(0.14), in: Capsule())
    }
}

private struct ConfigMapDetailSheet: View {
    let cluster: Cluster
    let namespace: Namespace
    let configMap: ConfigResourceSummary

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var editors: [ConfigMapEntryEditor]
    @State private var isSaving = false

    private var canEditConfigMap: Bool { configMap.permissions.canEdit }
    private var editReason: String? { configMap.permissions.editReason }
    private var pendingDiffs: [ConfigMapDiffSummary] { ConfigMapDiffSummary.compute(original: configMap.configMapEntries, updated: editors) }
    private var hasPendingChanges: Bool { !pendingDiffs.isEmpty }
    private var actionFeedback: ConfigMapActionFeedback? {
        guard let feedback = model.configMapActionFeedback,
              feedback.configMapName == configMap.name,
              feedback.namespace == namespace.name else { return nil }
        return feedback
    }

    init(cluster: Cluster, namespace: Namespace, configMap: ConfigResourceSummary) {
        self.cluster = cluster
        self.namespace = namespace
        self.configMap = configMap
        _editors = State(initialValue: configMap.configMapEntries?.map { ConfigMapEntryEditor(entry: $0) } ?? [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            permissionBanner

            if editors.isEmpty {
                centeredUnavailableView(
                    "No Data",
                    systemImage: "doc.text",
                    description: Text("This ConfigMap does not contain any key/value pairs.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach($editors) { $entry in
                            ConfigMapEntryEditorView(entry: $entry, canEdit: canEditConfigMap, editReason: editReason)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if canEditConfigMap {
                diffPreview
            }

            if let actionFeedback {
                configMapFeedbackPanel(actionFeedback)
            }

            Divider()
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving || !canEditConfigMap || !hasPendingChanges)
                    .optionalHelp(!canEditConfigMap ? (editReason ?? "Editing disabled by RBAC policy.") : nil)
            }
        }
        .padding(24)
        .frame(minWidth: 600, minHeight: 420)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("ConfigMap · \(configMap.name)")
                    .font(.title3.bold())
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("Namespace \(namespace.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
    }

    private func save() {
        guard !isSaving, canEditConfigMap, hasPendingChanges else { return }
        isSaving = true
        Task { @MainActor in
            await model.updateConfigMap(
                cluster: cluster,
                namespace: namespace,
                configMap: configMap,
                entries: editors
            )
            isSaving = false
            if model.error == nil {
                dismiss()
            }
        }
    }

    @ViewBuilder
    private var permissionBanner: some View {
        if !canEditConfigMap {
            Label(editReason ?? "Editing is disabled by Kubernetes RBAC for your account.", systemImage: "hand.raised")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var diffPreview: some View {
        if pendingDiffs.isEmpty { EmptyView() } else {
            SectionBox(title: "Pending Changes") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(pendingDiffs) { diff in
                        HStack(spacing: 8) {
                            badge(for: diff.kind)
                            Text(diff.key)
                                .font(.caption.bold())
                            Spacer()
                        }
                        if diff.kind != .removed {
                            DiffRow(before: diff.before ?? "", after: diff.after ?? "", isBase64: diff.isBinary)
                        } else {
                            DiffRow(before: diff.before ?? "", after: "", isBase64: diff.isBinary)
                        }
                    }
                }
            }
        }
    }

    private func badge(for kind: ConfigMapDiffSummary.ChangeKind) -> some View {
        let text: String
        let color: Color
        switch kind {
        case .added:
            text = "Added"
            color = .green
        case .removed:
            text = "Removed"
            color = .red
        case .modified:
            text = "Edited"
            color = .blue
        }
        return Text(text)
            .font(.caption.bold())
            .foregroundStyle(color)
    }

    private func configMapFeedbackPanel(_ feedback: ConfigMapActionFeedback) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: feedback.status == .success ? "checkmark.circle" : "exclamationmark.triangle")
                    .foregroundStyle(feedback.status == .success ? Color.green : Color.orange)
                Text(feedback.message)
                    .font(.subheadline)
                Spacer()
                Text(feedback.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let output = feedback.kubectlOutput, !output.isEmpty {
                Text(output)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2))
        )
    }
}

private struct ConfigMapEntryEditorView: View {
    @Binding var entry: ConfigMapEntryEditor
    let canEdit: Bool
    let editReason: String?

    private var isEditable: Bool {
        canEdit && entry.isEditable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(entry.key)
                    .font(.headline)
                Spacer()
                if entry.isBinary {
                    Text("Binary (base64)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !canEdit {
                    Text("Read-only")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if entry.isBinary || !isEditable {
                ScrollView {
                    Text(entry.value)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2))
                )
                .optionalHelp(!isEditable ? (editReason ?? "Editing disabled by RBAC policy.") : nil)
            } else {
                TextEditor(text: Binding(
                    get: { entry.value },
                    set: { entry.updateValue($0) }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2))
                )
                .optionalHelp(!canEdit ? (editReason ?? "Editing disabled by RBAC policy.") : nil)
            }
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.15))
        )
    }
}


private struct SecretEntryEditorView: View {
    @Binding var entry: SecretEntryEditor
    let canReveal: Bool
    let canEdit: Bool
    let revealReason: String?
    let editReason: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.key)
                    .font(.headline)
                if entry.isBinary {
                    Label("Binary", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .help("Value contains non-text data; editing occurs in base64 mode only.")
                }
                if !canEdit {
                    Label("Read Only", systemImage: "lock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    entry.toggleVisibility()
                } label: {
                    Image(systemName: entry.isDecodedVisible ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)
                .disabled(!canReveal || !entry.canDecode)
                .help(canReveal ? (entry.canDecode ? (entry.isDecodedVisible ? "Hide decoded value" : "Show decoded value") : "Value is not decodable; editing in plaintext is disabled.") : (revealReason ?? "Reveal disabled by RBAC policy."))
            }

            if entry.isDecodedVisible {
                TextEditor(text: Binding(
                    get: { entry.decodedValue },
                    set: { entry.decodedValue = $0 }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2))
                )
                .disabled(!canEdit)
                .optionalHelp(!canEdit ? (editReason ?? "Editing disabled by RBAC policy.") : nil)
            } else {
                TextEditor(text: Binding(
                    get: { entry.base64EditorValue },
                    set: { entry.base64EditorValue = $0 }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2))
                )
                .disabled(!canEdit)
                .optionalHelp(!canEdit ? (editReason ?? "Editing disabled by RBAC policy.") : nil)
            }
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.15))
        )
    }
}

private struct DiffRow: View {
    let before: String
    let after: String
    var isBase64: Bool = false

    private var beforeDisplay: String { before.isEmpty ? "‹empty›" : before }
    private var afterDisplay: String { after.isEmpty ? "‹empty›" : after }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 6) {
                Text("−")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Color.red)
                Text(label(for: beforeDisplay))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            HStack(alignment: .top, spacing: 6) {
                Text("+")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Color.green)
                Text(label(for: afterDisplay))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
        }
    }

private func label(for value: String) -> String {
    isBase64 ? "[base64] " + value : value
}
}

private struct SectionBox<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content
        }
    }
}

private extension View {
    @ViewBuilder
    func optionalHelp(_ message: String?) -> some View {
        if let message {
            self.help(message)
        } else {
            self
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .font(.caption)
            Spacer(minLength: 0)
        }
    }
}

private struct ContainerDetailView: View {
    let detail: ContainerDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(detail.name)
                    .font(.headline)
                Spacer()
                Text(detail.status.displayName)
                    .font(.caption.bold())
                    .foregroundStyle(detail.status.tint)
                if detail.ready {
                    Text("Ready")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Text(detail.image)
                .font(.caption.monospaced())

            if !detail.ports.isEmpty {
                DetailRow(label: "Ports", value: detail.ports.joined(separator: ", "))
            }

            DetailRow(label: "Environment", value: detail.envCount == 0 ? "—" : "\(detail.envCount) variables")
            DetailRow(label: "Mounts", value: detail.mountCount == 0 ? "—" : "\(detail.mountCount) mounts")

            if !detail.command.isEmpty {
                DetailRow(label: "Command", value: detail.command.joined(separator: " "))
            }

            if !detail.args.isEmpty {
                DetailRow(label: "Args", value: detail.args.joined(separator: " "))
            }

            if !detail.requests.isEmpty {
                DetailRow(label: "Requests", value: resourceString(detail.requests))
            }

            if !detail.limits.isEmpty {
                DetailRow(label: "Limits", value: resourceString(detail.limits))
            }

            if let liveness = detail.livenessProbe {
                DetailRow(label: "Liveness", value: "\(liveness.type.lowercased()) — \(liveness.detail)")
            }
            if let readiness = detail.readinessProbe {
                DetailRow(label: "Readiness", value: "\(readiness.type.lowercased()) — \(readiness.detail)")
            }
            if let startup = detail.startupProbe {
                DetailRow(label: "Startup", value: "\(startup.type.lowercased()) — \(startup.detail)")
            }
        }
    }

    private func resourceString(_ map: [String: String]) -> String {
        map.sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: ", ")
    }
}

private extension ContainerDetail.ContainerState {
    var displayName: String { rawValue.capitalized }

    var tint: Color {
        switch self {
        case .running: return .green
        case .waiting: return .blue
        case .terminated: return .orange
        case .unknown: return .secondary
        }
    }
}

private struct ClusterHeaderView: View {
    let cluster: Cluster

    private let dateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(cluster.name)
                    .font(.largeTitle.bold())
                Text(cluster.server)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Label(cluster.isConnected ? "Connected" : "Disconnected", systemImage: cluster.isConnected ? "antenna.radiowaves.left.and.right" : "bolt.slash")
                        .foregroundStyle(cluster.isConnected ? .green : .secondary)
                    Label(cluster.health.displayName, systemImage: cluster.health.systemImage)
                        .foregroundStyle(cluster.health.tint)
                    Text("Kubernetes \(cluster.kubernetesVersion)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Nodes \(cluster.nodeSummary.ready)/\(cluster.nodeSummary.total)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Synced \(dateFormatter.localizedString(for: cluster.lastSynced, relativeTo: Date()))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            ResourceHealthSummary(cluster: cluster)
        }
        .padding(.horizontal)
    }
}

private struct ResourceHealthSummary: View {
    let cluster: Cluster

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                summaryTile(label: "Unhealthy", value: "\(cluster.unhealthyWorkloadCount)")
                summaryTile(label: "CPU", value: PercentageFormatter.format(cluster.nodeSummary.cpuUsage))
                summaryTile(label: "Memory", value: PercentageFormatter.format(cluster.nodeSummary.memoryUsage))
                summaryTile(label: "Disk", value: PercentageFormatter.format(cluster.nodeSummary.diskUsage))
            }
        }
    }

    private func summaryTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct OverviewSection: View {
    let cluster: Cluster
    let namespace: Namespace?
    @EnvironmentObject private var model: AppModel

    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            basics
            metricsSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metrics: ClusterOverviewMetrics? {
        model.metrics(for: cluster.id)
    }

    @ViewBuilder
    private var basics: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let note = cluster.notes, !note.isEmpty {
                LabeledContent("Notes") {
                    Text(note)
                }
            }
            LabeledContent("Namespaces") {
                Text("\(cluster.namespaces.count)")
            }
            LabeledContent("Context") {
                Text(cluster.contextName)
            }
            if let namespace {
                LabeledContent("Focus Namespace") {
                    Text(namespace.name)
                }
            }
        }
    }

    @ViewBuilder
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cluster Metrics")
                .font(.headline)

            if let metrics, metrics.hasSamples {
                MetricsOverviewGrid(metrics: metrics)
                ClusterHeatmapView(metrics: metrics)
                if let updated = updatedLabel(for: metrics) {
                    Text("Updated \(updated)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                centeredUnavailableView(
                    "Metrics Unavailable",
                    systemImage: "waveform.path.ecg",
                    description: Text("Connect to Prometheus or metrics-server to visualize live trends.")
                )
                .frame(maxWidth: .infinity)
                .frame(minHeight: 220)
            }
        }
    }

    private func updatedLabel(for metrics: ClusterOverviewMetrics) -> String? {
        guard metrics.timestamp > .distantPast else { return nil }
        return relativeFormatter.localizedString(for: metrics.timestamp, relativeTo: Date())
    }
}

private struct MetricsOverviewGrid: View {
    let metrics: ClusterOverviewMetrics

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            MetricSparklineTile(
                title: "CPU",
                value: PercentageFormatter.format(metrics.cpu.latest),
                points: metrics.cpu.points,
                color: .orange
            )
            MetricSparklineTile(
                title: "Memory",
                value: PercentageFormatter.format(metrics.memory.latest),
                points: metrics.memory.points,
                color: .teal
            )
            MetricSparklineTile(
                title: "Disk",
                value: PercentageFormatter.format(metrics.disk.latest),
                points: metrics.disk.points,
                color: .purple
            )
            MetricSparklineTile(
                title: "Network",
                value: DataRateFormatter.format(metrics.network.latest),
                points: metrics.network.points,
                color: .pink
            )
        }
    }
}

private struct MetricSparklineTile: View {
    let title: String
    let value: String
    let points: [MetricPoint]
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
            SparklineView(points: points, color: color)
                .frame(height: 40)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
    }
}

private struct SparklineView: View {
    let points: [MetricPoint]
    var color: Color

    var body: some View {
        GeometryReader { geometry in
            let normalized = normalizedValues
            if normalized.count > 1 {
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    for (index, value) in normalized.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(normalized.count - 1)
                        let y = height * (1 - CGFloat(value))
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            } else {
                Path { path in
                    let midY = geometry.size.height / 2
                    path.move(to: CGPoint(x: 0, y: midY))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: midY))
                }
                .stroke(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
    }

    private var normalizedValues: [Double] {
        let values = points.map { $0.value }.filter { $0.isFinite }
        guard let minValue = values.min(), let maxValue = values.max(), values.count > 1 else {
            return Array(repeating: 0.5, count: max(points.count, 2))
        }
        let range = max(maxValue - minValue, 0.0001)
        return values.map { min(max(($0 - minValue) / range, 0), 1) }
    }
}

private struct ClusterHeatmapView: View {
    let metrics: ClusterOverviewMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Utilization Hotspots")
                .font(.headline)

            if metrics.nodeHeatmap.isEmpty && metrics.podHeatmap.isEmpty {
                Text("No hotspots detected from recent samples.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    HeatmapList(title: "Nodes", entries: metrics.nodeHeatmap)
                    HeatmapList(title: "Pods", entries: metrics.podHeatmap)
                }
            }
        }
    }
}

private struct HeatmapList: View {
    let title: String
    let entries: [HeatmapEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
            if entries.isEmpty {
                Text("No data available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entries) { entry in
                        HeatmapRow(entry: entry)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HeatmapRow: View {
    let entry: HeatmapEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.label)
                .font(.caption)
                .foregroundStyle(.primary)
            metricBar(label: "CPU", ratio: entry.cpuRatio, color: .orange)
            metricBar(label: "Mem", ratio: entry.memoryRatio, color: .teal)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
    }

    private func metricBar(label: String, ratio: Double?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(PercentageFormatter.format(ratio))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                    if let ratio, ratio > 0 {
                        Capsule()
                            .fill(color.opacity(0.85))
                            .frame(width: max(4, CGFloat(ratio) * geometry.size.width))
                    }
                }
            }
            .frame(height: 6)
        }
    }
}

private struct WorkloadsSection: View {
    let namespace: Namespace?
    let isConnected: Bool
    var filter: WorkloadKind? = nil
    let onSelect: (WorkloadSummary) -> Void

    var body: some View {
        if !isConnected {
            centeredUnavailableView(
                "Not Connected",
                systemImage: "bolt.slash",
                description: Text("Connect to the cluster to inspect workloads.")
            )
        } else if namespace == nil {
            centeredUnavailableView(
                "Select a Namespace",
                systemImage: "square.stack.3d.up",
                description: Text("Choose a namespace from the list to view workloads.")
            )
        } else if let namespace, !namespace.isLoaded {
            VStack {
                ProgressView()
                Text("Loading workloads…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let namespace, namespace.workloads.isEmpty {
            centeredUnavailableView(
                "No Workloads",
                systemImage: "shippingbox",
                description: Text("Workloads will appear when the namespace has resources.")
            )
        } else if let namespace {
            let workloads = namespace.workloads
            if let filter {
                FilteredWorkloadList(workloads: workloads.filter { $0.kind == filter }, kind: filter, onSelect: onSelect)
            } else {
                WorkloadGroupsView(workloads: workloads, onSelect: onSelect)
            }
        }
    }
}

private struct WorkloadListView: View {
    let namespace: Namespace?
    let isConnected: Bool
    let kind: WorkloadKind?
    let showsKindColumn: Bool
    let searchText: String
    let sortOption: WorkloadSortOption
    let filter: WorkloadFilterState
    let focusID: WorkloadSummary.ID?
    @Binding var selection: Set<WorkloadSummary.ID>
    let onInspect: (WorkloadSummary) -> Void
    let onFocusPods: (WorkloadSummary) -> Void

    private var baseWorkloads: [WorkloadSummary] {
        guard let namespace else { return [] }
        if let kind {
            return namespace.workloads.filter { $0.kind == kind }
        }
        return namespace.workloads
    }

    private var filteredWorkloads: [WorkloadSummary] {
        let normalized = searchTerm
        let filtered = baseWorkloads.filter { filter.matches($0) }
        guard !normalized.isEmpty else { return filtered }
        return filtered.filter { workload in
            workload.name.localizedCaseInsensitiveContains(normalized) ||
            workload.kind.displayName.localizedCaseInsensitiveContains(normalized)
        }
    }

    private var sortedWorkloads: [WorkloadSummary] {
        filteredWorkloads.sorted(by: compareWorkloads)
    }

    private var activeKinds: Set<WorkloadKind> {
        Set(filteredWorkloads.map(\.kind))
    }

    private var showsReplicaColumns: Bool {
        if let kind {
            return kind != .job && kind != .cronJob
        }
        return activeKinds.subtracting([.job, .cronJob]).isEmpty == false
    }

    private var showsUpdatedColumn: Bool {
        func supports(_ kind: WorkloadKind) -> Bool {
            [.deployment, .statefulSet, .replicaSet, .daemonSet].contains(kind)
        }
        if let kind { return supports(kind) }
        return activeKinds.contains(where: supports)
    }

    private var showsJobSummaryColumn: Bool {
        if let kind { return kind == .job }
        return activeKinds.contains(.job)
    }

    private var showsCronDetailsColumn: Bool {
        if let kind { return kind == .cronJob }
        return activeKinds.contains(.cronJob)
    }

    private var showsAvailableColumn: Bool {
        if let kind { return kind != .job && kind != .cronJob }
        return activeKinds.contains { candidate in
            candidate != .job && candidate != .cronJob
        }
    }

    private var searchTerm: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasActiveFilter: Bool {
        !filter.statuses.isEmpty || !filter.labelSelectors.isEmpty
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onChange(of: namespace?.id) { _, _ in
                selection.removeAll()
            }
            .onChange(of: filteredIDs) { _, newIDs in
                trimSelection(valid: newIDs)
            }
            .onChange(of: searchText) { _, _ in
                trimSelection(valid: filteredIDs)
            }
    }

    @ViewBuilder
    private var content: some View {
        if !isConnected {
            centeredUnavailableView(
                "Not Connected",
                systemImage: "bolt.slash",
                description: Text("Connect to the cluster to inspect workloads.")
            )
        } else if namespace == nil {
            centeredUnavailableView(
                "Select a Namespace",
                systemImage: "square.stack.3d.up",
                description: Text("Choose a namespace to view workloads.")
            )
        } else if let namespace, !namespace.isLoaded {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading workloads…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if baseWorkloads.isEmpty {
            let label = kind?.displayName ?? "Workloads"
            centeredUnavailableView(
                "No \(label)",
                systemImage: "shippingbox",
                description: Text("\(label) appear once resources are discovered in the namespace.")
            )
        } else if filteredWorkloads.isEmpty {
            if !searchTerm.isEmpty && hasActiveFilter {
                centeredUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No workloads match your search or filters.")
                )
            } else if !searchTerm.isEmpty {
                centeredUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No workloads match \"\(searchTerm)\".")
                )
            } else {
                centeredUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("Adjust filters to see workloads in this view.")
                )
            }
        } else {
            workloadsTable
        }
    }

    @ViewBuilder
    private var workloadsTable: some View {
        FixedColumnTable(
            rows: sortedWorkloads,
            columns: workloadColumns,
            selection: $selection,
            allowsMultipleSelection: false,
            minimumRowHeight: 32,
            focusID: focusID,
            onRowDoubleTap: { workload in onInspect(workload) }
        )
    }

    private var workloadColumns: [FixedTableColumn<WorkloadSummary>] {
        var columns: [FixedTableColumn<WorkloadSummary>] = []

        if showsKindColumn {
            columns.append(
                FixedTableColumn("Kind", width: WorkloadColumnWidth.kind) { workload in
                    Text(workload.kind.displayName)
                        .foregroundStyle(.secondary)
                }
            )
        }

        columns.append(
            FixedTableColumn("Name", width: WorkloadColumnWidth.name) { workload in
                Text(workload.name)
                    .font(.body.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        )

        if showsReplicaColumns {
            columns.append(
                FixedTableColumn("Desired", width: WorkloadColumnWidth.desired, alignment: .trailing) { workload in
                    Text(workload.desiredDisplay)
                        .foregroundStyle(.secondary)
                }
            )
            columns.append(
                FixedTableColumn("Ready", width: WorkloadColumnWidth.ready, alignment: .trailing) { workload in
                    Text(workload.readyDisplay)
                        .foregroundStyle(.secondary)
                }
            )
        }

        if showsUpdatedColumn {
            columns.append(
                FixedTableColumn("Updated", width: WorkloadColumnWidth.updated, alignment: .trailing) { workload in
                    Text(workload.updatedDisplay)
                        .foregroundStyle(.secondary)
                }
            )
        }

        if showsAvailableColumn {
            columns.append(
                FixedTableColumn("Available", width: WorkloadColumnWidth.available, alignment: .trailing) { workload in
                    Text(workload.availableDisplay)
                        .foregroundStyle(.secondary)
                }
            )
        }

        if showsJobSummaryColumn {
            columns.append(
                FixedTableColumn("Active", width: WorkloadColumnWidth.active, alignment: .trailing) { workload in
                    Text(workload.activeDisplay)
                        .foregroundStyle(.secondary)
                }
            )
            columns.append(
                FixedTableColumn("Succeeded", width: WorkloadColumnWidth.succeeded, alignment: .trailing) { workload in
                    Text(workload.succeededDisplay)
                        .foregroundStyle(.secondary)
                }
            )
            columns.append(
                FixedTableColumn("Failed", width: WorkloadColumnWidth.failed, alignment: .trailing) { workload in
                    Text(workload.failedDisplay)
                        .foregroundStyle(workload.failedCount ?? 0 > 0 ? Color.red : .secondary)
                }
            )
        }

        if showsCronDetailsColumn {
            columns.append(
                FixedTableColumn("Schedule", width: WorkloadColumnWidth.schedule) { workload in
                    Text(workload.scheduleDisplay)
                        .font(.body.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            )
            columns.append(
                FixedTableColumn("Mode", width: WorkloadColumnWidth.mode) { workload in
                    Text(workload.suspensionDisplay)
                        .foregroundStyle(workload.isSuspended == true ? Color.orange : .secondary)
                }
            )
        }

        columns.append(
            FixedTableColumn("Age", width: WorkloadColumnWidth.age) { workload in
                Text(workload.ageDisplay)
                    .foregroundStyle(.secondary)
            }
        )

        columns.append(
            FixedTableColumn("Status", width: WorkloadColumnWidth.status) { workload in
                Text(workload.status.displayName)
                    .foregroundStyle(workload.status.tint)
            }
        )

        columns.append(
            FixedTableColumn("Alerts", width: WorkloadColumnWidth.alerts, alignment: .trailing) { workload in
                workloadAlertsCell(for: workload)
            }
        )

        columns.append(
            FixedTableColumn("", width: WorkloadColumnWidth.actions, alignment: .trailing) { workload in
                Menu {
                    Button("Inspect") { onInspect(workload) }
                    Button("Focus Pods") { onFocusPods(workload) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .padding(2)
                }
                .menuStyle(.borderlessButton)
            }
        )

        return columns
    }

    private func compareWorkloads(_ lhs: WorkloadSummary, _ rhs: WorkloadSummary) -> Bool {
        let ascending = sortOption.direction == SortDirection.ascending
        switch sortOption.field {
        case .name:
            return compareWorkloadNames(lhs, rhs, ascending: ascending)
        case .age:
            let left = normalizedWorkloadValue(lhs.age?.totalMinutes, ascending: ascending)
            let right = normalizedWorkloadValue(rhs.age?.totalMinutes, ascending: ascending)
            if left == right {
                return compareWorkloadNames(lhs, rhs, ascending: ascending)
            }
            return ascending ? left < right : left > right
        case .readiness:
            let left = readinessValue(for: lhs)
            let right = readinessValue(for: rhs)
            if left == right {
                return compareWorkloadNames(lhs, rhs, ascending: ascending)
            }
            return ascending ? left < right : left > right
        }
    }

    private func compareWorkloadNames(_ lhs: WorkloadSummary, _ rhs: WorkloadSummary, ascending: Bool) -> Bool {
        let result = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if result == .orderedSame {
            if ascending {
                return lhs.id.uuidString < rhs.id.uuidString
            } else {
                return lhs.id.uuidString > rhs.id.uuidString
            }
        }
        return ascending ? result == .orderedAscending : result == .orderedDescending
    }

    private func normalizedWorkloadValue(_ value: Double?, ascending: Bool) -> Double {
        guard let value else {
            return ascending ? Double.greatestFiniteMagnitude : -Double.greatestFiniteMagnitude
        }
        return value
    }

    private func readinessValue(for workload: WorkloadSummary) -> Double {
        let total = max(workload.replicas, 1)
        return Double(workload.readyReplicas) / Double(total)
    }

    private var filteredIDs: Set<WorkloadSummary.ID> {
        Set(sortedWorkloads.map(\.id))
    }

    private func trimSelection(valid: Set<WorkloadSummary.ID>) {
        selection = selection.intersection(valid)
    }

    @ViewBuilder
    private func workloadAlertsCell(for workload: WorkloadSummary) -> some View {
        let counts = workloadEventCounts(for: workload)
        if counts.errors == 0 && counts.warnings == 0 {
            Text("—")
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 6) {
                if counts.errors > 0 {
                    Label("\(counts.errors)", systemImage: "exclamationmark.octagon.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Color.red)
                        .help("\(counts.errors) error event\(counts.errors == 1 ? "" : "s")")
                }
                if counts.warnings > 0 {
                    Label("\(counts.warnings)", systemImage: "exclamationmark.triangle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Color.orange)
                        .help("\(counts.warnings) warning event\(counts.warnings == 1 ? "" : "s")")
                }
            }
        }
    }

    private func workloadEventCounts(for workload: WorkloadSummary) -> (warnings: Int, errors: Int) {
        guard let namespace else { return (0, 0) }
        let name = workload.name.lowercased()
        let podNames = namespace.pods
            .filter { $0.controlledBy?.lowercased().contains(name) ?? false }
            .map { $0.name.lowercased() }

        var warnings = 0
        var errors = 0
        for event in namespace.events {
            let message = event.message.lowercased()
            let matchesWorkload = message.contains(name)
            let matchesPod = podNames.contains { message.contains($0) }
            guard matchesWorkload || matchesPod else { continue }
            let count = max(event.count, 1)
            switch event.type {
            case .warning:
                warnings += count
            case .error:
                errors += count
            default:
                break
            }
        }
        return (warnings, errors)
    }
}

private struct PodListView: View {
    let namespace: Namespace?
    let isConnected: Bool
    let filter: PodFilterState
    @Binding var selection: Set<PodSummary.ID>
    @Binding var focusedID: PodSummary.ID?
    let searchText: String
    let onShowDetails: (PodSummary) -> Void
    let onShowLogs: (PodSummary) -> Void
    let onShowExec: (PodSummary) -> Void
    let onShowYAML: (PodSummary) -> Void
    let onPortForward: (PodSummary) -> Void
    let onEvict: (PodSummary) -> Void
    let onDelete: (PodSummary) -> Void
    let focusID: PodSummary.ID?

    private var searchTerm: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var basePods: [PodSummary] {
        namespace?.pods ?? []
    }

    private var permissions: NamespacePermissions {
        namespace?.permissions ?? NamespacePermissions()
    }

    private func permissionHelp(_ action: NamespacePermissionAction, fallback: String) -> String? {
        guard !permissions.allows(action) else { return nil }
        return permissions.reason(for: action) ?? fallback
    }

    private var filteredPods: [PodSummary] {
        let sorted = basePods.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        let filtered = sorted.filter { filter.matches($0) }
        guard !searchTerm.isEmpty else { return filtered }
        return filtered.filter { pod in
            pod.name.localizedCaseInsensitiveContains(searchTerm) ||
            pod.nodeName.localizedCaseInsensitiveContains(searchTerm) ||
            (pod.controlledBy ?? "").localizedCaseInsensitiveContains(searchTerm) ||
            pod.containerSummary.localizedCaseInsensitiveContains(searchTerm)
        }
    }

    private var hasActiveFilter: Bool {
        filter.onlyWithWarnings || !filter.phases.isEmpty || !filter.labelSelectors.isEmpty
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onChange(of: namespace?.id) { _, _ in
                selection.removeAll()
                focusedID = nil
            }
            .onChange(of: filteredIDs) { _, newIDs in
                trimSelection(valid: newIDs)
            }
            .onChange(of: searchText) { _, _ in
                trimSelection(valid: filteredIDs)
            }
            .onChange(of: selection) { _, newValue in
                focusedID = newValue.first
            }
    }

    @ViewBuilder
    private var content: some View {
        if !isConnected {
            centeredUnavailableView(
                "Not Connected",
                systemImage: "bolt.slash",
                description: Text("Connect to the cluster to inspect pods.")
            )
        } else if namespace == nil {
            centeredUnavailableView(
                "Select a Namespace",
                systemImage: "square.stack.3d.up",
                description: Text("Choose a namespace to view pods.")
            )
        } else if let namespace, !namespace.isLoaded {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading pods…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if basePods.isEmpty {
            centeredUnavailableView(
                "No Pods",
                systemImage: "circle.grid.3x3.fill",
                description: Text("Pods display here once workloads create them.")
            )
        } else if filteredPods.isEmpty {
            if !searchTerm.isEmpty && hasActiveFilter {
                centeredUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No pods match your search or filters.")
                )
            } else if !searchTerm.isEmpty {
                centeredUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No pods match \"\(searchTerm)\".")
                )
            } else {
                centeredUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("Adjust filters to see pods in this view.")
                )
            }
        } else {
            podsTable
        }
    }

    @ViewBuilder
    private var podsTable: some View {
        FixedColumnTable(
            rows: filteredPods,
            columns: podColumns,
            selection: $selection,
            allowsMultipleSelection: true,
            minimumRowHeight: 34,
            focusID: focusID,
            onRowTap: { pod in
                handleFocus(afterTapping: pod)
            },
            onRowDoubleTap: { pod in onShowDetails(pod) }
        )
    }
    private var podColumns: [FixedTableColumn<PodSummary>] {
        [
            FixedTableColumn("Name", width: PodColumnWidth.name) { pod in
                Text(pod.name)
                    .font(.body.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
            },
            FixedTableColumn("Containers", width: PodColumnWidth.containers) { pod in
                Text(pod.containerSummary.isEmpty ? "—" : pod.containerSummary)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            },
            FixedTableColumn("Restarts", width: PodColumnWidth.restarts, alignment: .trailing) { pod in
                Text("\(pod.restarts)")
                    .foregroundStyle(.secondary)
            },
            FixedTableColumn("Node", width: PodColumnWidth.node) { pod in
                Text(pod.nodeName)
                    .lineLimit(1)
                    .truncationMode(.middle)
            },
            FixedTableColumn("Phase", width: PodColumnWidth.status) { pod in
                Text(pod.phase.displayName)
                    .foregroundStyle(pod.phase.tint)
            },
            FixedTableColumn("Alerts", width: PodColumnWidth.alerts, alignment: .trailing) { pod in
                alertsCell(for: pod)
            },
            FixedTableColumn("Age", width: PodColumnWidth.age) { pod in
                Text(pod.ageDisplay)
                    .foregroundStyle(.secondary)
            },
            FixedTableColumn("", width: PodColumnWidth.actions, alignment: .trailing) { pod in
                Menu {
                    Button("Inspect") { onShowDetails(pod) }
                        .disabled(!isConnected || !permissions.canGetPods)
                        .optionalHelp(permissionHelp(.getPods, fallback: "Requires get pods permission."))
                    Button("Logs") { onShowLogs(pod) }
                        .disabled(!isConnected || !permissions.canViewPodLogs)
                        .optionalHelp(permissionHelp(.viewPodLogs, fallback: "Requires pods/log permission."))
                    Button("Exec") { onShowExec(pod) }
                        .disabled(!isConnected || !permissions.canExecPods)
                        .optionalHelp(permissionHelp(.execPods, fallback: "Requires pods/exec permission."))
                    Button("YAML") { onShowYAML(pod) }
                        .disabled(!isConnected || !permissions.canGetPods)
                        .optionalHelp(permissionHelp(.getPods, fallback: "Requires get pods permission."))
                    Divider()
                    Button("Port Forward") { onPortForward(pod) }
                        .disabled(!isConnected || !permissions.canPortForwardPods)
                        .optionalHelp(permissionHelp(.portForwardPods, fallback: "Requires pods/portforward permission."))
                    Button("Evict") { onEvict(pod) }
                        .disabled(!isConnected || !permissions.canDeletePods)
                        .optionalHelp(permissionHelp(.deletePods, fallback: "Requires delete pods permission."))
                    Button(role: .destructive) { onDelete(pod) } label: {
                        Text("Delete")
                    }
                    .disabled(!isConnected || !permissions.canDeletePods)
                    .optionalHelp(permissionHelp(.deletePods, fallback: "Requires delete pods permission."))
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .padding(2)
                }
                .menuStyle(.borderlessButton)
            }
        ]
    }

    private var filteredIDs: Set<PodSummary.ID> {
        Set(filteredPods.map(\.id))
    }

    private func trimSelection(valid: Set<PodSummary.ID>) {
        selection = selection.intersection(valid)
        if let focused = focusedID, !valid.contains(focused) {
            focusedID = selection.first
        }
    }

    private func handleFocus(afterTapping pod: PodSummary) {
        if selection.contains(pod.id) {
            focusedID = pod.id
        } else if focusedID == pod.id {
            focusedID = selection.first
        }
    }

    @ViewBuilder
    private func alertsCell(for pod: PodSummary) -> some View {
        let counts = eventCounts(for: pod)
        if counts.errors == 0 && counts.warnings == 0 {
            Text("—")
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 6) {
                if counts.errors > 0 {
                    Label("\(counts.errors)", systemImage: "exclamationmark.octagon.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Color.red)
                        .help("\(counts.errors) error event\(counts.errors == 1 ? "" : "s")")
                }
                if counts.warnings > 0 {
                    Label("\(counts.warnings)", systemImage: "exclamationmark.triangle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Color.orange)
                        .help("\(counts.warnings) warning event\(counts.warnings == 1 ? "" : "s")")
                }
            }
        }
    }

    private func eventCounts(for pod: PodSummary) -> (warnings: Int, errors: Int) {
        guard let events = namespace?.events else { return (0, 0) }
        let podName = pod.name.lowercased()
        var warnings = 0
        var errors = 0
        for event in events {
            let message = event.message.lowercased()
            guard message.contains(podName) else { continue }
            switch event.type {
            case .warning:
                warnings += max(event.count, 1)
            case .error:
                errors += max(event.count, 1)
            default:
                break
            }
        }
        return (warnings, errors)
    }
}

private struct HelmListView: View {
    let cluster: Cluster
    let isLoading: Bool
    let errorMessage: String?
    @Binding var selection: Set<HelmRelease.ID>
    let searchText: String

    private var searchTerm: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var releases: [HelmRelease] {
        cluster.helmReleases.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var filteredReleases: [HelmRelease] {
        guard !searchTerm.isEmpty else { return releases }
        return releases.filter { release in
            release.name.localizedCaseInsensitiveContains(searchTerm) ||
            release.namespace.localizedCaseInsensitiveContains(searchTerm) ||
            release.chart.localizedCaseInsensitiveContains(searchTerm) ||
            release.status.localizedCaseInsensitiveContains(searchTerm)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let message = errorMessage, !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Group {
                if !cluster.isConnected {
                    centeredUnavailableView(
                        "Not Connected",
                        systemImage: "bolt.slash",
                        description: Text("Connect to the cluster to inspect Helm releases.")
                    )
                } else if releases.isEmpty && isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading Helm releases…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if releases.isEmpty {
                    centeredUnavailableView(
                        "No Releases",
                        systemImage: "shippingbox",
                        description: Text("Helm releases will appear once charts are installed.")
                    )
                } else if !searchTerm.isEmpty && filteredReleases.isEmpty {
                    centeredUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("No releases match \"\(searchTerm)\".")
                    )
                } else {
                    FixedColumnTable(
                        rows: filteredReleases,
                        columns: helmColumns,
                        selection: $selection,
                        allowsMultipleSelection: false,
                        minimumRowHeight: 32
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: searchText) {
            trimSelection()
        }
        .onChange(of: filteredReleases.map(\.id)) { _, _ in
            trimSelection()
        }
    }

    private var helmColumns: [FixedTableColumn<HelmRelease>] {
        [
            FixedTableColumn("Name", width: HelmColumnWidth.name) { release in
                Text(release.name)
                    .font(.body.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
            },
            FixedTableColumn("Namespace", width: HelmColumnWidth.namespace) { release in
                Text(release.namespace)
                    .foregroundStyle(.secondary)
            },
            FixedTableColumn("Revision", width: HelmColumnWidth.revision, alignment: .trailing) { release in
                Text("\(release.revision)")
                    .foregroundStyle(.secondary)
            },
            FixedTableColumn("Status", width: HelmColumnWidth.status) { release in
                Text(release.status.capitalized)
                    .foregroundStyle(release.statusColor)
            },
            FixedTableColumn("Updated", width: HelmColumnWidth.updated) { release in
                Text(release.updatedDisplay)
                    .foregroundStyle(.secondary)
            },
            FixedTableColumn("Chart", width: HelmColumnWidth.chart) { release in
                Text(release.chart)
                    .lineLimit(1)
            },
            FixedTableColumn("App Ver", width: HelmColumnWidth.appVersion) { release in
                Text(release.appVersion ?? "—")
                    .foregroundStyle(.secondary)
            }
        ]
    }

    private func trimSelection() {
        let valid = Set(filteredReleases.map(\.id))
        selection = selection.intersection(valid)
    }
}

private struct NetworkListView: View {
    let cluster: Cluster
    let namespace: Namespace?
    let isConnected: Bool
    let focus: ClusterDetailView.NetworkResourceKind
    @Binding var serviceSelection: Set<ServiceSummary.ID>
    @Binding var ingressSelection: Set<IngressSummary.ID>
    let searchText: String
    let servicePermissions: (ServiceSummary) -> NamespacePermissions?
    let onInspectService: (ServiceSummary) -> Void
    let onEditService: (ServiceSummary) -> Void
    let onDeleteService: (ServiceSummary) -> Void

    private var searchTerm: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var allServices: [ServiceSummary] { namespace?.services ?? [] }
    private var allIngresses: [IngressSummary] { namespace?.ingresses ?? [] }
    private var allLoadBalancers: [ServiceSummary] {
        allServices.filter { $0.type.lowercased() == "loadbalancer" }
    }

    private var services: [ServiceSummary] { filterServices(allServices) }
    private var loadBalancers: [ServiceSummary] { filterServices(allLoadBalancers) }

    private func filterServices(_ base: [ServiceSummary]) -> [ServiceSummary] {
        let sorted = base.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        guard !searchTerm.isEmpty else { return sorted }
        return sorted.filter { service in
            service.name.localizedCaseInsensitiveContains(searchTerm) ||
            service.clusterIP.localizedCaseInsensitiveContains(searchTerm) ||
            service.ports.localizedCaseInsensitiveContains(searchTerm) ||
            service.externalEndpointSummary.localizedCaseInsensitiveContains(searchTerm)
        }
    }

    private var ingresses: [IngressSummary] {
        let sorted = allIngresses.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        guard !searchTerm.isEmpty else { return sorted }
        return sorted.filter { ingress in
            ingress.name.localizedCaseInsensitiveContains(searchTerm) ||
            ingress.hostRules.localizedCaseInsensitiveContains(searchTerm) ||
            ingress.serviceTargets.localizedCaseInsensitiveContains(searchTerm)
        }
    }

    private var currentServiceIDs: [ServiceSummary.ID] {
        switch focus {
        case .services:
            return services.map(\.id)
        case .endpoints:
            return services.map(\.id)
        case .loadBalancers:
            return loadBalancers.map(\.id)
        default:
            return []
        }
    }

    var body: some View {
        Group {
            if !isConnected {
                centeredUnavailableView(
                    "Not Connected",
                    systemImage: "bolt.slash",
                    description: Text("Connect to the cluster to inspect networking resources.")
                )
            } else if namespace == nil {
                centeredUnavailableView(
                    "Select a Namespace",
                    systemImage: "square.stack.3d.up",
                    description: Text("Choose a namespace to view networking resources.")
                )
            } else if let namespace, !namespace.isLoaded {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading resources…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                switch focus {
                case .services:
                    servicesBody
                case .endpoints:
                    endpointsBody
                case .ingresses:
                    ingressesBody
                case .networkPolicies:
                    networkPoliciesBody
                case .loadBalancers:
                    loadBalancersBody
                case .portForwards:
                    portForwardsBody
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: focus) { _, _ in
            serviceSelection.removeAll()
            ingressSelection.removeAll()
        }
        .onChange(of: currentServiceIDs) { _, newIDs in
            let valid = Set(newIDs)
            serviceSelection = serviceSelection.intersection(valid)
        }
        .onChange(of: ingresses.map(\.id)) { _, newIDs in
            let valid = Set(newIDs)
            ingressSelection = ingressSelection.intersection(valid)
        }
    }

    private var servicesBody: some View {
        Group {
            if allServices.isEmpty {
                centeredUnavailableView(
                    "No Services",
                    systemImage: "switch.2",
                    description: Text("Services appear once workloads expose ports.")
                )
            } else if !searchTerm.isEmpty && services.isEmpty {
                centeredUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No services match \"\(searchTerm)\".")
                )
            } else {
                FixedColumnTable(
                    rows: services,
                    columns: serviceColumns,
                    selection: $serviceSelection,
                    allowsMultipleSelection: true,
                    minimumRowHeight: 32,
                    onRowDoubleTap: { service in onInspectService(service) }
                )
            }
        }
    }

    private var loadBalancersBody: some View {
        Group {
            if allLoadBalancers.isEmpty {
                centeredUnavailableView(
                    "No Load Balancers",
                    systemImage: "server.rack",
                    description: Text("Create a LoadBalancer service to expose workloads externally.")
                )
            } else if !searchTerm.isEmpty && loadBalancers.isEmpty {
                centeredUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No load balancers match \"\(searchTerm)\".")
                )
            } else {
                FixedColumnTable(
                    rows: loadBalancers,
                    columns: serviceColumns,
                    selection: $serviceSelection,
                    allowsMultipleSelection: true,
                    minimumRowHeight: 32,
                    onRowDoubleTap: { service in onInspectService(service) }
                )
            }
        }
    }

    private var endpointsBody: some View {
        Group {
            if services.isEmpty {
                centeredUnavailableView(
                    "No Endpoints",
                    systemImage: "point.3.filled.connected.trianglepath.dotted",
                    description: Text("Endpoints appear once services select pods.")
                )
            } else {
                FixedColumnTable(
                    rows: services,
                    columns: endpointColumns,
                    selection: $serviceSelection,
                    allowsMultipleSelection: true,
                    minimumRowHeight: 32,
                    onRowDoubleTap: { service in onInspectService(service) }
                )
            }
        }
    }

    private var networkPoliciesBody: some View {
        centeredUnavailableView(
            "Network Policies",
            systemImage: "shield.lefthalf.fill",
            description: Text("Network policies are not yet available in this build.")
        )
    }

    private var ingressesBody: some View {
        Group {
            if allIngresses.isEmpty {
                centeredUnavailableView(
                    "No Ingresses",
                    systemImage: "cloud",
                    description: Text("Ingress resources appear once they are defined in the namespace.")
                )
            } else if !searchTerm.isEmpty && ingresses.isEmpty {
                centeredUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No ingresses match \"\(searchTerm)\".")
                )
            } else {
                FixedColumnTable(
                    rows: ingresses,
                    columns: ingressColumns,
                    selection: $ingressSelection,
                    allowsMultipleSelection: true,
                    minimumRowHeight: 32
                )
            }
        }
    }

    private var portForwardsBody: some View {
        PortForwardDashboard(cluster: cluster, namespace: namespace)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var serviceColumns: [FixedTableColumn<ServiceSummary>] {
        [
            FixedTableColumn("Name", width: ServiceColumnWidth.name) { service in
                Text(service.name)
                    .font(.body.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
            },
            FixedTableColumn("Type", width: ServiceColumnWidth.type) { service in
                Text(service.type)
                    .foregroundStyle(.secondary)
            },
            FixedTableColumn("Cluster IP", width: ServiceColumnWidth.clusterIP) { service in
                Text(service.clusterIP)
                    .foregroundStyle(.secondary)
            },
            FixedTableColumn("Ports", width: ServiceColumnWidth.ports) { service in
                Text(service.ports)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            },
            FixedTableColumn("External", width: ServiceColumnWidth.external) { service in
                Text(service.externalEndpointSummary)
                    .foregroundStyle(service.hasExternalEndpoints ? .primary : .secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            },
            FixedTableColumn("Health", width: ServiceColumnWidth.health) { service in
                serviceHealthBadge(for: service)
            },
            FixedTableColumn("Latency", width: ServiceColumnWidth.latency) { service in
                Text(latencyDisplay(for: service))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            },
            FixedTableColumn("Age", width: ServiceColumnWidth.age) { service in
                Text(service.age?.displayText ?? "—")
                    .foregroundStyle(.secondary)
            },
            FixedTableColumn("", width: ServiceColumnWidth.actions, alignment: .trailing) { service in
                let permissions = servicePermissions(service)
                let canEdit = isConnected && (permissions?.canEditServices ?? false)
                let editReason = permissions?.reason(for: .editServices)
                let canDelete = isConnected && (permissions?.canDeleteServices ?? false)
                let deleteReason = permissions?.reason(for: .deleteServices)

                Menu {
                    Button("Inspect") { onInspectService(service) }
                        .disabled(!isConnected)
                    Button("Edit YAML…") { onEditService(service) }
                        .disabled(!canEdit)
                        .optionalHelp(!canEdit ? (editReason ?? "Editing disabled by RBAC policy.") : nil)
                    Button(role: .destructive) {
                        onDeleteService(service)
                    } label: {
                        Text("Delete")
                    }
                    .disabled(!canDelete)
                    .optionalHelp(!canDelete ? (deleteReason ?? "Requires delete services permission.") : nil)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .padding(2)
                }
                .menuStyle(.borderlessButton)
            }
        ]
    }

    private var endpointColumns: [FixedTableColumn<ServiceSummary>] {
        [
            FixedTableColumn("Service", width: ServiceColumnWidth.name) { service in
                Text(service.name)
                    .font(.body.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
            },
            FixedTableColumn("Cluster IP", width: ServiceColumnWidth.clusterIP) { service in
                Text(service.clusterIP)
                    .foregroundStyle(.secondary)
            },
            FixedTableColumn("Ready Pods", width: ServiceColumnWidth.health) { service in
                endpointPodsList(service.readyPods)
            },
            FixedTableColumn("Not Ready", width: ServiceColumnWidth.health) { service in
                endpointPodsList(service.notReadyPods)
            }
        ]
    }

    private func endpointPodsList(_ pods: [String]) -> some View {
        Group {
            if pods.isEmpty {
                Text("—").foregroundStyle(.secondary)
            } else {
                Text(pods.joined(separator: ", "))
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private func serviceHealthBadge(for service: ServiceSummary) -> some View {
        let total = service.totalEndpointCount
        if total == 0 {
            Text("No endpoints")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            let state = service.healthState
            HStack(spacing: 6) {
                Circle()
                    .fill(state.tint)
                    .frame(width: 8, height: 8)
                Text("\(service.endpointHealthDisplay) ready")
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(state.tint.opacity(0.12), in: Capsule())
        }
    }

    private func latencyDisplay(for service: ServiceSummary) -> String {
        guard let p50 = service.latencyP50 else { return "—" }
        let p50Text = formatLatency(p50)
        if let p95 = service.latencyP95 {
            return "\(p50Text) / \(formatLatency(p95))"
        }
        return p50Text
    }

    private func formatLatency(_ latency: TimeInterval) -> String {
        if latency >= 1 {
            return latency.formatted(.number.precision(.fractionLength(2))) + "s"
        }
        let milliseconds = latency * 1_000
        return milliseconds.formatted(.number.precision(.fractionLength(0...1))) + "ms"
    }

    private var ingressColumns: [FixedTableColumn<IngressSummary>] {
        [
            FixedTableColumn("Name", width: IngressColumnWidth.name) { ingress in
                Text(ingress.name)
                    .font(.body.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
            },
            FixedTableColumn("Class", width: IngressColumnWidth.className) { ingress in
                Text(ingress.className ?? "—")
                    .foregroundStyle(ingress.className == nil ? .secondary : .primary)
            },
            FixedTableColumn("Hosts", width: IngressColumnWidth.hosts) { ingress in
                Text(ingress.hostRules)
                    .lineLimit(2)
            },
            FixedTableColumn("Targets", width: IngressColumnWidth.targets) { ingress in
                Text(ingress.serviceTargets)
                    .lineLimit(2)
            },
            FixedTableColumn("TLS", width: IngressColumnWidth.tls, alignment: .center) { ingress in
                Image(systemName: ingress.tls ? "lock.fill" : "lock.open")
                    .foregroundStyle(ingress.tls ? Color.green : .secondary)
            },
            FixedTableColumn("Age", width: IngressColumnWidth.age) { ingress in
                Text(ingress.age?.displayText ?? "—")
                    .foregroundStyle(.secondary)
            }
        ]
    }
}
private struct PortForwardDashboard: View {
    let cluster: Cluster
    let namespace: Namespace?

    @EnvironmentObject private var model: AppModel
    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private var forwards: [ActivePortForward] {
        model.activePortForwards.filter { forward in
            guard forward.request.clusterID == cluster.id else { return false }
            guard let namespace else { return true }
            if namespace.id == AppModel.allNamespacesNamespaceID { return true }
            return forward.request.namespace == namespace.name
        }
        .sorted { $0.startedAt > $1.startedAt }
    }

    var body: some View {
        SectionBox(title: "Active Port Forwards") {
            if forwards.isEmpty {
                centeredUnavailableView(
                    "No Active Forwards",
                    systemImage: "bolt.horizontal",
                    description: Text("Start a port forward from the pod inspector to monitor live connections.")
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(forwards) { forward in
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("localhost:\(forward.request.localPort) → \(forward.request.namespace)/\(forward.request.podName):\(forward.request.remotePort)")
                                    .font(.caption.monospaced())
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(startedDescription(forward))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            statusBadge(for: forward)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(nsColor: .underPageBackgroundColor))
                        )
                    }
                }
            }
        }
    }

    private func startedDescription(_ forward: ActivePortForward) -> String {
        let relative = PortForwardDashboard.formatter.localizedString(for: forward.startedAt, relativeTo: Date())
        return "Started \(relative)"
    }

    private func statusBadge(for forward: ActivePortForward) -> some View {
        let (color, label, icon) = statusMetadata(forward.status)
        return HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
            Button {
                Task { await model.stopPortForward(id: forward.id) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Stop port forward")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.16), in: Capsule())
        .foregroundStyle(color)
    }

    private func statusMetadata(_ status: PortForwardStatus) -> (Color, String, String) {
        switch status {
        case .establishing:
            return (.blue, "Establishing", "hourglass")
        case .active:
            return (.green, "Active", "bolt.horizontal")
        case .failed(let message):
            let label = message.isEmpty ? "Failed" : message
            return (.orange, label, "exclamationmark.triangle")
        }
    }
}

private struct StorageListView: View {
    let namespace: Namespace?
    let isConnected: Bool
    @Binding var selection: Set<PersistentVolumeClaimSummary.ID>
    let searchText: String
    let claimPermissions: (PersistentVolumeClaimSummary) -> NamespacePermissions?
    let onInspectClaim: (PersistentVolumeClaimSummary) -> Void
    let onEditClaim: (PersistentVolumeClaimSummary) -> Void
    let onDeleteClaim: (PersistentVolumeClaimSummary) -> Void

    private var searchTerm: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var claims: [PersistentVolumeClaimSummary] {
        guard let namespace else { return [] }
        let sorted = namespace.persistentVolumeClaims.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        guard !searchTerm.isEmpty else { return sorted }
        return sorted.filter { claim in
            claim.name.localizedCaseInsensitiveContains(searchTerm) ||
            (claim.storageClass ?? "").localizedCaseInsensitiveContains(searchTerm) ||
            (claim.volumeName ?? "").localizedCaseInsensitiveContains(searchTerm)
        }
    }

    var body: some View {
        Group {
            if !isConnected {
                centeredUnavailableView(
                    "Not Connected",
                    systemImage: "bolt.slash",
                    description: Text("Connect to the cluster to inspect storage resources.")
                )
            } else if namespace == nil {
                centeredUnavailableView(
                    "Select a Namespace",
                    systemImage: "square.stack.3d.up",
                    description: Text("Choose a namespace to view persistent volume claims.")
                )
            } else if let namespace, !namespace.isLoaded {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading storage…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if claims.isEmpty {
                if searchTerm.isEmpty {
                    centeredUnavailableView(
                        "No Persistent Volume Claims",
                        systemImage: "externaldrive",
                        description: Text("PVCs appear here once declared in the namespace.")
                    )
                } else {
                    centeredUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("No PVCs match \"\(searchTerm)\".")
                    )
                }
            } else {
                FixedColumnTable(
                    rows: claims,
                    columns: pvcColumns,
                    selection: $selection,
                    allowsMultipleSelection: true,
                    minimumRowHeight: 32,
                    onRowDoubleTap: { claim in
                        onInspectClaim(claim)
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: searchText) {
            trimSelection()
        }
        .onChange(of: claims.map(\.id)) { _, _ in
            trimSelection()
        }
    }

    private var pvcColumns: [FixedTableColumn<PersistentVolumeClaimSummary>] {
        [
            FixedTableColumn("Name", width: PVCColumnWidth.name) { claim in
                Text(claim.name)
                    .font(.body.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
            },
            FixedTableColumn("Status", width: PVCColumnWidth.status) { claim in
                Text(claim.status)
                    .foregroundStyle(.secondary)
            },
            FixedTableColumn("Capacity", width: PVCColumnWidth.capacity) { claim in
                Text(claim.capacity ?? "—")
                    .foregroundStyle(claim.capacity == nil ? .secondary : .primary)
            },
            FixedTableColumn("Storage Class", width: PVCColumnWidth.storageClass) { claim in
                Text(claim.storageClass ?? "—")
                    .foregroundStyle(claim.storageClass == nil ? .secondary : .primary)
            },
            FixedTableColumn("Volume", width: PVCColumnWidth.volume) { claim in
                Text(claim.volumeName ?? "—")
                    .foregroundStyle(claim.volumeName == nil ? .secondary : .primary)
            },
            FixedTableColumn("Age", width: PVCColumnWidth.age) { claim in
                Text(claim.age?.displayText ?? "—")
                    .foregroundStyle(.secondary)
            },
            FixedTableColumn("", width: PVCColumnWidth.actions, alignment: .trailing) { claim in
                let permissions = claimPermissions(claim)
                let canEdit = isConnected && (permissions?.canEditPersistentVolumeClaims ?? false)
                let editReason = permissions?.reason(for: .editPersistentVolumeClaims)
                let canDelete = isConnected && (permissions?.canDeletePersistentVolumeClaims ?? false)
                let deleteReason = permissions?.reason(for: .deletePersistentVolumeClaims)

                Menu {
                    Button("Inspect") { onInspectClaim(claim) }
                        .disabled(!isConnected)
                    Button("Edit YAML…") { onEditClaim(claim) }
                        .disabled(!canEdit)
                        .optionalHelp(!canEdit ? (editReason ?? "Editing disabled by RBAC policy.") : nil)
                    Button(role: .destructive) { onDeleteClaim(claim) } label: {
                        Text("Delete")
                    }
                    .disabled(!canDelete)
                    .optionalHelp(!canDelete ? (deleteReason ?? "Requires delete persistentvolumeclaims permission.") : nil)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .padding(2)
                }
                .menuStyle(.borderlessButton)
            }
        ]
    }

    private func trimSelection() {
        let valid = Set(claims.map(\.id))
        selection = selection.intersection(valid)
    }
}

private struct PodsSection: View {
    let namespace: Namespace?
    let isConnected: Bool
    @Binding var selection: Set<PodSummary.ID>
    @Binding var focusedID: PodSummary.ID?
    let onShowDetails: (PodSummary) -> Void
    let onAttach: (PodSummary) -> Void
    let onShell: (PodSummary) -> Void
    let onEvict: (PodSummary) -> Void
    let onLogs: (PodSummary) -> Void
    let onEdit: (PodSummary) -> Void
    let onDelete: (PodSummary) -> Void
    let onPortForward: (PodSummary) -> Void

    var pods: [PodSummary] { namespace?.pods ?? [] }

    var body: some View {
        if !isConnected {
            centeredUnavailableView(
                "Not Connected",
                systemImage: "bolt.slash",
                description: Text("Connect to the cluster to inspect pods.")
            )
        } else if namespace == nil {
            centeredUnavailableView(
                "Select a Namespace",
                systemImage: "square.stack.3d.up",
                description: Text("Choose a namespace from the list to view pods.")
            )
        } else if let namespace, !namespace.isLoaded {
            VStack {
                ProgressView()
                Text("Loading pods…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if pods.isEmpty {
            centeredUnavailableView(
                "No Pods",
                systemImage: "circle.grid.3x3.fill",
                description: Text("Pods show here once the namespace is selected.")
            )
        } else {
            tableView
        }
    }

    private var tableView: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color(nsColor: .underPageBackgroundColor))
                Divider()
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(pods) { pod in
                            row(for: pod)
                            Divider()
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(minHeight: 280)
            }
        }
        .frame(minHeight: 320)
        .onChange(of: selection) { _, newValue in
            if let current = focusedID, newValue.contains(current) {
                return
            }
            focusedID = newValue.first
        }
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            Text("")
                .frame(width: Column.checkbox, alignment: .leading)
            Text("Name")
                .frame(width: Column.name, alignment: .leading)
            Text("Warnings")
                .frame(width: Column.warnings, alignment: .leading)
            Text("Namespace")
                .frame(width: Column.namespace, alignment: .leading)
            Text("Containers")
                .frame(width: Column.containers, alignment: .leading)
            Text("CPU")
                .frame(width: Column.cpu, alignment: .leading)
            Text("Memory")
                .frame(width: Column.memory, alignment: .leading)
            Text("Disk")
                .frame(width: Column.disk, alignment: .leading)
            Text("Restart")
                .frame(width: Column.restart, alignment: .leading)
            Text("Controlled By")
                .frame(width: Column.controlledBy, alignment: .leading)
            Text("Node")
                .frame(width: Column.node, alignment: .leading)
            Text("QoS")
                .frame(width: Column.qos, alignment: .leading)
            Text("Age")
                .frame(width: Column.age, alignment: .leading)
            Text("Status")
                .frame(width: Column.status, alignment: .leading)
            Text("")
                .frame(width: Column.actions, alignment: .trailing)
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
    }

    private func row(for pod: PodSummary) -> some View {
        let toggleBinding = Binding(
            get: { selection.contains(pod.id) },
            set: { isOn in
                var updated = selection
                if isOn {
                    updated.insert(pod.id)
                } else {
                    updated.remove(pod.id)
                }
                selection = updated
                if isOn {
                    focusedID = pod.id
                } else if focusedID == pod.id {
                    focusedID = updated.first
                }
            }
        )

        return HStack(spacing: 12) {
            Toggle("", isOn: toggleBinding)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .frame(width: Column.checkbox, alignment: .leading)

            Text(pod.name)
                .font(.body.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: Column.name, alignment: .leading)

            Group {
                if pod.warningCount > 0 {
                    Text("\(pod.warningCount)")
                        .foregroundStyle(Color.orange)
                } else {
                    Text("—")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: Column.warnings, alignment: .leading)

            Text(pod.namespace)
                .frame(width: Column.namespace, alignment: .leading)

            Group {
                if pod.containerNames.isEmpty {
                    Text("—")
                        .foregroundStyle(.secondary)
                } else {
                    Text(pod.containerSummary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(width: Column.containers, alignment: .leading)

            Text(pod.cpuDisplay)
                .foregroundStyle(.secondary)
                .frame(width: Column.cpu, alignment: .leading)

            Text(pod.memoryDisplay)
                .foregroundStyle(.secondary)
                .frame(width: Column.memory, alignment: .leading)

            Text(pod.diskDisplay)
                .foregroundStyle(.secondary)
                .frame(width: Column.disk, alignment: .leading)

            Text("\(pod.restarts)")
                .frame(width: Column.restart, alignment: .leading)

            Text(pod.controlledBy ?? "—")
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: Column.controlledBy, alignment: .leading)

            Text(pod.nodeName)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: Column.node, alignment: .leading)

            Text(pod.qosDisplay)
                .foregroundStyle(.secondary)
                .frame(width: Column.qos, alignment: .leading)

            Text(pod.ageDisplay)
                .foregroundStyle(.secondary)
                .frame(width: Column.age, alignment: .leading)

            Text(pod.phase.displayName)
                .foregroundStyle(pod.phase.tint)
                .frame(width: Column.status, alignment: .leading)

            actionsMenu(for: pod)
                .frame(width: Column.actions, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(focusedID == pod.id ? Color.accentColor.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedID = pod.id
        }
    }

    @ViewBuilder
    private func actionsMenu(for pod: PodSummary) -> some View {
        Menu {
            Button("Show Details") { onShowDetails(pod) }
            Button("Attach Pod") { onAttach(pod) }
                .disabled(!isConnected)
            Button("Shell") { onShell(pod) }
                .disabled(!isConnected)
            Button("Evict") { onEvict(pod) }
                .disabled(!isConnected)
            Divider()
            Button("Logs") { onLogs(pod) }
                .disabled(!isConnected)
            Button("Edit") { onEdit(pod) }
                .disabled(!isConnected)
            Button(role: .destructive) { onDelete(pod) } label: {
                Text("Delete")
            }
            .disabled(!isConnected)
            Button("Port Forward") { onPortForward(pod) }
                .disabled(!isConnected)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .padding(4)
        }
        .menuStyle(.borderlessButton)
    }

    private enum Column {
        static let checkbox: CGFloat = 32
        static let name: CGFloat = 220
        static let warnings: CGFloat = 80
        static let namespace: CGFloat = 160
        static let containers: CGFloat = 220
        static let cpu: CGFloat = 80
        static let memory: CGFloat = 80
        static let disk: CGFloat = 160
        static let restart: CGFloat = 80
        static let controlledBy: CGFloat = 180
        static let node: CGFloat = 160
        static let qos: CGFloat = 80
        static let age: CGFloat = 60
        static let status: CGFloat = 100
        static let actions: CGFloat = 60
    }
}

private struct WorkloadDetailSheetView: View {
    let cluster: Cluster
    let namespace: Namespace
    let workload: WorkloadSummary
    let pods: [PodSummary]
    let onFocusPods: () -> Void
    let presentation: DetailPresentationStyle
    private let closeAction: (() -> Void)?

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var desiredReplicas: Int
    @State private var isScaling = false

    init(
        cluster: Cluster,
        namespace: Namespace,
        workload: WorkloadSummary,
        pods: [PodSummary],
        onFocusPods: @escaping () -> Void,
        presentation: DetailPresentationStyle = .sheet,
        onClose: (() -> Void)? = nil
    ) {
        self.cluster = cluster
        self.namespace = namespace
        self.workload = workload
        self.pods = pods
        self.onFocusPods = onFocusPods
        self.presentation = presentation
        self.closeAction = onClose
        _desiredReplicas = State(initialValue: max(workload.replicas, 0))
    }

    private var supportsScaling: Bool { workload.kind.supportsScaling }
    private var cpuAverageRatio: Double? { averageRatio(pods.map { $0.cpuUsageRatio }) }
    private var memoryAverageRatio: Double? { averageRatio(pods.map { $0.memoryUsageRatio }) }
    private var diskAverageRatio: Double? { averageRatio(pods.map { $0.diskUsageRatio }) }

    private var statusBreakdown: [(label: String, count: Int, color: Color)] {
        let groups = Dictionary(grouping: pods) { $0.phase }
        return PodPhase.allCases.compactMap { phase in
            let count = groups[phase]?.count ?? 0
            guard count > 0 else { return nil }
            return (phase.displayName, count, phase.tint)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            Divider()
            metrics
            analytics
            if supportsScaling {
                scalingControls
            }
            actionRow
            Divider()
            podsSection
            Spacer(minLength: 0)
            footer
        }
        .padding(presentation == .sheet ? 24 : 16)
        .frame(
            minWidth: presentation == .sheet ? 560 : nil,
            maxWidth: .infinity,
            minHeight: presentation == .sheet ? 520 : nil,
            alignment: .topLeading
        )
        .onChange(of: workload.replicas) { _, newValue in
            desiredReplicas = max(newValue, 0)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(workload.kind.displayName) · \(workload.name)")
                    .font(.title3.bold())
                Text("Namespace \(namespace.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(workload.status.displayName)
                .font(.headline)
                .foregroundStyle(workload.status.tint)
            if presentation == .sheet {
                Button("Close") { close() }
                    .keyboardShortcut(.cancelAction)
            }
        }
    }

    private var metrics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow {
                    metric(label: "Desired", value: workload.desiredDisplay)
                    metric(label: "Ready", value: workload.readyDisplay)
                    metric(label: "Available", value: workload.availableDisplay)
                }
                GridRow {
                    metric(label: "Updated", value: workload.updatedDisplay)
                    metric(label: "Age", value: workload.ageDisplay)
                    metric(label: "Status", value: workload.status.displayName)
                }
                if workload.kind == .job {
                    GridRow {
                        metric(label: "Active", value: workload.activeDisplay)
                        metric(label: "Succeeded", value: workload.succeededDisplay)
                        metric(label: "Failed", value: workload.failedDisplay)
                    }
                }
                if workload.kind == .cronJob {
                    GridRow {
                        metric(label: "Schedule", value: workload.scheduleDisplay)
                        metric(label: "Mode", value: workload.suspensionDisplay)
                        EmptyView()
                    }
                }
            }
        }
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
    }

    private func progressRow(label: String, ratio: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let ratio {
                    Text(NumberFormatter.percentFormatter.string(from: NSNumber(value: ratio)) ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let ratio {
                ProgressView(value: ratio)
                    .progressViewStyle(.linear)
            } else {
                ProgressView(value: 0)
                    .progressViewStyle(.linear)
                    .tint(.gray.opacity(0.3))
            }
        }
    }

    private func averageRatio(_ values: [Double?]) -> Double? {
        let filtered = values.compactMap { $0 }
        guard !filtered.isEmpty else { return nil }
        return filtered.reduce(0, +) / Double(filtered.count)
    }

    private func close() {
        if let closeAction {
            closeAction()
        } else {
            dismiss()
        }
    }

    private var analytics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resource Utilization")
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                progressRow(label: "CPU", ratio: cpuAverageRatio)
                progressRow(label: "Memory", ratio: memoryAverageRatio)
                progressRow(label: "Disk", ratio: diskAverageRatio)
            }

            if !statusBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Pod Status")
                        .font(.headline)
                    HStack(spacing: 12) {
                        ForEach(statusBreakdown, id: \.label) { item in
                            Label("\(item.count)", systemImage: "circle.fill")
                                .labelStyle(.titleAndIcon)
                                .font(.caption)
                                .foregroundStyle(item.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(item.color.opacity(0.12), in: Capsule())
                                .accessibilityLabel("\(item.label) pods: \(item.count)")
                        }
                    }
                }
            }
        }
    }

    private var scalingControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scale")
                .font(.headline)
            HStack(spacing: 16) {
                Stepper(value: $desiredReplicas, in: 0...10_000, step: 1) {
                    Text("Replicas: \(desiredReplicas)")
                        .font(.body.monospaced())
                }
                Button("Apply Scale") {
                    applyScale()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isScaling || desiredReplicas == workload.replicas)
                if isScaling {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 16) {
            Button {
                Task { await model.editWorkload(cluster: cluster, namespace: namespace, workload: workload) }
            } label: {
                Label("Edit YAML", systemImage: "square.and.pencil")
            }
            .disabled(!workload.kind.supportsEdit)

            Button {
                onFocusPods()
                if presentation == .sheet {
                    close()
                }
            } label: {
                Label("Focus Pods", systemImage: "target")
            }
            .disabled(pods.isEmpty)
        }
    }

    private var podsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pods (\(pods.count))")
                .font(.headline)

            if pods.isEmpty {
                centeredUnavailableView(
                    "No Pods",
                    systemImage: "circle.grid.3x3",
                    description: Text("Pods managed by this workload will appear here.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(pods) { pod in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pod.name)
                                        .font(.body.monospaced())
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Text(pod.nodeName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(pod.phase.displayName)
                                    .font(.caption.bold())
                                    .foregroundStyle(pod.phase.tint)
                            }
                            .padding(10)
                            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.gray.opacity(0.15))
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 220)
            }
        }
    }

    private var footer: some View {
        HStack {
            if presentation == .sheet {
                Button("Close") { close() }
                    .keyboardShortcut(.cancelAction)
            }
            Spacer()
            Text("Context: \(cluster.contextName)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func applyScale() {
        guard !isScaling else { return }
        isScaling = true
        Task {
            await model.scaleWorkload(
                cluster: cluster,
                namespace: namespace,
                workload: workload,
                replicas: desiredReplicas
            )
            isScaling = false
        }
    }
}

private struct EventsSection: View {
    let namespace: Namespace?
    let isConnected: Bool

    var body: some View {
        if !isConnected {
            centeredUnavailableView(
                "Not Connected",
                systemImage: "bolt.slash",
                description: Text("Connect to the cluster to inspect events.")
            )
        } else if namespace == nil {
            centeredUnavailableView(
                "Select a Namespace",
                systemImage: "square.stack.3d.up",
                description: Text("Choose a namespace from the list to view events.")
            )
        } else if let namespace, !namespace.isLoaded {
            VStack {
                ProgressView()
                Text("Loading events…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let namespace, namespace.events.isEmpty {
            centeredUnavailableView(
                "No Events",
                systemImage: "bell",
                description: Text("Events will stream in once the namespace is chosen.")
            )
        } else if let namespace {
            List(namespace.events) { event in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Image(systemName: event.type.icon)
                        .foregroundStyle(event.type.tint)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.message)
                        Text("Count: \(event.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(event.age.displayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 260)
        }
    }
}

private struct ConfigResourceListView: View {
    let cluster: Cluster
    let namespace: Namespace?
    let isConnected: Bool
    let kind: ConfigResourceKind
    let filterState: ConfigFilterState
    let searchText: String

    @EnvironmentObject private var model: AppModel
    @State private var selectedSecret: ConfigResourceSummary?
    @State private var selectedConfigMap: ConfigResourceSummary?

    private var searchTerm: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var baseResources: [ConfigResourceSummary] {
        guard let namespace else { return [] }
        return namespace.configResources
            .filter { $0.kind == kind }
            .filter { filterState.matches($0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filteredResources: [ConfigResourceSummary] {
        guard !searchTerm.isEmpty else { return baseResources }
        return baseResources.filter { resource in
            resource.name.localizedCaseInsensitiveContains(searchTerm) ||
            (resource.summary?.localizedCaseInsensitiveContains(searchTerm) ?? false)
        }
    }

    var body: some View {
        Group {
            if !isConnected {
                centeredUnavailableView(
                    "Not Connected",
                    systemImage: "bolt.slash",
                    description: Text("Connect to the cluster to inspect \(kind.pluralDisplayName.lowercased()).")
                )
            } else if namespace == nil {
                centeredUnavailableView(
                    "Select a Namespace",
                    systemImage: "square.stack.3d.up",
                    description: Text("Choose a namespace to view \(kind.pluralDisplayName.lowercased()).")
                )
            } else if let namespace, !namespace.isLoaded {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading \(kind.pluralDisplayName.lowercased())…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if baseResources.isEmpty {
                centeredUnavailableView(
                    emptyTitle,
                    systemImage: kind.systemImage,
                    description: Text(emptyDescription)
                )
            } else if filteredResources.isEmpty {
                centeredUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No \(kind.pluralDisplayName.lowercased()) match \"\(searchTerm)\".")
                )
            } else {
                ConfigResourceGroupsView(
                    resources: filteredResources,
                    onOpenResource: handleOpenResource
                )
            }
        }
        .sheet(item: $selectedSecret) { secret in
            if let namespace {
                SecretDetailSheet(
                    cluster: cluster,
                    namespace: namespace,
                    secret: secret
                )
                .environmentObject(model)
            } else {
                Text("Secret details unavailable without namespace context.")
                    .padding()
            }
        }
        .sheet(item: $selectedConfigMap) { configMap in
            if let namespace {
                ConfigMapDetailSheet(
                    cluster: cluster,
                    namespace: namespace,
                    configMap: configMap
                )
                .environmentObject(model)
            } else {
                Text("ConfigMap details unavailable without namespace context.")
                    .padding()
            }
        }
    }

    private var emptyTitle: String {
        switch kind {
        case .configMap: return "No ConfigMaps"
        case .secret: return "No Secrets"
        case .resourceQuota: return "No Resource Quotas"
        case .limitRange: return "No Limit Ranges"
        }
    }

    private var emptyDescription: String {
        switch kind {
        case .configMap:
            return "ConfigMaps will appear once created in this namespace."
        case .secret:
            return "Secrets will appear once created in this namespace."
        case .resourceQuota:
            return "Define ResourceQuotas to control namespace usage."
        case .limitRange:
            return "Define LimitRanges to enforce pod resource limits."
        }
    }

    private func handleOpenResource(_ resource: ConfigResourceSummary) {
        switch resource.kind {
        case .secret:
            selectedSecret = resource
        case .configMap:
            selectedConfigMap = resource
        default:
            break
        }
    }
}

private struct HelmSection: View {
    let cluster: Cluster
    let isConnected: Bool
    let isLoading: Bool
    let errorMessage: String?
    let onRefresh: () -> Void

    private var releases: [HelmRelease] {
        cluster.helmReleases.sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Helm Releases")
                    .font(.title3.bold())
                Spacer()
                Button {
                    onRefresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(!isConnected || isLoading)
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let message = errorMessage, !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if !isConnected {
                centeredUnavailableView(
                    "Not Connected",
                    systemImage: "bolt.slash",
                    description: Text("Connect to the cluster to inspect Helm releases.")
                )
            } else if releases.isEmpty {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading Helm releases…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    centeredUnavailableView(
                        "No Releases",
                        systemImage: "shippingbox",
                        description: Text("Helm releases will appear here once installed on the cluster.")
                    )
                }
            } else {
                FixedColumnTable(
                    rows: releases,
                    columns: [
                        FixedTableColumn("Name", width: HelmColumnWidth.name) { release in
                            Text(release.name)
                                .font(.body.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                        },
                        FixedTableColumn("Namespace", width: HelmColumnWidth.namespace) { release in
                            Text(release.namespace)
                                .foregroundStyle(.secondary)
                        },
                        FixedTableColumn("Revision", width: HelmColumnWidth.revision, alignment: .trailing) { release in
                            Text("\(release.revision)")
                                .foregroundStyle(.secondary)
                        },
                        FixedTableColumn("Status", width: HelmColumnWidth.status) { release in
                            Text(release.status.capitalized)
                                .foregroundStyle(release.statusColor)
                        },
                        FixedTableColumn("Updated", width: HelmColumnWidth.updated) { release in
                            Text(release.updatedDisplay)
                                .foregroundStyle(.secondary)
                        },
                        FixedTableColumn("Chart", width: HelmColumnWidth.chart) { release in
                            Text(release.chart)
                                .lineLimit(1)
                        },
                        FixedTableColumn("App Ver", width: HelmColumnWidth.appVersion) { release in
                            Text(release.appVersion ?? "—")
                                .foregroundStyle(.secondary)
                        }
                    ]
                )
            }
        }
    }
}

private struct NetworkSection: View {
    let namespace: Namespace?
    let isConnected: Bool

    private var services: [ServiceSummary] { namespace?.services ?? [] }
    private var ingresses: [IngressSummary] { namespace?.ingresses ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            section(title: "Services", systemImage: "switch.2", emptyMessage: "No services defined in this namespace.") {
                servicesTable
            }
            section(title: "Ingresses", systemImage: "cloud", emptyMessage: "No ingresses defined in this namespace.") {
                ingressTable
            }
        }
    }

    @ViewBuilder
    private func section(title: String, systemImage: String, emptyMessage: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            if !isConnected {
                centeredUnavailableView(
                    "Not Connected",
                    systemImage: "bolt.slash",
                    description: Text("Connect to the cluster to inspect network resources.")
                )
            } else if namespace == nil {
                centeredUnavailableView(
                    "Select a Namespace",
                    systemImage: "square.stack.3d.up",
                    description: Text("Choose a namespace from the list to view network resources.")
                )
            } else if (title == "Services" ? services.isEmpty : ingresses.isEmpty) {
                centeredUnavailableView(
                    "No Entries",
                    systemImage: systemImage,
                    description: Text(emptyMessage)
                )
            } else {
                content()
            }
        }
    }

    private var servicesTable: some View {
        FixedColumnTable(
            rows: services,
            columns: [
                FixedTableColumn("Name", width: ServiceColumnWidth.name) { service in
                    Text(service.name)
                        .font(.body.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                },
                FixedTableColumn("Type", width: ServiceColumnWidth.type) { service in
                    Text(service.type)
                        .foregroundStyle(.secondary)
                },
                FixedTableColumn("Cluster IP", width: ServiceColumnWidth.clusterIP) { service in
                    Text(service.clusterIP)
                        .foregroundStyle(.secondary)
                },
                FixedTableColumn("Ports", width: ServiceColumnWidth.ports) { service in
                    Text(service.ports)
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                },
                FixedTableColumn("Age", width: ServiceColumnWidth.age) { service in
                    Text(service.age?.displayText ?? "—")
                        .foregroundStyle(.secondary)
                }
            ]
        )
    }

    private var ingressTable: some View {
        FixedColumnTable(
            rows: ingresses,
            columns: [
                FixedTableColumn("Name", width: IngressColumnWidth.name) { ingress in
                    Text(ingress.name)
                        .font(.body.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                },
                FixedTableColumn("Class", width: IngressColumnWidth.className) { ingress in
                    Text(ingress.className ?? "—")
                        .foregroundStyle((ingress.className == nil) ? .secondary : .primary)
                },
                FixedTableColumn("Hosts", width: IngressColumnWidth.hosts) { ingress in
                    Text(ingress.hostRules)
                        .lineLimit(2)
                },
                FixedTableColumn("Targets", width: IngressColumnWidth.targets) { ingress in
                    Text(ingress.serviceTargets)
                        .lineLimit(2)
                },
                FixedTableColumn("TLS", width: IngressColumnWidth.tls, alignment: .center) { ingress in
                    Image(systemName: ingress.tls ? "lock.fill" : "lock.open")
                        .foregroundStyle(ingress.tls ? Color.green : .secondary)
                },
                FixedTableColumn("Age", width: IngressColumnWidth.age) { ingress in
                    Text(ingress.age?.displayText ?? "—")
                        .foregroundStyle(.secondary)
                }
            ]
        )
    }
}

private struct StorageSection: View {
    let namespace: Namespace?
    let isConnected: Bool

    private var claims: [PersistentVolumeClaimSummary] { namespace?.persistentVolumeClaims ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Persistent Volume Claims")
                .font(.headline)

            if !isConnected {
                centeredUnavailableView(
                    "Not Connected",
                    systemImage: "bolt.slash",
                    description: Text("Connect to the cluster to inspect storage resources.")
                )
            } else if namespace == nil {
                centeredUnavailableView(
                    "Select a Namespace",
                    systemImage: "square.stack.3d.up",
                    description: Text("Choose a namespace from the list to view storage resources.")
                )
            } else if claims.isEmpty {
                centeredUnavailableView(
                    "No Persistent Volume Claims",
                    systemImage: "externaldrive",
                    description: Text("PVCs will appear here when defined in the namespace.")
                )
            } else {
                FixedColumnTable(
                    rows: claims,
                    columns: [
                        FixedTableColumn("Name", width: PVCColumnWidth.name) { claim in
                            Text(claim.name)
                                .font(.body.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                        },
                        FixedTableColumn("Status", width: PVCColumnWidth.status) { claim in
                            Text(claim.status)
                                .foregroundStyle(.secondary)
                        },
                        FixedTableColumn("Capacity", width: PVCColumnWidth.capacity) { claim in
                            Text(claim.capacity ?? "—")
                                .foregroundStyle(claim.capacity == nil ? .secondary : .primary)
                        },
                        FixedTableColumn("Storage Class", width: PVCColumnWidth.storageClass) { claim in
                            Text(claim.storageClass ?? "—")
                                .foregroundStyle(claim.storageClass == nil ? .secondary : .primary)
                        },
                        FixedTableColumn("Volume", width: PVCColumnWidth.volume) { claim in
                            Text(claim.volumeName ?? "—")
                                .foregroundStyle(claim.volumeName == nil ? .secondary : .primary)
                        },
                        FixedTableColumn("Age", width: PVCColumnWidth.age) { claim in
                            Text(claim.age?.displayText ?? "—")
                                .foregroundStyle(.secondary)
                        }
                    ]
                )
            }
        }
    }
}

private struct AccessControlSection: View {
    let namespace: Namespace?
    let isConnected: Bool

    private var serviceAccounts: [ServiceAccountSummary] { namespace?.serviceAccounts ?? [] }
    private var roles: [RoleSummary] { namespace?.roles ?? [] }
    private var roleBindings: [RoleBindingSummary] { namespace?.roleBindings ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            section(title: "Service Accounts", entries: serviceAccounts.isEmpty) {
                FixedColumnTable(
                    rows: serviceAccounts,
                    columns: [
                        FixedTableColumn("Name", width: ServiceAccountColumn.name) { account in
                            Text(account.name)
                                .font(.body.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                        },
                        FixedTableColumn("Secrets", width: ServiceAccountColumn.secrets, alignment: .trailing) { account in
                            Text("\(account.secretCount)")
                                .foregroundStyle(.secondary)
                        },
                        FixedTableColumn("Age", width: ServiceAccountColumn.age) { account in
                            Text(account.age?.displayText ?? "—")
                                .foregroundStyle(.secondary)
                        }
                    ]
                )
            }

            section(title: "Roles", entries: roles.isEmpty) {
                FixedColumnTable(
                    rows: roles,
                    columns: [
                        FixedTableColumn("Name", width: RoleColumn.name) { role in
                            Text(role.name)
                                .font(.body.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                        },
                        FixedTableColumn("Rules", width: RoleColumn.rules, alignment: .trailing) { role in
                            Text("\(role.ruleCount)")
                                .foregroundStyle(.secondary)
                        },
                        FixedTableColumn("Age", width: RoleColumn.age) { role in
                            Text(role.age?.displayText ?? "—")
                                .foregroundStyle(.secondary)
                        }
                    ]
                )
            }

            section(title: "Role Bindings", entries: roleBindings.isEmpty) {
                FixedColumnTable(
                    rows: roleBindings,
                    columns: [
                        FixedTableColumn("Name", width: RoleBindingColumn.name) { binding in
                            Text(binding.name)
                                .font(.body.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                        },
                        FixedTableColumn("Subjects", width: RoleBindingColumn.subjects, alignment: .trailing) { binding in
                            Text("\(binding.subjectCount)")
                                .foregroundStyle(.secondary)
                        },
                        FixedTableColumn("Role Ref", width: RoleBindingColumn.roleRef) { binding in
                            Text(binding.roleRef)
                        },
                        FixedTableColumn("Age", width: RoleBindingColumn.age) { binding in
                            Text(binding.age?.displayText ?? "—")
                                .foregroundStyle(.secondary)
                        }
                    ]
                )
            }
        }
    }

    @ViewBuilder
    private func section(title: String, entries: Bool, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            if !isConnected {
                centeredUnavailableView(
                    "Not Connected",
                    systemImage: "bolt.slash",
                    description: Text("Connect to the cluster to inspect access control objects.")
                )
            } else if namespace == nil {
                centeredUnavailableView(
                    "Select a Namespace",
                    systemImage: "square.stack.3d.up",
                    description: Text("Choose a namespace from the list to view access control objects.")
                )
            } else if entries {
                centeredUnavailableView(
                    "No Entries",
                    systemImage: "lock.shield",
                    description: Text("No resources found in this namespace.")
                )
            } else {
                content()
            }
        }
    }

    private enum ServiceAccountColumn {
        static let name: CGFloat = 220
        static let secrets: CGFloat = 80
        static let age: CGFloat = 80
    }

    private enum RoleColumn {
        static let name: CGFloat = 220
        static let rules: CGFloat = 80
        static let age: CGFloat = 80
    }

    private enum RoleBindingColumn {
        static let name: CGFloat = 220
        static let subjects: CGFloat = 80
        static let roleRef: CGFloat = 200
        static let age: CGFloat = 80
    }
}

private struct CustomResourcesSection: View {
    let cluster: Cluster
    let isConnected: Bool

    private var resources: [CustomResourceDefinitionSummary] { cluster.customResources }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Resource Definitions")
                .font(.headline)

            if !isConnected {
                centeredUnavailableView(
                    "Not Connected",
                    systemImage: "bolt.slash",
                    description: Text("Connect to the cluster to inspect custom resources.")
                )
            } else if resources.isEmpty {
                centeredUnavailableView(
                    "No CRDs",
                    systemImage: "puzzlepiece.extension",
                    description: Text("Install Helm charts or apply CRDs to populate this list.")
                )
            } else {
                FixedColumnTable(
                    rows: resources,
                    columns: [
                        FixedTableColumn("Name", width: CustomResourceColumn.name) { crd in
                            Text(crd.name)
                                .font(.body.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                        },
                        FixedTableColumn("Group", width: CustomResourceColumn.group) { crd in
                            Text(crd.group)
                                .foregroundStyle(.secondary)
                        },
                        FixedTableColumn("Version", width: CustomResourceColumn.version) { crd in
                            Text(crd.version)
                                .foregroundStyle(.secondary)
                        },
                        FixedTableColumn("Kind", width: CustomResourceColumn.kind) { crd in
                            Text(crd.kind)
                        },
                        FixedTableColumn("Scope", width: CustomResourceColumn.scope) { crd in
                            Text(crd.scope)
                                .foregroundStyle(.secondary)
                        },
                        FixedTableColumn("Short Names", width: CustomResourceColumn.shortNames) { crd in
                            let names = crd.shortNames.joined(separator: ", ")
                            Text(names.isEmpty ? "—" : names)
                                .foregroundStyle(names.isEmpty ? .secondary : .primary)
                        },
                        FixedTableColumn("Age", width: CustomResourceColumn.age) { crd in
                            Text(crd.age?.displayText ?? "—")
                                .foregroundStyle(.secondary)
                        }
                    ]
                )
            }
        }
    }

    private enum CustomResourceColumn {
        static let name: CGFloat = 220
        static let group: CGFloat = 160
        static let version: CGFloat = 120
        static let kind: CGFloat = 160
        static let scope: CGFloat = 120
        static let shortNames: CGFloat = 220
        static let age: CGFloat = 80
    }
}

private struct FixedTableColumn<Row> {
    let title: String
    let width: CGFloat
    let alignment: Alignment
    private let renderer: (Row) -> AnyView

    init(_ title: String, width: CGFloat, alignment: Alignment = .leading, @ViewBuilder content: @escaping (Row) -> some View) {
        self.title = title
        self.width = width
        self.alignment = alignment
        self.renderer = { row in AnyView(content(row)) }
    }

    func view(for row: Row) -> AnyView {
        renderer(row)
    }
}

private struct FixedColumnTable<Row: Identifiable>: View {
    let rows: [Row]
    let columns: [FixedTableColumn<Row>]
    var selection: Binding<Set<Row.ID>>? = nil
    var allowsMultipleSelection: Bool = true
    var highlightSelection: Bool = true
    var selectionColor: Color = Color.accentColor.opacity(0.08)
    var rowVerticalPadding: CGFloat = 6
    var rowHorizontalPadding: CGFloat = 12
    var minimumRowHeight: CGFloat = 34
    var headerBackground: Color = Color(nsColor: .underPageBackgroundColor)
    var tableBackground: Color = Color(nsColor: .textBackgroundColor)
    var showsRowDividers: Bool = true
    var focusID: Row.ID? = nil
    var onRowTap: ((Row) -> Void)? = nil
    var onRowDoubleTap: ((Row) -> Void)? = nil
    var rowBackground: ((Row, Bool) -> Color?)? = nil

    private var minimumHeight: CGFloat {
        let headerAndPadding: CGFloat = 48
        let contentHeight = CGFloat(max(rows.count, 1)) * minimumRowHeight
        let minRowsHeight = minimumRowHeight * 4
        let maxRowsHeight = minimumRowHeight * 14
        let clampedHeight = min(max(contentHeight, minRowsHeight), maxRowsHeight)
        return clampedHeight + headerAndPadding
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            rowView(for: row, index: index)
                                .id(row.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: minimumHeight, maxHeight: .infinity, alignment: .topLeading)
            }
            .background(tableBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onChange(of: focusID) { _, newValue in
                guard let newValue else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private func rowView(for row: Row, index: Int) -> some View {
        let isSelected = selection?.wrappedValue.contains(row.id) ?? false
        let singleTap = makeSingleTapHandler(for: row)

        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(Array(columns.enumerated()), id: \.offset) { columnPair in
                    columnPair.element.view(for: row)
                        .frame(width: columnPair.element.width, alignment: columnPair.element.alignment)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, rowVerticalPadding)
            .padding(.horizontal, rowHorizontalPadding)
            .background(backgroundColor(for: row, isSelected: isSelected))
            .contentShape(Rectangle())
            .onTapGesture(perform: singleTap)
            .onTapGesture(count: 2) {
                onRowDoubleTap?(row)
            }

            if showsRowDividers && index < rows.count - 1 {
                Divider()
            }
        }
    }

    private func makeSingleTapHandler(for row: Row) -> () -> Void {
        {
            if let binding = selection {
                var updated = binding.wrappedValue
                if allowsMultipleSelection {
                    if updated.contains(row.id) {
                        updated.remove(row.id)
                    } else {
                        updated.insert(row.id)
                    }
                } else {
                    updated = [row.id]
                }
                binding.wrappedValue = updated
            }
            onRowTap?(row)
        }
    }

    private func backgroundColor(for row: Row, isSelected: Bool) -> Color {
        if let custom = rowBackground?(row, isSelected) {
            return custom
        }
        if highlightSelection && isSelected {
            return selectionColor
        }
        return Color.clear
    }

    private var header: some View {
        HStack(spacing: 8) {
            ForEach(Array(columns.enumerated()), id: \.offset) { columnPair in
                Text(columnPair.element.title)
                    .frame(width: columnPair.element.width, alignment: columnPair.element.alignment)
            }
            Spacer(minLength: 0)
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(headerBackground)
    }
}

private enum HelmColumnWidth {
    static let name: CGFloat = 200
    static let namespace: CGFloat = 160
    static let revision: CGFloat = 80
    static let status: CGFloat = 120
    static let updated: CGFloat = 160
    static let chart: CGFloat = 200
    static let appVersion: CGFloat = 120
}

private enum ServiceColumnWidth {
    static let name: CGFloat = 220
    static let type: CGFloat = 120
    static let clusterIP: CGFloat = 160
    static let ports: CGFloat = 160
    static let external: CGFloat = 200
    static let health: CGFloat = 120
    static let latency: CGFloat = 130
    static let age: CGFloat = 80
    static let actions: CGFloat = 52
}

private enum IngressColumnWidth {
    static let name: CGFloat = 220
    static let className: CGFloat = 140
    static let hosts: CGFloat = 220
    static let targets: CGFloat = 220
    static let tls: CGFloat = 60
    static let age: CGFloat = 80
}

private enum PVCColumnWidth {
    static let name: CGFloat = 220
    static let status: CGFloat = 120
    static let capacity: CGFloat = 120
    static let storageClass: CGFloat = 160
    static let volume: CGFloat = 160
    static let age: CGFloat = 80
    static let actions: CGFloat = 52
}

private enum WorkloadColumnWidth {
    static let kind: CGFloat = 80
    static let name: CGFloat = 240
    static let desired: CGFloat = 72
    static let ready: CGFloat = 72
    static let updated: CGFloat = 96
    static let available: CGFloat = 96
    static let active: CGFloat = 80
    static let succeeded: CGFloat = 90
    static let failed: CGFloat = 80
    static let schedule: CGFloat = 160
    static let mode: CGFloat = 80
    static let age: CGFloat = 70
    static let status: CGFloat = 120
    static let alerts: CGFloat = 80
    static let actions: CGFloat = 52
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var systemImage: String? = nil
    var tint: Color = .accentColor
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(.small)
                }
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
            .overlay(
                Capsule()
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? tint : Color.primary)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var backgroundColor: Color {
        if isSelected {
            return tint.opacity(0.2)
        }
        return Color(nsColor: .controlBackgroundColor)
    }

    private var borderColor: Color {
        isSelected ? tint.opacity(0.6) : Color.secondary.opacity(0.25)
    }
}

@ViewBuilder
private func centeredUnavailableView(
    _ title: String,
    systemImage: String,
    description: Text
) -> some View {
    ContentUnavailableView(title, systemImage: systemImage, description: description)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
}


private enum PodColumnWidth {
    static let name: CGFloat = 260
    static let containers: CGFloat = 180
    static let restarts: CGFloat = 80
    static let node: CGFloat = 180
    static let status: CGFloat = 120
    static let alerts: CGFloat = 80
    static let age: CGFloat = 80
    static let actions: CGFloat = 52
}

private struct EventTimelineView: View {
    let events: [EventSummary]

    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private var orderedEvents: [EventSummary] {
        events.sorted { eventDate($0) > eventDate($1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(orderedEvents.enumerated()), id: \.element.id) { index, event in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(color(for: event))
                            .frame(width: 8, height: 8)
                        if index < orderedEvents.count - 1 {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 2, height: 18)
                                .padding(.top, 2)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Label(event.type.rawValue.capitalized, systemImage: icon(for: event))
                                .labelStyle(.titleAndIcon)
                                .font(.caption.bold())
                                .foregroundStyle(color(for: event))
                            if event.count > 1 {
                                Text("×\(event.count)")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(relativeTime(for: event))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(event.message)
                            .font(.caption)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                    }
                }
            }
        }
    }

    private func eventDate(_ event: EventSummary) -> Date {
        if let timestamp = event.timestamp {
            return timestamp
        }
        let now = Date()
        switch event.age {
        case .minutes(let value):
            return now.addingTimeInterval(Double(-value * 60))
        case .hours(let value):
            return now.addingTimeInterval(Double(-value * 3600))
        case .days(let value):
            return now.addingTimeInterval(Double(-value * 86400))
        }
    }

    private func relativeTime(for event: EventSummary) -> String {
        EventTimelineView.formatter.localizedString(for: eventDate(event), relativeTo: Date())
    }

    private func color(for event: EventSummary) -> Color {
        switch event.type {
        case .error: return .red
        case .warning: return .orange
        case .normal: return .blue
        }
    }

    private func icon(for event: EventSummary) -> String {
        switch event.type {
        case .error: return "exclamationmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .normal: return "info.circle.fill"
        }
    }
}

private struct NavigationSidebar: View {
    @Binding var selectedTab: ClusterDetailView.Tab
    @Binding var expandedCategories: Set<ClusterDetailView.ResourceCategory>
    let isConnected: Bool
    @State private var hoveredCategory: ClusterDetailView.ResourceCategory?
    @State private var hoveredTab: ClusterDetailView.Tab?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(ClusterDetailView.ResourceCategory.navigationOrder, id: \.id) { category in
                    let tabs = category.tabs
                    if !tabs.isEmpty {
                        if category == .namespaces || category == .events {
                            navigationRow(for: tabs[0])
                                .padding(.top, 6)
                        } else {
                            DisclosureGroup(
                                isExpanded: binding(for: category)
                            ) {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(tabs, id: \.self) { tab in
                                        navigationRow(for: tab)
                                    }
                                }
                                .padding(.top, 6)
                            } label: {
                            categoryLabel(for: category)
                        }
                        .disclosureGroupStyle(.automatic)
                    }
                }
            }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func navigationRow(for tab: ClusterDetailView.Tab) -> some View {
        let isSelected = selectedTab == tab
        let disabled = tab.requiresConnection && !isConnected
        return Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .frame(width: 18)
                Text(tab.title)
                    .font(.body)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isSelected ? Color.accentColor.opacity(0.18) : Color.accentColor.opacity(hoveredTab == tab ? 0.12 : 0)
                    )
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(disabled ? Color.secondary : Color.primary)
        .disabled(disabled)
        .onHover { hovering in
            hoveredTab = hovering ? tab : nil
        }
    }

    private func binding(for category: ClusterDetailView.ResourceCategory) -> Binding<Bool> {
        Binding(
            get: { expandedCategories.contains(category) },
            set: { isExpanded in
                if isExpanded {
                    expandedCategories.insert(category)
                } else {
                    expandedCategories.remove(category)
                }
            }
        )
    }

    private func toggle(_ category: ClusterDetailView.ResourceCategory) {
        if expandedCategories.contains(category) {
            expandedCategories.remove(category)
        } else {
            expandedCategories.insert(category)
        }
    }

    private func categoryLabel(for category: ClusterDetailView.ResourceCategory) -> some View {
        HStack(spacing: 8) {
            if let icon = category.systemImage {
                Image(systemName: icon)
                    .font(.caption)
            }
            Text(category.menuTitle.uppercased())
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.accentColor.opacity(hoveredCategory == category ? 0.12 : 0))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredCategory = hovering ? category : nil
        }
        .onTapGesture {
            toggle(category)
        }
    }
}

private struct ConfigResourceGroupsView: View {
    let resources: [ConfigResourceSummary]
    let onOpenResource: (ConfigResourceSummary) -> Void

    private struct Group: Identifiable {
        let kind: ConfigResourceKind
        let items: [ConfigResourceSummary]
        var id: ConfigResourceKind { kind }
    }

    private var groups: [Group] {
        ConfigResourceKind.allCases.compactMap { kind in
            let items = resources.filter { $0.kind == kind }
            return items.isEmpty ? nil : Group(kind: kind, items: items)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(groups) { group in
                ConfigResourceGroupView(
                    kind: group.kind,
                    resources: group.items,
                    onOpenResource: onOpenResource
                )
            }
        }
    }
}

private struct ConfigResourceGroupView: View {
    let kind: ConfigResourceKind
    let resources: [ConfigResourceSummary]
    let onOpenResource: (ConfigResourceSummary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label(kind.pluralDisplayName, systemImage: kind.systemImage)
                    .font(.headline)
                Spacer()
                Text("\(resources.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            FixedColumnTable(
                rows: resources,
                columns: tableColumns
            )
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var tableColumns: [FixedTableColumn<ConfigResourceSummary>] {
        var columns: [FixedTableColumn<ConfigResourceSummary>] = [
            FixedTableColumn("Name", width: ConfigColumn.name) { resource in
                Text(resource.name)
                    .font(.body.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
            },
            FixedTableColumn("Type", width: ConfigColumn.type) { resource in
                Text(resource.typeDescription ?? resource.kind.displayName)
                    .foregroundStyle(.secondary)
            },
            FixedTableColumn("Entries", width: ConfigColumn.entries, alignment: .trailing) { resource in
                if let count = resource.dataCount {
                    Text("\(count)")
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .foregroundStyle(.secondary)
                }
            },
            FixedTableColumn("Summary", width: ConfigColumn.summary) { resource in
                if let summary = resource.summary, !summary.isEmpty {
                    Text(summary)
                        .lineLimit(2)
                } else {
                    Text("—")
                        .foregroundStyle(.secondary)
                }
            },
            FixedTableColumn("Age", width: ConfigColumn.age) { resource in
                if let age = resource.age {
                    Text(age.displayText)
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .foregroundStyle(.secondary)
                }
            }
        ]

        if kind == .secret || kind == .configMap {
            columns.append(
                FixedTableColumn("Actions", width: ConfigColumn.actions, alignment: .trailing) { resource in
                    Button {
                        onOpenResource(resource)
                    } label: {
                        if kind == .secret {
                            Image(systemName: resource.permissions.canReveal ? "eye" : "eye.slash")
                        } else {
                            Image(systemName: "eye")
                        }
                    }
                    .buttonStyle(.borderless)
                    .help(kind == .secret
                        ? (resource.permissions.canReveal ? "View secret data" : (resource.permissions.revealReason ?? "View secret metadata (plaintext restricted by RBAC)."))
                        : (resource.permissions.canEdit ? "View and edit config map" : (resource.permissions.editReason ?? "Editing restricted by RBAC.")))
                }
            )
        }

        return columns
    }

    private enum ConfigColumn {
        static let name: CGFloat = 220
        static let type: CGFloat = 160
        static let entries: CGFloat = 80
        static let summary: CGFloat = 260
        static let age: CGFloat = 80
        static let actions: CGFloat = 60
    }
}

private struct WorkloadGroupsView: View {
    let workloads: [WorkloadSummary]
    let onSelect: (WorkloadSummary) -> Void

    private struct Group: Identifiable {
        let kind: WorkloadKind
        let items: [WorkloadSummary]
        var id: WorkloadKind { kind }
    }

    private var grouped: [Group] {
        WorkloadKind.allCases.compactMap { kind in
            let items = workloads.filter { $0.kind == kind }
            return items.isEmpty ? nil : Group(kind: kind, items: items)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(grouped) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.kind.displayName)
                            .font(.headline)
                        WorkloadTableView(kind: group.kind, workloads: group.items, onSelect: onSelect)
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
    }
}

private struct FilteredWorkloadList: View {
    let workloads: [WorkloadSummary]
    let kind: WorkloadKind
    let onSelect: (WorkloadSummary) -> Void

    var body: some View {
        if workloads.isEmpty {
            centeredUnavailableView(
                "No \(kind.displayName)s",
                systemImage: kind.systemImage,
                description: Text("No \(kind.displayName.lowercased())s are present in the selected namespace.")
            )
        } else {
            WorkloadTableView(kind: kind, workloads: workloads, onSelect: onSelect)
        }
    }
}

private struct WorkloadTableView: View {
    let kind: WorkloadKind
    let workloads: [WorkloadSummary]
    let onSelect: (WorkloadSummary) -> Void

    private var showsReplicaColumns: Bool {
        switch kind {
        case .job, .cronJob: return false
        default: return true
        }
    }

    private var showsUpdatedColumn: Bool {
        switch kind {
        case .deployment, .statefulSet, .replicaSet, .daemonSet: return true
        default: return false
        }
    }

    private var showsAvailableColumn: Bool {
        switch kind {
        case .job, .cronJob: return false
        default: return true
        }
    }

    private var showsJobColumns: Bool { kind == .job }
    private var showsScheduleColumn: Bool { kind == .cronJob }
    private var showsSuspensionColumn: Bool { kind == .cronJob }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color(nsColor: .underPageBackgroundColor))
                Divider()
                LazyVStack(spacing: 0) {
                    ForEach(workloads) { workload in
                        Button {
                            onSelect(workload)
                        } label: {
                            row(for: workload)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(minHeight: minHeight)
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            Text("Name")
                .frame(width: Column.name, alignment: .leading)
            if showsReplicaColumns {
                Text("Desired")
                    .frame(width: Column.desired, alignment: .leading)
                Text("Ready")
                    .frame(width: Column.ready, alignment: .leading)
            }
            if showsUpdatedColumn {
                Text("Updated")
                    .frame(width: Column.updated, alignment: .leading)
            }
            if showsAvailableColumn {
                Text("Available")
                    .frame(width: Column.available, alignment: .leading)
            }
            if showsJobColumns {
                Text("Active")
                    .frame(width: Column.active, alignment: .leading)
                Text("Succeeded")
                    .frame(width: Column.succeeded, alignment: .leading)
                Text("Failed")
                    .frame(width: Column.failed, alignment: .leading)
            }
            if showsScheduleColumn {
                Text("Schedule")
                    .frame(width: Column.schedule, alignment: .leading)
            }
            if showsSuspensionColumn {
                Text("Mode")
                    .frame(width: Column.mode, alignment: .leading)
            }
            Text("Age")
                .frame(width: Column.age, alignment: .leading)
            Text("Status")
                .frame(width: Column.status, alignment: .leading)
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
    }

    private func row(for workload: WorkloadSummary) -> some View {
        HStack(spacing: 12) {
            Text(workload.name)
                .font(.body.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: Column.name, alignment: .leading)

            if showsReplicaColumns {
                Text(workload.desiredDisplay)
                    .foregroundStyle(.secondary)
                    .frame(width: Column.desired, alignment: .leading)
                Text(workload.readyDisplay)
                    .foregroundStyle(.secondary)
                    .frame(width: Column.ready, alignment: .leading)
            }

            if showsUpdatedColumn {
                Text(workload.updatedDisplay)
                    .foregroundStyle(.secondary)
                    .frame(width: Column.updated, alignment: .leading)
            }

            if showsAvailableColumn {
                Text(workload.availableDisplay)
                    .foregroundStyle(.secondary)
                    .frame(width: Column.available, alignment: .leading)
            }

            if showsJobColumns {
                Text(workload.activeDisplay)
                    .foregroundStyle(.secondary)
                    .frame(width: Column.active, alignment: .leading)
                Text(workload.succeededDisplay)
                    .foregroundStyle(.secondary)
                    .frame(width: Column.succeeded, alignment: .leading)
                Text(workload.failedDisplay)
                    .foregroundStyle(workload.failedCount ?? 0 > 0 ? Color.red : .secondary)
                    .frame(width: Column.failed, alignment: .leading)
            }

            if showsScheduleColumn {
                Text(workload.scheduleDisplay)
                    .font(.body.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: Column.schedule, alignment: .leading)
            }

            if showsSuspensionColumn {
                let isPaused = workload.isSuspended == true
                Text(workload.suspensionDisplay)
                    .foregroundStyle(isPaused ? Color.orange : .secondary)
                    .frame(width: Column.mode, alignment: .leading)
            }

            Text(workload.ageDisplay)
                .foregroundStyle(.secondary)
                .frame(width: Column.age, alignment: .leading)

            Text(workload.status.displayName)
                .foregroundStyle(workload.status.tint)
                .frame(width: Column.status, alignment: .leading)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }

    private enum Column {
        static let name: CGFloat = 220
        static let desired: CGFloat = 70
        static let ready: CGFloat = 80
        static let updated: CGFloat = 90
        static let available: CGFloat = 90
        static let active: CGFloat = 80
        static let succeeded: CGFloat = 90
        static let failed: CGFloat = 80
        static let schedule: CGFloat = 160
        static let mode: CGFloat = 80
        static let age: CGFloat = 60
        static let status: CGFloat = 110
    }

    private var minHeight: CGFloat {
        let rows = CGFloat(max(workloads.count, 1))
        return rows * 32 + 72
    }

}

private struct ApplicationsSection: View {
    let namespace: Namespace?
    let isConnected: Bool
    let onSelect: (WorkloadSummary) -> Void

    var body: some View {
        WorkloadsSection(namespace: namespace, isConnected: isConnected, onSelect: onSelect)
    }
}

private struct NodesSection: View {
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

private struct NamespacesSection: View {
    let isConnected: Bool
    let namespaces: [Namespace]
    let selectedNamespaceID: Namespace.ID?
    let onSelect: (Namespace) -> Void

    var body: some View {
        if !isConnected {
            centeredUnavailableView(
                "Not Connected",
                systemImage: "bolt.slash",
                description: Text("Connect to the cluster to browse namespaces.")
            )
        } else if namespaces.isEmpty {
            centeredUnavailableView(
                "No Namespaces",
                systemImage: "folder.badge.questionmark",
                description: Text("Namespaces will appear once the cluster loads them.")
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(namespaces, id: \Namespace.id) { namespace in
                    NamespaceRow(namespace: namespace, isSelected: namespace.id == selectedNamespaceID) {
                        onSelect(namespace)
                    }
                }
            }
        }
    }
}

private struct NamespaceRow: View {
    let namespace: Namespace
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                namespaceIcon
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(namespace.name)
                        .font(.body)
                    if namespace.alertCount > 0 {
                        Text("Alerts: \(namespace.alertCount)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if !namespace.isLoaded {
                        Text("Not loaded")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.gray.opacity(0.08), lineWidth: isSelected ? 1.25 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var namespaceIcon: some View {
        let isAll = namespace.id == AppModel.allNamespacesNamespaceID
        let symbol = isAll ? "globe" : "square.stack.3d.up" 
        let color: Color = isSelected ? .accentColor : (isAll ? .blue : .secondary)

        return ZStack {
            Circle()
                .fill(color.opacity(0.12))
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}

private struct PlaceholderSection: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private enum PercentageFormatter {
    static func format(_ value: Double?) -> String {
        guard let value else { return "–" }
        return NumberFormatter.percentFormatter.string(from: NSNumber(value: value)) ?? "–"
    }
}

private enum DataRateFormatter {
    static func format(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "–" }
        let units: [String] = ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"]
        var rate = value
        var index = 0
        while rate >= 1024, index < units.count - 1 {
            rate /= 1024
            index += 1
        }
        let formatted = NumberFormatter.dataRateFormatter.string(from: NSNumber(value: rate)) ?? String(format: "%.1f", rate)
        return "\(formatted) \(units[index])"
    }
}

private extension NumberFormatter {
    static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    static let dataRateFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }()
}

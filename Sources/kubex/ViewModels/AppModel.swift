import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var clusters: [Cluster] = []
    @Published private(set) var activePortForwards: [ActivePortForward] = []
    @Published private(set) var connectedClusterID: Cluster.ID?
    @Published var selectedClusterID: Cluster.ID? {
        didSet { persistSelection() }
    }
    @Published var selectedNamespaceID: Namespace.ID? {
        didSet { persistSelection() }
    }
    @Published var selectedResourceTab: ClusterDetailView.Tab = .overview {
        didSet { persistSelection() }
    }
    @Published var error: AppModelError?
    @Published var banner: BannerMessage?
    @Published private(set) var kubeconfigSources: [String] = []
    @Published private(set) var nodeActionsInProgress: Set<String> = []
    @Published private(set) var secretActionFeedback: SecretActionFeedback?
    @Published private(set) var configMapActionFeedback: ConfigMapActionFeedback?
    @Published private(set) var nodeActionFeedback: [String: NodeActionFeedback] = [:]
    @Published private(set) var helmLoadingContexts: Set<String> = []
    @Published private(set) var helmErrors: [String: String] = [:]
    @Published private(set) var inspectorSelection: InspectorSelection = .none
    @Published private(set) var clusterOverviewMetrics: [Cluster.ID: ClusterOverviewMetrics] = [:]
    @Published var workloadSortOption: WorkloadSortOption = .default {
        didSet { persistSortPreferencesIfNeeded() }
    }
    @Published var nodeSortOption: NodeSortOption = .default {
        didSet { persistSortPreferencesIfNeeded() }
    }
    @Published var workloadFilterState: WorkloadFilterState = .empty {
        didSet { persistFilterPreferencesIfNeeded() }
    }
    @Published var podFilterState: PodFilterState = .empty {
        didSet { persistFilterPreferencesIfNeeded() }
    }
    @Published var nodeFilterState: NodeFilterState = .empty {
        didSet { persistFilterPreferencesIfNeeded() }
    }
    @Published var configFilterState: ConfigFilterState = .empty {
        didSet { persistFilterPreferencesIfNeeded() }
    }
    @Published var isQuickSearchPresented: Bool = false
    @Published var quickSearchQuery: String = "" {
        didSet { refreshQuickSearchResults() }
    }
    @Published var quickSearchNamespaceFilter: Namespace.ID? = AppModel.allNamespacesNamespaceID {
        didSet { refreshQuickSearchResults() }
    }
    @Published private(set) var quickSearchResults: [QuickSearchResult] = []
    @Published private(set) var quickSearchFocus: QuickSearchSelection?

    private var kubeconfigEnvValue: String? {
        AppModel.joinedKubeconfigPath(for: kubeconfigSources)
    }

    struct ExecCommandOutput: Equatable {
        var output: String
        var exitCode: Int32?
        var isError: Bool

        var displayExitCode: String {
            guard let exitCode else {
                return isError ? "exit status ?" : "exit status 0"
            }
            return "exit status \(exitCode)"
        }
    }

    static let allNamespacesNamespaceID = UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!
    static let allNamespacesDisplayName = "All Namespaces"
    private static let allNamespacesPreferenceValue = "__ALL_NAMESPACES__"

    enum InspectorSelection: Equatable {
        case none
        case workload(clusterID: Cluster.ID, namespaceID: Namespace.ID, workloadID: WorkloadSummary.ID)
        case pod(clusterID: Cluster.ID, namespaceID: Namespace.ID, podID: PodSummary.ID)
        case helm(clusterID: Cluster.ID, releaseID: HelmRelease.ID)
        case service(clusterID: Cluster.ID, namespaceID: Namespace.ID, serviceID: ServiceSummary.ID)
        case ingress(clusterID: Cluster.ID, namespaceID: Namespace.ID, ingressID: IngressSummary.ID)
        case persistentVolumeClaim(clusterID: Cluster.ID, namespaceID: Namespace.ID, claimID: PersistentVolumeClaimSummary.ID)
    }

    enum QuickSearchTarget: Equatable, Hashable {
        case tab(ClusterDetailView.Tab)
        case namespace(Namespace.ID)
        case workload(kind: WorkloadKind, namespaceID: Namespace.ID, workloadID: WorkloadSummary.ID)
        case pod(namespaceID: Namespace.ID, podID: PodSummary.ID)
        case node(nodeID: NodeInfo.ID)
        case helm(releaseID: HelmRelease.ID)
        case service(namespaceID: Namespace.ID, serviceID: ServiceSummary.ID)
        case ingress(namespaceID: Namespace.ID, ingressID: IngressSummary.ID)
        case persistentVolumeClaim(namespaceID: Namespace.ID, claimID: PersistentVolumeClaimSummary.ID)
        case configResource(kind: ConfigResourceKind, namespaceID: Namespace.ID, resourceID: ConfigResourceSummary.ID)
    }

    struct QuickSearchResult: Identifiable, Hashable {
        let id: UUID
        let clusterID: Cluster.ID
        let title: String
        let subtitle: String?
        let detail: String?
        let category: String
        let iconSystemName: String
        let target: QuickSearchTarget

        init(
            id: UUID = UUID(),
            clusterID: Cluster.ID,
            title: String,
            subtitle: String? = nil,
            detail: String? = nil,
            category: String,
            iconSystemName: String,
            target: QuickSearchTarget
        ) {
            self.id = id
            self.clusterID = clusterID
            self.title = title
            self.subtitle = subtitle
            self.detail = detail
            self.category = category
            self.iconSystemName = iconSystemName
            self.target = target
        }
    }

    struct QuickSearchSelection: Identifiable, Equatable {
        let id: UUID
        let clusterID: Cluster.ID
        let target: QuickSearchTarget

        init(clusterID: Cluster.ID, target: QuickSearchTarget) {
            self.id = UUID()
            self.clusterID = clusterID
            self.target = target
        }
    }

    private struct ClusterMetricHistory {
        var cpuPoints: [MetricPoint] = []
        var memoryPoints: [MetricPoint] = []
        var diskPoints: [MetricPoint] = []
        var networkPoints: [MetricPoint] = []
        var lastNetworkTotals: NetworkTotals?
        var nodeHeatmap: [HeatmapEntry] = []
        var podHeatmap: [HeatmapEntry] = []
    }

    private struct NetworkTotals {
        let rxBytes: Double
        let txBytes: Double
        let timestamp: Date
    }

    private struct WorkloadHistoryKey: Hashable {
        let namespace: String
        let name: String
        let kind: WorkloadKind
    }

    private var clusterService: ClusterService
    private var logService: LogStreamingService
    private var execService: ExecService
    private var portForwardService: PortForwardService
    private var editService: EditService
    private var helmService: HelmService
    private let telemetryService: TelemetryService
    private var clusterMetricsHistory: [Cluster.ID: ClusterMetricHistory] = [:]
    private var workloadRolloutHistory: [Cluster.ID: [WorkloadHistoryKey: WorkloadRolloutSeries]] = [:]

    private var clusterRefreshTask: Task<Void, Never>?
    private var namespaceRefreshTasks: [String: Task<Void, Never>] = [:]
    private var namespaceRetryTasks: [String: Task<Void, Never>] = [:]
    private let clusterRefreshInterval: TimeInterval = 30
    private let namespaceRefreshInterval: TimeInterval = 20
    private var clusterRefreshIntervalNanoseconds: UInt64 { UInt64(max(clusterRefreshInterval, 5) * 1_000_000_000) }
    private var namespaceRefreshIntervalNanoseconds: UInt64 { UInt64(max(namespaceRefreshInterval, 5) * 1_000_000_000) }
    private let metricsSampleLimit = 60
    private var isRestoringPreferences = true
    private var pendingPreferredContext: String?
    private var pendingPreferredNamespace: String?
    private var pendingPreferredConnectedContext: String?
    private var pendingPreferredTab: ClusterDetailView.Tab?

    private enum PreferenceKeys {
        static let selectedContext = "kubex.selected_context"
        static let selectedNamespace = "kubex.selected_namespace"
        static let connectedContext = "kubex.connected_context"
        static let selectedTab = "kubex.selected_tab"
        static let kubeconfigSources = "kubex.kubeconfig_sources"
        static let kubeconfigPath = "kubex.kubeconfig_path"
        static let workloadSort = "kubex.sort.workloads"
        static let nodeSort = "kubex.sort.nodes"
        static let workloadFilter = "kubex.filter.workloads"
        static let podFilter = "kubex.filter.pods"
        static let nodeFilter = "kubex.filter.nodes"
        static let configFilter = "kubex.filter.config"
    }

    private static func normalizePath(_ path: String?) -> String? {
        guard let trimmed = path?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        let expanded = (trimmed as NSString).expandingTildeInPath
        return expanded.isEmpty ? nil : expanded
    }

    private static func normalizePaths(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []
        for path in paths {
            guard let resolved = normalizePath(path) else { continue }
            guard FileManager.default.fileExists(atPath: resolved) else { continue }
            if seen.insert(resolved).inserted {
                normalized.append(resolved)
            }
        }
        return normalized
    }

    private static func joinedKubeconfigPath(for paths: [String]) -> String? {
        guard !paths.isEmpty else {
            return KubectlDefaults.defaultKubeconfigPath()
        }
        return paths.joined(separator: ":")
    }

    init(
        clusterService: ClusterService = KubectlClusterService(),
        logService: LogStreamingService = KubectlLogStreamingService(),
        execService: ExecService = KubectlExecService(),
        portForwardService: PortForwardService = KubectlPortForwardService(),
        editService: EditService = KubectlEditService(),
        helmService: HelmService = HelmCLIService(),
        telemetryService: TelemetryService = TelemetryLogService()
    ) {
        let defaults = UserDefaults.standard

        self.clusterService = clusterService
        self.logService = logService
        self.execService = execService
        self.portForwardService = portForwardService
        self.editService = editService
        self.helmService = helmService
        self.telemetryService = telemetryService

        let storedSources: [String]
        if let data = defaults.data(forKey: PreferenceKeys.kubeconfigSources),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            storedSources = decoded
        } else if let legacyPath = defaults.string(forKey: PreferenceKeys.kubeconfigPath) {
            storedSources = [legacyPath]
        } else if let defaultPath = KubectlDefaults.defaultKubeconfigPath() {
            storedSources = [defaultPath]
        } else {
            storedSources = []
        }

        let normalizedSources = AppModel.normalizePaths(storedSources)
        self.kubeconfigSources = normalizedSources

        rebuildServices(with: normalizedSources)

        self.pendingPreferredContext = defaults.string(forKey: PreferenceKeys.selectedContext)
        self.pendingPreferredNamespace = defaults.string(forKey: PreferenceKeys.selectedNamespace)
        self.pendingPreferredConnectedContext = defaults.string(forKey: PreferenceKeys.connectedContext)
        if let tabKey = defaults.string(forKey: PreferenceKeys.selectedTab),
           let tab = ClusterDetailView.Tab(preferenceValue: tabKey) {
            self.selectedResourceTab = tab
            self.pendingPreferredTab = tab
        }

        loadSortPreferences(from: defaults)
        loadFilterPreferences(from: defaults)
    }

    func setInspectorSelection(_ selection: InspectorSelection) {
        if inspectorSelection != selection {
            inspectorSelection = selection
        }
    }

    func clearInspectorSelection() {
        setInspectorSelection(.none)
    }

    func metrics(for clusterID: Cluster.ID) -> ClusterOverviewMetrics? {
        clusterOverviewMetrics[clusterID]
    }

    func workloadRolloutSeries(for clusterID: Cluster.ID, namespace: String, workloadName: String, kind: WorkloadKind) -> WorkloadRolloutSeries? {
        workloadRolloutHistory[clusterID]?[WorkloadHistoryKey(namespace: namespace, name: workloadName, kind: kind)]
    }

    func refreshClusters() async {
        defer {
            isRestoringPreferences = false
            persistSelection()
        }
        do {
            let previousSelectedContext = selectedCluster?.contextName
            let previousNamespace: String?
            if selectedNamespaceID == AppModel.allNamespacesNamespaceID {
                previousNamespace = AppModel.allNamespacesPreferenceValue
            } else {
                previousNamespace = selectedNamespace?.name
            }
            let previousConnectedContext = connectedCluster?.contextName

            if let currentID = connectedClusterID {
                await disconnectCluster(clusterID: currentID)
            }

            let clusters = try await clusterService.loadClusters()
            self.clusters = clusters
            if isQuickSearchPresented {
                refreshQuickSearchResults()
            }
            let newClusterIDs = Set(clusters.map { $0.id })
            let obsoleteMetricKeys = clusterOverviewMetrics.keys.filter { !newClusterIDs.contains($0) }
            for key in obsoleteMetricKeys {
                clearClusterMetrics(for: key)
            }

            if let desiredContext = [pendingPreferredContext, previousSelectedContext, clusters.first?.contextName].compactMap({ $0 }).first,
               let restored = clusters.first(where: { $0.contextName == desiredContext }) {
                selectedClusterID = restored.id
                pendingPreferredContext = nil
            } else {
                selectedClusterID = clusters.first?.id
            }

            connectedClusterID = nil
            selectedNamespaceID = nil
            activePortForwards.removeAll()

            if let pendingTab = pendingPreferredTab {
                selectedResourceTab = pendingTab
                pendingPreferredTab = nil
            } else {
                selectedResourceTab = .overview
            }

            let namespacePreference = previousNamespace ?? pendingPreferredNamespace
            let desiredConnectedContext = previousConnectedContext
                ?? pendingPreferredConnectedContext
                ?? pendingPreferredContext

            if let contextName = desiredConnectedContext,
               let target = clusters.first(where: { $0.contextName == contextName }) {
                await connectCluster(clusterID: target.id, contextName: contextName, preferredNamespace: namespacePreference)
                pendingPreferredConnectedContext = nil
            } else {
                error = nil
            }
        } catch {
            self.error = AppModelError(message: error.localizedDescription)
        }
    }

    var selectedCluster: Cluster? {
        clusters.first { $0.id == selectedClusterID }
    }

    var connectedCluster: Cluster? {
        guard let id = connectedClusterID else { return nil }
        return clusters.first { $0.id == id }
    }

    var selectedNamespace: Namespace? {
        guard let cluster = selectedCluster, cluster.isConnected else { return nil }
        if selectedNamespaceID == AppModel.allNamespacesNamespaceID {
            return makeAllNamespacesNamespace(from: cluster)
        }
        if let id = selectedNamespaceID,
           let namespace = cluster.namespaces.first(where: { $0.id == id }) {
            if namespace.isLoaded {
                return namespace
            } else if let loaded = cluster.namespaces.first(where: { $0.id == id && $0.isLoaded }) {
                return loaded
            } else {
                return namespace
            }
        }
        return cluster.namespaces.first
    }

    var unhealthySummary: [String] {
        guard let cluster = connectedCluster else { return [] }
        return cluster.namespaces.flatMap { namespace in
            namespace.workloads
                .filter { $0.status != .healthy }
                .map { "\(namespace.name): \($0.name)" }
        }
    }

    var currentNamespaces: [Namespace]? {
        guard let cluster = selectedCluster, cluster.isConnected else { return nil }
        var namespaces = cluster.namespaces
        if !namespaces.isEmpty {
            let aggregated = makeAllNamespacesNamespace(from: cluster)
            namespaces.insert(aggregated, at: 0)
        }
        return namespaces
    }

    private func makeAllNamespacesNamespace(from cluster: Cluster) -> Namespace {
        let allLoaded = cluster.namespaces.contains { $0.isLoaded }
        var aggregated = Namespace(
            id: AppModel.allNamespacesNamespaceID,
            name: AppModel.allNamespacesDisplayName,
            workloads: [],
            pods: [],
            events: [],
            alerts: [],
            configResources: [],
            services: [],
            ingresses: [],
            persistentVolumeClaims: [],
            serviceAccounts: [],
            roles: [],
            roleBindings: [],
            isLoaded: allLoaded
        )

        for namespace in cluster.namespaces {
            aggregated.workloads.append(contentsOf: namespace.workloads)
            aggregated.pods.append(contentsOf: namespace.pods)
            aggregated.events.append(contentsOf: namespace.events)
            aggregated.alerts.append(contentsOf: namespace.alerts)
            aggregated.configResources.append(contentsOf: namespace.configResources)
            aggregated.services.append(contentsOf: namespace.services)
            aggregated.ingresses.append(contentsOf: namespace.ingresses)
            aggregated.persistentVolumeClaims.append(contentsOf: namespace.persistentVolumeClaims)
            aggregated.serviceAccounts.append(contentsOf: namespace.serviceAccounts)
            aggregated.roles.append(contentsOf: namespace.roles)
            aggregated.roleBindings.append(contentsOf: namespace.roleBindings)
        }

        return aggregated
    }

    // MARK: - Quick Search

    func presentQuickSearch() {
        guard let cluster = selectedCluster, cluster.isConnected else { return }
        quickSearchQuery = ""
        if let namespaceID = selectedNamespaceID {
            quickSearchNamespaceFilter = namespaceID
        } else {
            quickSearchNamespaceFilter = AppModel.allNamespacesNamespaceID
        }
        isQuickSearchPresented = true
        refreshQuickSearchResults()
    }

    func dismissQuickSearch() {
        isQuickSearchPresented = false
        quickSearchQuery = ""
        quickSearchResults = []
        quickSearchFocus = nil
    }

    func handleQuickSearchSelection(_ result: QuickSearchResult) {
        guard let cluster = clusters.first(where: { $0.id == result.clusterID }) else { return }

        if selectedClusterID != cluster.id {
            selectedClusterID = cluster.id
        }

        isQuickSearchPresented = false
        quickSearchResults = []
        quickSearchQuery = ""

        switch result.target {
        case let .tab(tab):
            selectedResourceTab = tab
            clearInspectorSelection()

        case let .namespace(namespaceID):
            selectedNamespaceID = namespaceID
            selectedResourceTab = .namespaces
            clearInspectorSelection()

        case let .workload(kind, namespaceID, workloadID):
            selectedNamespaceID = namespaceID
            selectedResourceTab = workloadTab(for: kind)
            setInspectorSelection(
                .workload(
                    clusterID: cluster.id,
                    namespaceID: namespaceID,
                    workloadID: workloadID
                )
            )

        case let .pod(namespaceID, podID):
            selectedNamespaceID = namespaceID
            selectedResourceTab = .workloadsPods
            setInspectorSelection(
                .pod(
                    clusterID: cluster.id,
                    namespaceID: namespaceID,
                    podID: podID
                )
            )

        case .node:
            selectedResourceTab = .nodes
            clearInspectorSelection()
            quickSearchFocus = QuickSearchSelection(clusterID: cluster.id, target: result.target)
            return

        case let .helm(releaseID):
            selectedResourceTab = .helm
            setInspectorSelection(.helm(clusterID: cluster.id, releaseID: releaseID))

        case let .service(namespaceID, serviceID):
            selectedNamespaceID = namespaceID
            selectedResourceTab = .networkServices
            setInspectorSelection(
                .service(
                    clusterID: cluster.id,
                    namespaceID: namespaceID,
                    serviceID: serviceID
                )
            )

        case let .ingress(namespaceID, ingressID):
            selectedNamespaceID = namespaceID
            selectedResourceTab = .networkIngresses
            setInspectorSelection(
                .ingress(
                    clusterID: cluster.id,
                    namespaceID: namespaceID,
                    ingressID: ingressID
                )
            )

        case let .persistentVolumeClaim(namespaceID, claimID):
            selectedNamespaceID = namespaceID
            selectedResourceTab = .storagePersistentVolumeClaims
            setInspectorSelection(
                .persistentVolumeClaim(
                    clusterID: cluster.id,
                    namespaceID: namespaceID,
                    claimID: claimID
                )
            )

        case let .configResource(kind, namespaceID, _):
            selectedNamespaceID = namespaceID
            selectedResourceTab = {
                switch kind {
                case .configMap: return .configConfigMaps
                case .secret: return .configSecrets
                case .resourceQuota: return .configResourceQuotas
                case .limitRange: return .configLimitRanges
                }
            }()
            clearInspectorSelection()
        }

        quickSearchFocus = QuickSearchSelection(clusterID: cluster.id, target: result.target)
    }

    func consumeQuickSearchFocus() {
        quickSearchFocus = nil
    }

    private func refreshQuickSearchResults() {
        guard isQuickSearchPresented else {
            quickSearchResults = []
            return
        }

        guard let cluster = selectedCluster, cluster.isConnected else {
            quickSearchResults = []
            return
        }

        let trimmed = quickSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            quickSearchResults = []
            return
        }

        let tokens = trimmed.lowercased().split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !tokens.isEmpty else {
            quickSearchResults = []
            return
        }

        let maxCandidates = 200
        var matches: [(score: Int, result: QuickSearchResult)] = []
        let filterID = quickSearchNamespaceFilter
        let clusterName = cluster.name
        let namespaceLookup = Dictionary(uniqueKeysWithValues: cluster.namespaces.map { ($0.name, $0.id) })

        func filterAllows(namespaceName: String) -> Bool {
            guard let filterID else { return true }
            if filterID == AppModel.allNamespacesNamespaceID { return true }
            guard let actualID = namespaceLookup[namespaceName] else { return false }
            return actualID == filterID
        }

        func addResult(
            title: String,
            subtitle: String?,
            detail: String?,
            category: String,
            icon: String,
            target: QuickSearchTarget,
            secondary: [String] = []
        ) {
            var fields = secondary
            if let subtitle { fields.append(subtitle) }
            if let detail { fields.append(detail) }
            fields.append(category)
            fields.append(clusterName)
            guard let score = matchScore(for: tokens, primary: title, secondary: fields) else { return }
            let result = QuickSearchResult(
                clusterID: cluster.id,
                title: title,
                subtitle: subtitle,
                detail: detail,
                category: category,
                iconSystemName: icon,
                target: target
            )
            matches.append((score, result))
        }

        if filterID == nil || filterID == AppModel.allNamespacesNamespaceID {
            addResult(
                title: AppModel.allNamespacesDisplayName,
                subtitle: clusterName,
                detail: nil,
                category: "Namespace",
                icon: ClusterDetailView.Tab.namespaces.icon,
                target: .namespace(AppModel.allNamespacesNamespaceID)
            )
        }

        for namespace in cluster.namespaces {
            if matches.count >= maxCandidates { break }
            if !matchesNamespaceFilter(namespaceID: namespace.id, filterID: filterID) {
                continue
            }

            var namespaceDetails: [String] = []
            if !namespace.workloads.isEmpty {
                namespaceDetails.append("\(namespace.workloads.count) workloads")
            }
            if !namespace.pods.isEmpty {
                namespaceDetails.append("\(namespace.pods.count) pods")
            }

            addResult(
                title: namespace.name,
                subtitle: clusterName,
                detail: namespaceDetails.isEmpty ? nil : namespaceDetails.joined(separator: " · "),
                category: "Namespace",
                icon: ClusterDetailView.Tab.namespaces.icon,
                target: .namespace(namespace.id),
                secondary: [namespace.name]
            )

            for workload in namespace.workloads {
                if matches.count >= maxCandidates { break }
                let detailParts: [String] = [
                    "Ready \(workload.readyDisplay)",
                    workload.status.displayName
                ]
                addResult(
                    title: workload.name,
                    subtitle: "\(namespace.name) • \(workload.kind.displayName)",
                    detail: detailParts.joined(separator: " · "),
                    category: workload.kind.displayName,
                    icon: workload.kind.systemImage,
                    target: .workload(kind: workload.kind, namespaceID: namespace.id, workloadID: workload.id),
                    secondary: [namespace.name, workload.status.displayName]
                )
            }

            for pod in namespace.pods {
                if matches.count >= maxCandidates { break }
                var podDetails: [String] = [pod.phase.displayName]
                if pod.restarts > 0 {
                    podDetails.append("\(pod.restarts) restarts")
                }
                if let nodeName = pod.nodeName.split(separator: ".").first {
                    podDetails.append(String(nodeName))
                }
                addResult(
                    title: pod.name,
                    subtitle: "\(namespace.name) • Pod",
                    detail: podDetails.joined(separator: " · "),
                    category: "Pod",
                    icon: ClusterDetailView.Tab.workloadsPods.icon,
                    target: .pod(namespaceID: namespace.id, podID: pod.id),
                    secondary: [namespace.name, pod.phase.displayName]
                )
            }

            for service in namespace.services {
                if matches.count >= maxCandidates { break }
                var serviceDetails: [String] = []
                if !service.type.isEmpty {
                    serviceDetails.append(service.type)
                }
                if !service.clusterIP.isEmpty {
                    serviceDetails.append("ClusterIP \(service.clusterIP)")
                }
                if !service.ports.isEmpty {
                    serviceDetails.append("Ports \(service.ports)")
                }
                if service.totalEndpointCount > 0 {
                    serviceDetails.append("Endpoints \(service.endpointHealthDisplay)")
                }
                addResult(
                    title: service.name,
                    subtitle: "\(namespace.name) • Service",
                    detail: serviceDetails.joined(separator: " · "),
                    category: "Service",
                    icon: ClusterDetailView.NetworkResourceKind.services.systemImage,
                    target: .service(namespaceID: namespace.id, serviceID: service.id),
                    secondary: [namespace.name, service.type]
                )
            }

            for ingress in namespace.ingresses {
                if matches.count >= maxCandidates { break }
                let ingressDetails = ingress.serviceTargets.isEmpty ? ingress.hostRules : ingress.serviceTargets
                addResult(
                    title: ingress.name,
                    subtitle: "\(namespace.name) • Ingress",
                    detail: ingressDetails,
                    category: "Ingress",
                    icon: ClusterDetailView.NetworkResourceKind.ingresses.systemImage,
                    target: .ingress(namespaceID: namespace.id, ingressID: ingress.id),
                    secondary: [namespace.name, ingress.hostRules]
                )
            }

            for claim in namespace.persistentVolumeClaims {
                if matches.count >= maxCandidates { break }
                var claimDetails: [String] = [claim.status]
                if let capacity = claim.capacity {
                    claimDetails.append(capacity)
                }
                if let storageClass = claim.storageClass {
                    claimDetails.append(storageClass)
                }
                addResult(
                    title: claim.name,
                    subtitle: "\(namespace.name) • PVC",
                    detail: claimDetails.joined(separator: " · "),
                    category: "PersistentVolumeClaim",
                    icon: ClusterDetailView.Tab.storagePersistentVolumeClaims.icon,
                    target: .persistentVolumeClaim(namespaceID: namespace.id, claimID: claim.id),
                    secondary: [namespace.name, claim.status]
                )
            }

            for config in namespace.configResources {
                if matches.count >= maxCandidates { break }
                let detail = config.summary ?? config.typeDescription
                addResult(
                    title: config.name,
                    subtitle: "\(namespace.name) • \(config.kind.displayName)",
                    detail: detail,
                    category: config.kind.displayName,
                    icon: config.kind.systemImage,
                    target: .configResource(kind: config.kind, namespaceID: namespace.id, resourceID: config.id),
                    secondary: [namespace.name, config.kind.displayName]
                )
            }
        }

        if filterID == nil || filterID == AppModel.allNamespacesNamespaceID {
            for node in cluster.nodes {
                if matches.count >= maxCandidates { break }
                var nodeDetails: [String] = []
                if let cpu = node.cpuUsage {
                    nodeDetails.append("CPU \(cpu)")
                }
                if let memory = node.memoryUsage {
                    nodeDetails.append("Memory \(memory)")
                }
                if node.warningCount > 0 {
                    nodeDetails.append("\(node.warningCount) warnings")
                }
                addResult(
                    title: node.name,
                    subtitle: "Node",
                    detail: nodeDetails.joined(separator: " · "),
                    category: "Node",
                    icon: ClusterDetailView.Tab.nodes.icon,
                    target: .node(nodeID: node.id),
                    secondary: nodeDetails
                )
            }
        }

        for release in cluster.helmReleases {
            if matches.count >= maxCandidates { break }
            if !filterAllows(namespaceName: release.namespace) {
                continue
            }
            var releaseDetails: [String] = [release.status]
            if !release.chart.isEmpty {
                releaseDetails.append(release.chart)
            }
            if let appVersion = release.appVersion {
                releaseDetails.append("App \(appVersion)")
            }
            addResult(
                title: release.name,
                subtitle: "\(release.namespace) • Helm",
                detail: releaseDetails.joined(separator: " · "),
                category: "Helm",
                icon: ClusterDetailView.Tab.helm.icon,
                target: .helm(releaseID: release.id),
                secondary: [release.namespace, release.status]
            )
        }

        matches.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score < rhs.score }
            let left = lhs.result
            let right = rhs.result
            let titleCompare = left.title.localizedCaseInsensitiveCompare(right.title)
            if titleCompare != .orderedSame {
                return titleCompare == .orderedAscending
            }
            let leftSubtitle = left.subtitle ?? ""
            let rightSubtitle = right.subtitle ?? ""
            let subtitleCompare = leftSubtitle.localizedCaseInsensitiveCompare(rightSubtitle)
            if subtitleCompare != .orderedSame {
                return subtitleCompare == .orderedAscending
            }
            if left.category != right.category {
                return left.category.localizedCompare(right.category) == .orderedAscending
            }
            if left.clusterID != right.clusterID {
                return left.clusterID.uuidString < right.clusterID.uuidString
            }
            return left.id.uuidString < right.id.uuidString
        }

        quickSearchResults = matches.prefix(60).map { $0.result }
    }

    private func matchesNamespaceFilter(namespaceID: Namespace.ID, filterID: Namespace.ID?) -> Bool {
        guard let filterID else { return true }
        if filterID == AppModel.allNamespacesNamespaceID {
            return true
        }
        return namespaceID == filterID
    }

    private func workloadTab(for kind: WorkloadKind) -> ClusterDetailView.Tab {
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

    private func matchScore(for tokens: [String], primary: String, secondary: [String]) -> Int? {
        let primaryLower = primary.lowercased()
        let secondaryLower = secondary.map { $0.lowercased() }
        var total = 0

        for token in tokens {
            let tokenLower = token
            var best = Int.max

            if primaryLower.hasPrefix(tokenLower) {
                best = min(best, 0)
            }
            if primaryLower.contains(tokenLower) {
                best = min(best, 1)
            }

            for field in secondaryLower {
                if field.hasPrefix(tokenLower) {
                    best = min(best, 2)
                }
                if field.contains(tokenLower) {
                    best = min(best, 3)
                }
            }

            if best == Int.max {
                return nil
            }
            total += best
        }

        return total
    }

    func namespace(clusterID: Cluster.ID, named name: String) -> Namespace? {
        clusters.first(where: { $0.id == clusterID })?.namespaces.first(where: { $0.name == name })
    }

    func ensureAllNamespacesLoaded(clusterID: Cluster.ID, contextName: String) async {
        guard let clusterIndex = clusters.firstIndex(where: { $0.id == clusterID }) else { return }
        let namespaceNames = clusters[clusterIndex].namespaces.map { $0.name }
        for name in namespaceNames {
            await loadNamespaceIfNeeded(clusterID: clusterID, namespaceName: name)
        }
    }

    func connectSelectedCluster() async {
        guard let cluster = selectedCluster else { return }
        KubectlDefaults.debug("Connect requested for \(cluster.contextName)")
        await connectCluster(clusterID: cluster.id, contextName: cluster.contextName, preferredNamespace: nil)
    }

    func disconnectCurrentCluster() async {
        guard let currentID = connectedClusterID else { return }
        await disconnectCluster(clusterID: currentID)
    }

    func applyKubeconfig(at inputPath: String?) async -> Result<Void, AppModelError> {
        guard let resolvedPath = AppModel.normalizePath(inputPath) ?? KubectlDefaults.defaultKubeconfigPath() else {
            return .failure(AppModelError(message: "Provide a kubeconfig path or ensure ~/.kube/config exists."))
        }

        if !FileManager.default.fileExists(atPath: resolvedPath) {
            return .failure(AppModelError(message: "Kubeconfig not found at \(resolvedPath)"))
        }

        do {
            try await validateKubeconfig(path: resolvedPath)
        } catch {
            let message = sanitizeErrorMessage(error.localizedDescription)
            return .failure(AppModelError(message: message))
        }

        var updated = kubeconfigSources
        if !updated.contains(resolvedPath) {
            updated.append(resolvedPath)
        }
        updated = AppModel.normalizePaths(updated)
        kubeconfigSources = updated
        persistKubeconfigSources(updated)

        clearSelectionPreferences()
        isRestoringPreferences = true
        pendingPreferredContext = nil
        pendingPreferredNamespace = nil
        pendingPreferredConnectedContext = nil
        pendingPreferredTab = nil

        rebuildServices(with: updated)

        await refreshClusters()
        return .success(())
    }

    func makeLogStream(for request: LogStreamRequest) -> AsyncThrowingStream<LogStreamEvent, Error> {
        logService.streamLogs(for: request)
    }

    func removeKubeconfigSource(at index: Int) async {
        guard kubeconfigSources.indices.contains(index) else { return }
        var updated = kubeconfigSources
        updated.remove(at: index)
        if updated.isEmpty, let defaultPath = KubectlDefaults.defaultKubeconfigPath(), FileManager.default.fileExists(atPath: defaultPath) {
            updated = [defaultPath]
        }
        updated = AppModel.normalizePaths(updated)
        kubeconfigSources = updated
        persistKubeconfigSources(updated)

        clearSelectionPreferences()
        isRestoringPreferences = true
        pendingPreferredContext = nil
        pendingPreferredNamespace = nil
        pendingPreferredConnectedContext = nil
        pendingPreferredTab = nil

        rebuildServices(with: updated)
        await refreshClusters()
    }

    func fetchPodYAML(cluster: Cluster, namespace: Namespace, pod: PodSummary) async -> Result<String, AppModelError> {
        await fetchResourceYAML(
            contextName: cluster.contextName,
            namespace: namespace.name,
            resourceType: "pod",
            name: pod.name
        )
    }

    func fetchWorkloadYAML(cluster: Cluster, namespace: Namespace, workload: WorkloadSummary) async -> Result<String, AppModelError> {
        guard let resource = workload.kind.kubectlResourceName else {
            return .failure(AppModelError(message: "YAML unavailable for \(workload.kind.displayName)."))
        }
        return await fetchResourceYAML(
            contextName: cluster.contextName,
            namespace: namespace.name,
            resourceType: resource,
            name: workload.name
        )
    }

    func applyPodYAML(cluster: Cluster, namespace: Namespace, pod: PodSummary, yaml: String) async -> Result<String, AppModelError> {
        await applyNamespaceManifest(
            cluster: cluster,
            namespaceName: namespace.name,
            yaml: yaml,
            successMessage: "Pod \(pod.name) updated"
        )
    }

    func applyWorkloadYAML(cluster: Cluster, namespace: Namespace, workload: WorkloadSummary, yaml: String) async -> Result<String, AppModelError> {
        await applyNamespaceManifest(
            cluster: cluster,
            namespaceName: namespace.name,
            yaml: yaml,
            successMessage: "Applied changes to \(workload.name)"
        )
    }

    func executePodCommand(
        cluster: Cluster,
        namespace: Namespace,
        pod: PodSummary,
        container: String?,
        command: String
    ) async -> Result<ExecCommandOutput, AppModelError> {
        guard cluster.isConnected else {
            return .failure(AppModelError(message: "Connect to the cluster before running exec commands."))
        }

        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(AppModelError(message: "Enter a command to execute."))
        }

        var arguments = ["exec", "-i", pod.name, "-n", namespace.name]
        if let container, !container.isEmpty {
            arguments.append(contentsOf: ["-c", container])
        }
        arguments.append(contentsOf: ["--context", cluster.contextName, "--", "/bin/sh", "-lc", trimmed])

        let runner = KubectlRunner()
        do {
            let output = try await runner.run(
                arguments: arguments,
                kubeconfigPath: kubeconfigEnvValue ?? KubectlDefaults.defaultKubeconfigPath()
            )
            let normalized = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(ExecCommandOutput(output: normalized.isEmpty ? "(no output)" : normalized, exitCode: 0, isError: false))
        } catch let kubectlError as KubectlError {
            let payload = (kubectlError.output ?? kubectlError.message).trimmingCharacters(in: .whitespacesAndNewlines)
            let message = payload.isEmpty ? kubectlError.message : payload
            return .success(ExecCommandOutput(output: message, exitCode: kubectlError.exitCode, isError: true))
        } catch {
            let message = sanitizeErrorMessage(error.localizedDescription)
            return .failure(AppModelError(message: message))
        }
    }

    func startPortForward(request: PortForwardRequest) async {
        guard connectedClusterID == request.clusterID else {
            self.error = AppModelError(message: "Connect to the cluster before starting a port forward.")
            return
        }
        do {
            let forward = try await portForwardService.startForward(request) { [weak self] event in
                Task { @MainActor in
                    guard let self else { return }
                    self.handlePortForwardEvent(event)
                }
            }
            activePortForwards.append(forward)
            error = nil
            emitPortForwardEvent(name: "port_forward_started", request: forward.request, status: forward.status, message: nil)
        } catch {
            self.error = AppModelError(message: error.localizedDescription)
            emitPortForwardFailure(request: request, message: error.localizedDescription)
        }
    }

    func stopPortForward(id: ActivePortForward.ID) async {
        guard let index = activePortForwards.firstIndex(where: { $0.id == id }) else { return }
        let forward = activePortForwards[index]
        do {
            try await portForwardService.stopForward(forward)
            activePortForwards.remove(at: index)
            error = nil
            emitPortForwardEvent(name: "port_forward_stopped", request: forward.request, status: forward.status, message: nil)
        } catch {
            self.error = AppModelError(message: error.localizedDescription)
        }
    }

    private func handlePortForwardEvent(_ event: PortForwardLifecycleEvent) {
        switch event {
        case .terminated(let id, let request, let kubectlError):
            guard let index = activePortForwards.firstIndex(where: { $0.id == id }) else {
                if let kubectlError {
                    let message = sanitizeErrorMessage(kubectlError.message)
                    emitPortForwardFailure(request: request, message: message)
                    self.error = AppModelError(message: message)
                }
                return
            }

            let forward = activePortForwards[index]
            if let kubectlError {
                let message = sanitizeErrorMessage(kubectlError.message)
                activePortForwards[index].status = .failed(message)
                emitPortForwardEvent(name: "port_forward_failed", request: forward.request, status: .failed(message), message: message)
                self.error = AppModelError(message: message)
            } else {
                activePortForwards.remove(at: index)
                emitPortForwardEvent(name: "port_forward_terminated", request: forward.request, status: forward.status, message: nil)
            }
        }
    }

    @discardableResult
    func openShell(for cluster: Cluster, namespace: Namespace, pod: PodSummary, defaultCommand: [String] = ["/bin/sh"]) async -> ExecSession? {
        guard cluster.isConnected, connectedClusterID == cluster.id else {
            self.error = AppModelError(message: "Connect to the cluster before opening a shell.")
            return nil
        }
        let session = ExecSession(
            id: UUID(),
            clusterID: cluster.id,
            contextName: cluster.contextName,
            namespace: namespace.name,
            podName: pod.name,
            containerName: pod.primaryContainer,
            command: defaultCommand,
            startedAt: Date()
        )
        do {
            let established = try await execService.openShell(for: session)
            return established
        } catch {
            self.error = AppModelError(message: error.localizedDescription)
            return nil
        }
    }

    func editPod(cluster: Cluster, namespace: Namespace, pod: PodSummary) async {
        guard cluster.isConnected else {
            self.error = AppModelError(message: "Connect to the cluster before editing resources.")
            return
        }

        let request = ResourceEditRequest(
            contextName: cluster.contextName,
            namespace: namespace.name,
            kind: "pod",
            name: pod.name
        )

        do {
            try await editService.editResource(request)
            error = nil
        } catch {
            let message = sanitizeErrorMessage(error.localizedDescription)
            self.error = AppModelError(message: message)
        }
    }

    func fetchPodDetail(cluster: Cluster, namespace: Namespace, pod: PodSummary) async -> Result<PodDetailData, AppModelError> {
        do {
            let detail = try await clusterService.loadPodDetail(contextName: cluster.contextName, namespace: namespace.name, pod: pod.name)
            return .success(detail)
        } catch {
            let message = sanitizeErrorMessage(error.localizedDescription)
            return .failure(AppModelError(message: message))
        }
    }

    func attachPod(cluster: Cluster, namespace: Namespace, pod: PodSummary) async {
        guard cluster.isConnected else {
            self.error = AppModelError(message: "Connect to the cluster before attaching.")
            return
        }
        var components = ["kubectl", "attach", "-it", pod.name, "-n", namespace.name, "--context", cluster.contextName]
        if let container = pod.primaryContainer {
            components.append(contentsOf: ["-c", container])
        }
        launchKubectlInTerminal(arguments: components)
    }

    func deletePod(cluster: Cluster, namespace: Namespace, pod: PodSummary, force: Bool) async {
        guard cluster.isConnected else {
            self.error = AppModelError(message: "Connect to the cluster before deleting.")
            return
        }
        var arguments = ["delete", "pod", pod.name, "-n", namespace.name, "--context", cluster.contextName]
        if force {
            arguments.append(contentsOf: ["--grace-period", "0", "--force"])
        }
        do {
            try await runKubectl(arguments: arguments)
            error = nil
        } catch {
            let message = sanitizeErrorMessage(error.localizedDescription)
            self.error = AppModelError(message: message)
        }
    }

    func editServiceResource(cluster: Cluster, namespace: Namespace, service: ServiceSummary) async {
        guard cluster.isConnected else {
            self.error = AppModelError(message: "Connect to the cluster before editing services.")
            return
        }

        let request = ResourceEditRequest(
            contextName: cluster.contextName,
            namespace: namespace.name,
            kind: "service",
            name: service.name
        )

        do {
            try await editService.editResource(request)
            error = nil
        } catch {
            let message = sanitizeErrorMessage(error.localizedDescription)
            self.error = AppModelError(message: message)
        }
    }

    func deleteServiceResource(cluster: Cluster, namespace: Namespace, service: ServiceSummary) async {
        guard cluster.isConnected else {
            self.error = AppModelError(message: "Connect to the cluster before deleting services.")
            return
        }

        do {
            try await runKubectl(arguments: [
                "delete",
                "service",
                service.name,
                "-n",
                namespace.name,
                "--context",
                cluster.contextName
            ])
            error = nil
            await refreshNamespace(clusterID: cluster.id, contextName: cluster.contextName, namespaceName: namespace.name)
        } catch {
            let message = sanitizeErrorMessage(error.localizedDescription)
            self.error = AppModelError(message: message)
        }
    }

    func editPersistentVolumeClaim(cluster: Cluster, namespace: Namespace, claim: PersistentVolumeClaimSummary) async {
        guard cluster.isConnected else {
            self.error = AppModelError(message: "Connect to the cluster before editing persistent volume claims.")
            return
        }

        let request = ResourceEditRequest(
            contextName: cluster.contextName,
            namespace: namespace.name,
            kind: "persistentvolumeclaim",
            name: claim.name
        )

        do {
            try await editService.editResource(request)
            error = nil
        } catch {
            let message = sanitizeErrorMessage(error.localizedDescription)
            self.error = AppModelError(message: message)
        }
    }

    func deletePersistentVolumeClaim(cluster: Cluster, namespace: Namespace, claim: PersistentVolumeClaimSummary) async {
        guard cluster.isConnected else {
            self.error = AppModelError(message: "Connect to the cluster before deleting persistent volume claims.")
            return
        }

        do {
            try await runKubectl(arguments: [
                "delete",
                "pvc",
                claim.name,
                "-n",
                namespace.name,
                "--context",
                cluster.contextName
            ])
            error = nil
            await refreshNamespace(clusterID: cluster.id, contextName: cluster.contextName, namespaceName: namespace.name)
        } catch {
            let message = sanitizeErrorMessage(error.localizedDescription)
            self.error = AppModelError(message: message)
        }
    }

    func openNodeShell(cluster: Cluster, node: NodeInfo) async {
        guard cluster.isConnected else {
            self.error = AppModelError(message: "Connect to the cluster before launching a node shell.")
            return
        }
        let arguments = [
            "debug",
            "node/\(node.name)",
            "-it",
            "--context",
            cluster.contextName,
            "--image=registry.k8s.io/e2e-test-images/agnhost:2.45",
            "--",
            "/bin/sh"
        ]
        showBanner("Launching debug shell for \(node.name)…", style: .info)
        launchKubectlInTerminal(arguments: arguments)
        showBanner("Debug shell opened for \(node.name)", style: .success)
    }

    func cordonNode(cluster: Cluster, node: NodeInfo) async {
        guard cluster.isConnected else {
            self.error = AppModelError(message: "Connect to the cluster before cordoning nodes.")
            return
        }
        showBanner("Cordoning \(node.name)…", style: .info)
        let key = beginNodeAction(contextName: cluster.contextName, nodeName: node.name)
        defer { endNodeAction(key: key) }
        do {
            try await runKubectl(arguments: ["cordon", node.name, "--context", cluster.contextName])
            error = nil
            invalidateCachedNodeData(for: cluster)
            await updateClusterSnapshot(clusterID: cluster.id, contextName: cluster.contextName)
            showBanner("Node \(node.name) cordoned", style: .success)
            nodeActionFeedback.removeValue(forKey: key)
        } catch {
            let message = sanitizeErrorMessage(error.localizedDescription)
            self.error = AppModelError(message: message)
            nodeActionFeedback[key] = NodeActionFeedback(
                contextName: cluster.contextName,
                nodeName: node.name,
                message: message
            )
        }
    }

    func drainNode(cluster: Cluster, node: NodeInfo) async {
        guard cluster.isConnected else {
            self.error = AppModelError(message: "Connect to the cluster before draining nodes.")
            return
        }
        let arguments = [
            "drain",
            node.name,
            "--context",
            cluster.contextName,
            "--ignore-daemonsets",
            "--delete-emptydir-data",
            "--force",
            "--grace-period",
            "0",
            "--timeout",
            "5m"
        ]
        showBanner("Draining \(node.name)…", style: .info)
        let key = beginNodeAction(contextName: cluster.contextName, nodeName: node.name)
        defer { endNodeAction(key: key) }
        do {
            try await runKubectl(arguments: arguments)
            error = nil
            invalidateCachedNodeData(for: cluster)
            await updateClusterSnapshot(clusterID: cluster.id, contextName: cluster.contextName)
            showBanner("Node \(node.name) drained", style: .success)
            nodeActionFeedback.removeValue(forKey: key)
        } catch {
            let message = sanitizeErrorMessage(error.localizedDescription)
            self.error = AppModelError(message: message)
            nodeActionFeedback[key] = NodeActionFeedback(
                contextName: cluster.contextName,
                nodeName: node.name,
                message: message
            )
        }
    }

    func editNode(cluster: Cluster, node: NodeInfo) async {
        guard cluster.isConnected else {
            self.error = AppModelError(message: "Connect to the cluster before editing nodes.")
            return
        }

        let request = ResourceEditRequest(
            contextName: cluster.contextName,
            namespace: nil,
            kind: "node",
            name: node.name
        )

        showBanner("Editing \(node.name)…", style: .info)
        let key = beginNodeAction(contextName: cluster.contextName, nodeName: node.name)
        defer { endNodeAction(key: key) }
        do {
            try await editService.editResource(request)
            error = nil
            invalidateCachedNodeData(for: cluster)
            await updateClusterSnapshot(clusterID: cluster.id, contextName: cluster.contextName)
            showBanner("Edit applied to \(node.name)", style: .success)
            nodeActionFeedback.removeValue(forKey: key)
        } catch {
            let message = sanitizeErrorMessage(error.localizedDescription)
            self.error = AppModelError(message: message)
            nodeActionFeedback[key] = NodeActionFeedback(
                contextName: cluster.contextName,
                nodeName: node.name,
                message: message
            )
        }
    }

    func deleteNode(cluster: Cluster, node: NodeInfo) async {
        guard cluster.isConnected else {
            self.error = AppModelError(message: "Connect to the cluster before deleting nodes.")
            return
        }

        showBanner("Deleting \(node.name)…", style: .info)
        let key = beginNodeAction(contextName: cluster.contextName, nodeName: node.name)
        defer { endNodeAction(key: key) }
        do {
            try await runKubectl(arguments: ["delete", "node", node.name, "--context", cluster.contextName])
            error = nil
            invalidateCachedNodeData(for: cluster)
            await updateClusterSnapshot(clusterID: cluster.id, contextName: cluster.contextName)
            showBanner("Deleted node \(node.name)", style: .success)
            nodeActionFeedback.removeValue(forKey: key)
        } catch {
            let message = sanitizeErrorMessage(error.localizedDescription)
            self.error = AppModelError(message: message)
            nodeActionFeedback[key] = NodeActionFeedback(
                contextName: cluster.contextName,
                nodeName: node.name,
                message: message
            )
        }
    }

    func updateSecret(
        cluster: Cluster,
        namespace: Namespace,
        secret: ConfigResourceSummary,
        entries: [SecretEntryEditor]
    ) async {
        guard cluster.isConnected else {
            self.error = AppModelError(message: "Connect to the cluster before editing secrets.")
            secretActionFeedback = SecretActionFeedback(
                secretName: secret.name,
                namespace: namespace.name,
                status: .failure,
                message: "Cluster is disconnected.",
                kubectlOutput: nil,
                diff: computeSecretDiff(original: secret.secretEntries, updated: entries)
            )
            return
        }

        let encodedData = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.encodedValueForSave()) })
        let diff = computeSecretDiff(original: secret.secretEntries, updated: entries)
        showBanner("Updating secret \(secret.name)…", style: .info)
        do {
            let output = try await clusterService.updateSecret(
                contextName: cluster.contextName,
                namespace: namespace.name,
                name: secret.name,
                type: secret.typeDescription,
                encodedData: encodedData
            )
            applyOptimisticSecretUpdate(
                clusterID: cluster.id,
                namespaceName: namespace.name,
                secretName: secret.name,
                entries: entries
            )
            secretActionFeedback = SecretActionFeedback(
                secretName: secret.name,
                namespace: namespace.name,
                status: .success,
                message: "Secret \(secret.name) updated",
                kubectlOutput: output.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty(),
                diff: diff
            )
            invalidateCachedNodeData(for: cluster)
            await refreshNamespace(clusterID: cluster.id, contextName: cluster.contextName, namespaceName: namespace.name)
            showBanner("Secret \(secret.name) updated", style: .success)
        } catch {
            let message = sanitizeErrorMessage(error.localizedDescription)
            self.error = AppModelError(message: message)
            secretActionFeedback = SecretActionFeedback(
                secretName: secret.name,
                namespace: namespace.name,
                status: .failure,
                message: message,
                kubectlOutput: nil,
                diff: diff
            )
        }
    }

    func updateConfigMap(
        cluster: Cluster,
        namespace: Namespace,
        configMap: ConfigResourceSummary,
        entries: [ConfigMapEntryEditor]
    ) async {
        guard cluster.isConnected else {
            self.error = AppModelError(message: "Connect to the cluster before editing config maps.")
            configMapActionFeedback = ConfigMapActionFeedback(
                configMapName: configMap.name,
                namespace: namespace.name,
                status: .failure,
                message: "Cluster is disconnected.",
                kubectlOutput: nil,
                diff: computeConfigMapDiff(original: configMap.configMapEntries, updated: entries)
            )
            return
        }

        guard namespace.permissions.canEditConfigMaps else {
            let diff = computeConfigMapDiff(original: configMap.configMapEntries, updated: entries)
            let message = "RBAC forbids editing config maps in namespace \(namespace.name)."
            self.error = AppModelError(message: message)
            configMapActionFeedback = ConfigMapActionFeedback(
                configMapName: configMap.name,
                namespace: namespace.name,
                status: .failure,
                message: message,
                kubectlOutput: nil,
                diff: diff
            )
            return
        }

        let plainData = Dictionary(uniqueKeysWithValues: entries.filter { !$0.isBinary }.map { ($0.key, $0.valueForSave()) })
        let binaryData = Dictionary(uniqueKeysWithValues: entries.filter { $0.isBinary }.map { ($0.key, $0.valueForSave()) })
        let diff = computeConfigMapDiff(original: configMap.configMapEntries, updated: entries)

        showBanner("Updating config map \(configMap.name)…", style: .info)
        do {
            let output = try await clusterService.updateConfigMap(
                contextName: cluster.contextName,
                namespace: namespace.name,
                name: configMap.name,
                data: plainData,
                binaryData: binaryData
            )
            applyOptimisticConfigMapUpdate(
                clusterID: cluster.id,
                namespaceName: namespace.name,
                configMapName: configMap.name,
                entries: entries
            )
            configMapActionFeedback = ConfigMapActionFeedback(
                configMapName: configMap.name,
                namespace: namespace.name,
                status: .success,
                message: "ConfigMap \(configMap.name) updated",
                kubectlOutput: output.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty(),
                diff: diff
            )
            await refreshNamespace(clusterID: cluster.id, contextName: cluster.contextName, namespaceName: namespace.name)
            showBanner("ConfigMap \(configMap.name) updated", style: .success)
        } catch {
            let message = sanitizeErrorMessage(error.localizedDescription)
            self.error = AppModelError(message: message)
            configMapActionFeedback = ConfigMapActionFeedback(
                configMapName: configMap.name,
                namespace: namespace.name,
                status: .failure,
                message: message,
                kubectlOutput: nil,
                diff: diff
            )
        }
    }

    private func applyNamespaceManifest(
        cluster: Cluster,
        namespaceName: String,
        yaml: String,
        successMessage: String
    ) async -> Result<String, AppModelError> {
        guard cluster.isConnected else {
            return .failure(AppModelError(message: "Connect to the cluster before applying manifests."))
        }

        let trimmed = yaml.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(AppModelError(message: "Manifest is empty; add YAML before applying."))
        }

        showBanner("Applying manifest…", style: .info)
        do {
            let output = try await clusterService.applyResourceYAML(
                contextName: cluster.contextName,
                manifestYAML: yaml
            )
            await refreshNamespace(clusterID: cluster.id, contextName: cluster.contextName, namespaceName: namespaceName)
            showBanner(successMessage, style: .success)
            return .success(output)
        } catch {
            let message = sanitizeErrorMessage(error.localizedDescription)
            self.error = AppModelError(message: message)
            showBanner("Failed to apply manifest", style: .warning)
            return .failure(AppModelError(message: message))
        }
    }

    func editWorkload(
        cluster: Cluster,
        namespace: Namespace,
        workload: WorkloadSummary
    ) async {
        guard cluster.isConnected else {
            self.error = AppModelError(message: "Connect to the cluster before editing workloads.")
            return
        }

        guard let resource = workload.kind.kubectlResourceName else {
            self.error = AppModelError(message: "Editing is not supported for \(workload.kind.displayName).")
            return
        }

        let request = ResourceEditRequest(
            contextName: cluster.contextName,
            namespace: namespace.name,
            kind: resource,
            name: workload.name
        )

        do {
            try await editService.editResource(request)
            error = nil
        } catch {
            let message = sanitizeErrorMessage(error.localizedDescription)
            self.error = AppModelError(message: message)
        }
    }

    func scaleWorkload(
        cluster: Cluster,
        namespace: Namespace,
        workload: WorkloadSummary,
        replicas: Int
    ) async {
        guard cluster.isConnected else {
            self.error = AppModelError(message: "Connect to the cluster before scaling workloads.")
            return
        }

        guard workload.kind.supportsScaling, let resource = workload.kind.kubectlResourceName else {
            self.error = AppModelError(message: "Scaling is not supported for \(workload.kind.displayName).")
            return
        }

        let desiredReplicas = max(replicas, 0)
        showBanner("Scaling \(workload.name)…", style: .info)
        do {
            try await runKubectl(arguments: [
                "scale",
                "\(resource)/\(workload.name)",
                "--replicas",
                "\(desiredReplicas)",
                "-n",
                namespace.name,
                "--context",
                cluster.contextName
            ])
            await refreshNamespace(clusterID: cluster.id, contextName: cluster.contextName, namespaceName: namespace.name)
            showBanner("Scaled \(workload.name) to \(desiredReplicas) replicas", style: .success)
        } catch {
            let message = sanitizeErrorMessage(error.localizedDescription)
            self.error = AppModelError(message: message)
        }
    }

    private func launchKubectlInTerminal(arguments: [String], extraEnv: [String: String] = [:]) {
        do {
            try KubectlDefaults.launchInTerminal(
                kubeconfigPath: kubeconfigEnvValue ?? KubectlDefaults.defaultKubeconfigPath(),
                arguments: arguments,
                extraEnv: extraEnv
            )
            error = nil
        } catch {
            let message = sanitizeErrorMessage(error.localizedDescription)
            self.error = AppModelError(message: message)
        }
    }

    private func runKubectl(arguments: [String]) async throws {
        let runner = KubectlRunner()
        _ = try await runner.run(arguments: arguments, kubeconfigPath: kubeconfigEnvValue ?? KubectlDefaults.defaultKubeconfigPath())
    }

    private func invalidateCachedNodeData(for cluster: Cluster) {
        if let service = clusterService as? KubectlClusterService {
            service.invalidateNodeCache(contextName: cluster.contextName)
        }
    }

    private func beginNodeAction(contextName: String, nodeName: String) -> String {
        let key = nodeActionKey(contextName: contextName, nodeName: nodeName)
        nodeActionsInProgress.insert(key)
        nodeActionFeedback.removeValue(forKey: key)
        return key
    }

    private func endNodeAction(key: String) {
        nodeActionsInProgress.remove(key)
    }

    func isNodeActionInProgress(contextName: String, nodeName: String) -> Bool {
        nodeActionsInProgress.contains(nodeActionKey(contextName: contextName, nodeName: nodeName))
    }

    func nodeActionError(contextName: String, nodeName: String) -> NodeActionFeedback? {
        nodeActionFeedback[nodeActionKey(contextName: contextName, nodeName: nodeName)]
    }

    private func nodeActionKey(contextName: String, nodeName: String) -> String {
        "\(contextName)|\(nodeName)"
    }

    private func showBanner(_ message: String, style: BannerMessage.Style) {
        withAnimation(.easeInOut(duration: 0.2)) {
            banner = BannerMessage(text: message, style: style)
        }
        let currentID = banner?.id
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                guard let self, self.banner?.id == currentID else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.banner = nil
                }
            }
        }
    }

    private func connectCluster(clusterID: Cluster.ID, contextName: String, preferredNamespace: String?) async {
        do {
            if let current = connectedClusterID, current != clusterID {
                await disconnectCluster(clusterID: current)
            }

            stopClusterWatcher()
            stopAllNamespaceWatchers()

            KubectlDefaults.debug("Loading cluster details for \(contextName)")
            var detailed = try await clusterService.loadClusterDetails(contextName: contextName, focusNamespace: preferredNamespace)
            detailed.isConnected = true
            replaceCluster(detailed)
            connectedClusterID = detailed.id
            selectedClusterID = detailed.id
            if let pendingTab = pendingPreferredTab {
                selectedResourceTab = pendingTab
                pendingPreferredTab = nil
            } else {
                selectedResourceTab = .overview
            }

            startClusterWatcher(clusterID: detailed.id, contextName: contextName)
            pendingPreferredContext = nil

            await refreshHelmReleases(clusterID: detailed.id, contextName: contextName)

            if let preferredNamespace {
                KubectlDefaults.debug("Preferred namespace: \(preferredNamespace)")
                if preferredNamespace == AppModel.allNamespacesPreferenceValue {
                    selectedNamespaceID = AppModel.allNamespacesNamespaceID
                    await ensureAllNamespacesLoaded(clusterID: detailed.id, contextName: contextName)
                } else if let resolved = await loadNamespaceIfNeeded(clusterID: detailed.id, namespaceName: preferredNamespace) {
                    selectedNamespaceID = resolved.id
                } else if let namespace = detailed.namespaces.first(where: { $0.name == preferredNamespace }) {
                    selectedNamespaceID = namespace.id
                }
                pendingPreferredNamespace = nil
            } else if let first = detailed.namespaces.first {
                if let resolved = await loadNamespaceIfNeeded(clusterID: detailed.id, namespaceName: first.name) {
                    selectedNamespaceID = resolved.id
                } else {
                    selectedNamespaceID = first.id
                }
            }
            KubectlDefaults.debug("Selected namespace id: \(selectedNamespaceID?.uuidString ?? "nil")")
            error = nil
            persistSelection()
        } catch {
            let message = sanitizeErrorMessage(error.localizedDescription)
            self.error = AppModelError(message: message)
            connectedClusterID = nil
            selectedNamespaceID = nil
            selectedResourceTab = .overview
            updateClusterAfterFailedConnection(clusterID: clusterID, message: message)
            persistSelection()
        }
    }

    private func disconnectCluster(clusterID: Cluster.ID) async {
        stopClusterWatcher()
        stopAllNamespaceWatchers()
        let forwards = activePortForwards
        activePortForwards.removeAll()
        for forward in forwards {
            try? await portForwardService.stopForward(forward)
        }

        if let index = clusters.firstIndex(where: { $0.id == clusterID }) {
            var cluster = clusters[index]
            cluster.isConnected = false
            cluster.namespaces = []
            cluster.nodeSummary = NodeSummary(total: 0, ready: 0, cpuUsage: nil, memoryUsage: nil, diskUsage: nil, networkReceiveBytes: nil, networkTransmitBytes: nil)
            cluster.nodes = []
            cluster.helmReleases = []
            clusters[index] = cluster
        }
        if connectedClusterID == clusterID {
            connectedClusterID = nil
        }
        if let context = clusters.first(where: { $0.id == clusterID })?.contextName {
            helmErrors[context] = nil
        }
        selectedNamespaceID = nil
        selectedResourceTab = .overview
        clearClusterMetrics(for: clusterID)
        persistSelection()
    }

    private func replaceCluster(_ updated: Cluster) {
        if let index = clusters.firstIndex(where: { $0.id == updated.id }) {
            clusters[index] = updated
        } else {
            clusters.append(updated)
        }
        if isQuickSearchPresented {
            refreshQuickSearchResults()
        }
    }

    private func updateClusterAfterFailedConnection(clusterID: Cluster.ID, message: String) {
        if let index = clusters.firstIndex(where: { $0.id == clusterID }) {
            clusters[index].isConnected = false
            clusters[index].namespaces = []
            clusters[index].health = .unreachable
            clusters[index].nodeSummary = NodeSummary(total: 0, ready: 0, cpuUsage: nil, memoryUsage: nil, diskUsage: nil, networkReceiveBytes: nil, networkTransmitBytes: nil)
            clusters[index].nodes = []
            clusters[index].notes = message
        }
        clearClusterMetrics(for: clusterID)
    }

    @discardableResult
    func loadNamespaceIfNeeded(clusterID: Cluster.ID, namespaceName: String) async -> Namespace? {
        guard let clusterIndex = clusters.firstIndex(where: { $0.id == clusterID }) else { return nil }
        guard namespaceName != AppModel.allNamespacesDisplayName,
              namespaceName != AppModel.allNamespacesPreferenceValue else { return nil }
        let cluster = clusters[clusterIndex]
        guard cluster.isConnected else { return nil }
        guard let namespaceIndex = cluster.namespaces.firstIndex(where: { $0.name == namespaceName }) else { return nil }
        var namespace = cluster.namespaces[namespaceIndex]
        guard !namespace.isLoaded else { return namespace }

        do {
            KubectlDefaults.debug("Loading namespace \(namespaceName) for \(cluster.contextName)")
            let detailed = try await clusterService.loadNamespaceDetails(contextName: cluster.contextName, namespace: namespaceName)
            namespace.workloads = detailed.workloads
            namespace.pods = detailed.pods
            namespace.events = detailed.events
            namespace.alerts = detailed.alerts
            namespace.configResources = detailed.configResources
            namespace.isLoaded = true
            var updatedCluster = cluster
            updatedCluster.namespaces[namespaceIndex] = namespace
            if namespace.workloads.contains(where: { $0.status != .healthy }) {
                updatedCluster.health = .degraded
            }
            clusters[clusterIndex] = updatedCluster
            emitServiceTelemetry(clusterID: cluster.id, contextName: cluster.contextName, namespace: namespace)
            startNamespaceWatcher(clusterID: cluster.id, contextName: cluster.contextName, namespaceName: namespaceName)
            namespaceRetryTasks[namespaceName]?.cancel()
            namespaceRetryTasks.removeValue(forKey: namespaceName)
            KubectlDefaults.debug("Namespace \(namespaceName) loaded: workloads=\(namespace.workloads.count) pods=\(namespace.pods.count) events=\(namespace.events.count)")
            persistSelection()
            return namespace
        } catch {
            if isTransientKubectlDecodeError(error) {
                KubectlDefaults.debug("Namespace \(namespaceName) decode failure; retrying shortly.")
                scheduleNamespaceRetry(clusterID: clusterID, namespaceName: namespaceName)
                return nil
            }
            let message = sanitizeErrorMessage(error.localizedDescription)
            self.error = AppModelError(message: message)
            var updatedCluster = cluster
            updatedCluster.notes = message
            clusters[clusterIndex] = updatedCluster
            KubectlDefaults.debug("Namespace \(namespaceName) failed: \(message)")
            return nil
        }
    }

    private func validateKubeconfig(path: String?) async throws {
        let runner = KubectlRunner()
        _ = try await runner.run(arguments: ["config", "view", "-o", "json"], kubeconfigPath: path)
    }

    private func rebuildServices(with paths: [String]) {
        stopClusterWatcher()
        stopAllNamespaceWatchers()
        activePortForwards.removeAll()
        clusters = []
        connectedClusterID = nil
        selectedClusterID = nil
        selectedNamespaceID = nil
        selectedResourceTab = .overview
        clusterMetricsHistory.removeAll()
        clusterOverviewMetrics.removeAll()

        let joinedPath = AppModel.joinedKubeconfigPath(for: paths)

        if let service = clusterService as? KubectlClusterService {
            clusterService = service.withKubeconfig(joinedPath)
        }
        if let service = logService as? KubectlLogStreamingService {
            logService = service.withKubeconfig(joinedPath)
        }
        if let service = execService as? KubectlExecService {
            execService = service.withKubeconfig(joinedPath)
        }
        if portForwardService is KubectlPortForwardService {
            portForwardService = KubectlPortForwardService(kubeconfigPath: joinedPath ?? KubectlDefaults.defaultKubeconfigPath())
        }
        if let service = editService as? KubectlEditService {
            editService = service.withKubeconfig(joinedPath)
        }
    }

    private func persistSelection() {
        if isRestoringPreferences { return }

        let defaults = UserDefaults.standard
        if let context = selectedCluster?.contextName {
            defaults.set(context, forKey: PreferenceKeys.selectedContext)
        } else {
            defaults.removeObject(forKey: PreferenceKeys.selectedContext)
        }

        if let namespace = selectedNamespace?.name {
            if selectedNamespaceID == AppModel.allNamespacesNamespaceID {
                defaults.set(AppModel.allNamespacesPreferenceValue, forKey: PreferenceKeys.selectedNamespace)
            } else {
                defaults.set(namespace, forKey: PreferenceKeys.selectedNamespace)
            }
        } else {
            defaults.removeObject(forKey: PreferenceKeys.selectedNamespace)
        }

        if let connected = connectedCluster?.contextName {
            defaults.set(connected, forKey: PreferenceKeys.connectedContext)
        } else {
            defaults.removeObject(forKey: PreferenceKeys.connectedContext)
        }

        defaults.set(selectedResourceTab.preferenceValue, forKey: PreferenceKeys.selectedTab)
    }

    private func loadSortPreferences(from defaults: UserDefaults) {
        let decoder = JSONDecoder()
        if let workloadData = defaults.data(forKey: PreferenceKeys.workloadSort),
           let option = try? decoder.decode(WorkloadSortOption.self, from: workloadData) {
            workloadSortOption = option
        }
        if let nodeData = defaults.data(forKey: PreferenceKeys.nodeSort),
           let option = try? decoder.decode(NodeSortOption.self, from: nodeData) {
            nodeSortOption = option
        }
    }

    private func loadFilterPreferences(from defaults: UserDefaults) {
        let decoder = JSONDecoder()
        if let workloadData = defaults.data(forKey: PreferenceKeys.workloadFilter),
           let state = try? decoder.decode(WorkloadFilterState.self, from: workloadData) {
            workloadFilterState = state
        }
        if let podData = defaults.data(forKey: PreferenceKeys.podFilter),
           let state = try? decoder.decode(PodFilterState.self, from: podData) {
            podFilterState = state
        }
        if let nodeData = defaults.data(forKey: PreferenceKeys.nodeFilter),
           let state = try? decoder.decode(NodeFilterState.self, from: nodeData) {
            nodeFilterState = state
        }
        if let configData = defaults.data(forKey: PreferenceKeys.configFilter),
           let state = try? decoder.decode(ConfigFilterState.self, from: configData) {
            configFilterState = state
        }
    }

    private func persistSortPreferencesIfNeeded() {
        guard !isRestoringPreferences else { return }
        let encoder = JSONEncoder()
        let defaults = UserDefaults.standard
        if let workloadData = try? encoder.encode(workloadSortOption) {
            defaults.set(workloadData, forKey: PreferenceKeys.workloadSort)
        }
        if let nodeData = try? encoder.encode(nodeSortOption) {
            defaults.set(nodeData, forKey: PreferenceKeys.nodeSort)
        }
    }

    private func persistFilterPreferencesIfNeeded() {
        guard !isRestoringPreferences else { return }
        let encoder = JSONEncoder()
        let defaults = UserDefaults.standard
        if let workloadData = try? encoder.encode(workloadFilterState) {
            defaults.set(workloadData, forKey: PreferenceKeys.workloadFilter)
        }
        if let podData = try? encoder.encode(podFilterState) {
            defaults.set(podData, forKey: PreferenceKeys.podFilter)
        }
        if let nodeData = try? encoder.encode(nodeFilterState) {
            defaults.set(nodeData, forKey: PreferenceKeys.nodeFilter)
        }
        if let configData = try? encoder.encode(configFilterState) {
            defaults.set(configData, forKey: PreferenceKeys.configFilter)
        }
    }

    private func persistKubeconfigSources(_ paths: [String]) {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(paths) {
            defaults.set(data, forKey: PreferenceKeys.kubeconfigSources)
        }
        defaults.removeObject(forKey: PreferenceKeys.kubeconfigPath)
    }

    private func clearSelectionPreferences() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: PreferenceKeys.selectedContext)
        defaults.removeObject(forKey: PreferenceKeys.selectedNamespace)
        defaults.removeObject(forKey: PreferenceKeys.connectedContext)
        defaults.removeObject(forKey: PreferenceKeys.selectedTab)
    }

    func reloadHelmReleases(for cluster: Cluster) async {
        await refreshHelmReleases(clusterID: cluster.id, contextName: cluster.contextName)
    }

    private func refreshHelmReleases(clusterID: Cluster.ID, contextName: String) async {
        helmLoadingContexts.insert(contextName)
        defer { helmLoadingContexts.remove(contextName) }
        do {
            let releases = try await helmService.listReleases(contextName: contextName)
            applyHelmReleases(clusterID: clusterID, releases: releases)
            helmErrors[contextName] = nil
        } catch {
            let message = sanitizeErrorMessage(error.localizedDescription)
            helmErrors[contextName] = message
        }
    }

    private func sanitizeErrorMessage(_ raw: String) -> String {
        let lines = raw
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var seen = Set<String>()
        var unique: [String] = []
        for line in lines {
            if seen.insert(line).inserted {
                unique.append(line)
            }
        }

        let normalized = unique.joined(separator: "\n")

        if normalized.contains("gke-gcloud-auth-plugin not found") {
            return "Google Kubernetes Engine credential plugin missing. Install via 'gcloud components install gke-gcloud-auth-plugin' and rerun connect.\n" + normalized
        }

        if normalized.contains("executable gcloud") {
            return "gcloud executable not found. Ensure Google Cloud SDK is installed and available in PATH.\n" + normalized
        }

        let lowercased = normalized.lowercased()

        if lowercased.contains("forbidden") || (lowercased.contains(" cannot ") && lowercased.contains(" resource")) {
            return "Access denied by Kubernetes RBAC. Verify your role bindings or request the required permissions before retrying.\n" + normalized
        }

        if lowercased.contains("unauthorized") || lowercased.contains("authentication") || lowercased.contains("expired token") {
            return "Authentication failed. Refresh your Kubernetes credentials or log in again, then retry the action.\n" + normalized
        }

        return normalized.isEmpty ? raw : normalized
    }

    private func isTransientKubectlDecodeError(_ error: Error) -> Bool {
        if let kubectlError = error as? KubectlError,
           kubectlError.message.localizedCaseInsensitiveContains("failed to decode kubectl response") {
            return true
        }
        let description = error.localizedDescription.lowercased()
        return description.contains("failed to decode kubectl response")
    }

    private func scheduleNamespaceRetry(clusterID: Cluster.ID, namespaceName: String) {
        namespaceRetryTasks[namespaceName]?.cancel()
        let task = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                return
            }
            guard let self else { return }
            await self.performNamespaceRetry(clusterID: clusterID, namespaceName: namespaceName)
        }
        namespaceRetryTasks[namespaceName] = task
    }

    @MainActor
    private func performNamespaceRetry(clusterID: Cluster.ID, namespaceName: String) async {
        namespaceRetryTasks[namespaceName] = nil
        _ = await loadNamespaceIfNeeded(clusterID: clusterID, namespaceName: namespaceName)
    }

    private func applyOptimisticSecretUpdate(
        clusterID: Cluster.ID,
        namespaceName: String,
        secretName: String,
        entries: [SecretEntryEditor]
    ) {
        guard let clusterIndex = clusters.firstIndex(where: { $0.id == clusterID }) else { return }
        var cluster = clusters[clusterIndex]
        guard let namespaceIndex = cluster.namespaces.firstIndex(where: { $0.name == namespaceName }) else { return }

        var namespace = cluster.namespaces[namespaceIndex]
        guard let secretIndex = namespace.configResources.firstIndex(where: { $0.kind == .secret && $0.name == secretName }) else { return }

        var summary = namespace.configResources[secretIndex]
        let updatedEntries = entries
            .map { SecretDataEntry(key: $0.key, encodedValue: $0.encodedValueForSave()) }
            .sorted { $0.key < $1.key }
        summary.secretEntries = updatedEntries
        summary.dataCount = updatedEntries.count
        namespace.configResources[secretIndex] = summary
        cluster.namespaces[namespaceIndex] = namespace
        clusters[clusterIndex] = cluster
    }

    private func computeSecretDiff(
        original: [SecretDataEntry]?,
        updated: [SecretEntryEditor]
    ) -> [SecretDiffSummary] {
        SecretDiffSummary.compute(original: original, updated: updated)
    }

    private func applyOptimisticConfigMapUpdate(
        clusterID: Cluster.ID,
        namespaceName: String,
        configMapName: String,
        entries: [ConfigMapEntryEditor]
    ) {
        guard let clusterIndex = clusters.firstIndex(where: { $0.id == clusterID }) else { return }
        var cluster = clusters[clusterIndex]
        guard let namespaceIndex = cluster.namespaces.firstIndex(where: { $0.name == namespaceName }) else { return }

        var namespace = cluster.namespaces[namespaceIndex]
        guard let configMapIndex = namespace.configResources.firstIndex(where: { $0.kind == .configMap && $0.name == configMapName }) else { return }

        var summary = namespace.configResources[configMapIndex]
        let updatedEntries = entries
            .map { ConfigMapEntry(key: $0.key, value: $0.valueForSave(), isBinary: $0.isBinary) }
            .sorted { $0.key < $1.key }
        summary.configMapEntries = updatedEntries
        summary.dataCount = updatedEntries.count
        namespace.configResources[configMapIndex] = summary
        cluster.namespaces[namespaceIndex] = namespace
        clusters[clusterIndex] = cluster
    }

    private func computeConfigMapDiff(
        original: [ConfigMapEntry]?,
        updated: [ConfigMapEntryEditor]
    ) -> [ConfigMapDiffSummary] {
        ConfigMapDiffSummary.compute(original: original, updated: updated)
    }

    private func stopClusterWatcher() {
        clusterRefreshTask?.cancel()
        clusterRefreshTask = nil
    }

    private func stopAllNamespaceWatchers() {
        for task in namespaceRefreshTasks.values {
            task.cancel()
        }
        namespaceRefreshTasks.removeAll()
        for task in namespaceRetryTasks.values {
            task.cancel()
        }
        namespaceRetryTasks.removeAll()
    }

    private func startClusterWatcher(clusterID: Cluster.ID, contextName: String) {
        clusterRefreshTask?.cancel()
        clusterRefreshTask = Task { [weak self] in
            guard let self else { return }
            await self.clusterWatcherLoop(clusterID: clusterID, contextName: contextName)
        }
    }

    @MainActor
    private func clusterWatcherLoop(clusterID: Cluster.ID, contextName: String) async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: clusterRefreshIntervalNanoseconds)
            } catch {
                break
            }
            if Task.isCancelled { break }
            await updateClusterSnapshot(clusterID: clusterID, contextName: contextName)
        }
    }

    @MainActor
    private func updateClusterSnapshot(clusterID: Cluster.ID, contextName: String) async {
        do {
            let detailed = try await clusterService.loadClusterDetails(contextName: contextName, focusNamespace: selectedNamespace?.name)
            mergeConnectedCluster(clusterID: clusterID, updatedCluster: detailed)
        } catch {
            let message = sanitizeErrorMessage(error.localizedDescription)
            if let index = clusters.firstIndex(where: { $0.id == clusterID }) {
                clusters[index].notes = message
                clusters[index].health = .degraded
            }
            if self.error == nil {
                self.error = AppModelError(message: message)
            }
        }
    }

    private func startNamespaceWatcher(clusterID: Cluster.ID, contextName: String, namespaceName: String) {
        namespaceRefreshTasks[namespaceName]?.cancel()
        namespaceRefreshTasks[namespaceName] = Task { [weak self] in
            guard let self else { return }
            await self.namespaceWatcherLoop(clusterID: clusterID, contextName: contextName, namespaceName: namespaceName)
        }
    }

    @MainActor
    private func namespaceWatcherLoop(clusterID: Cluster.ID, contextName: String, namespaceName: String) async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: namespaceRefreshIntervalNanoseconds)
            } catch {
                break
            }
            if Task.isCancelled { break }
            await refreshNamespace(clusterID: clusterID, contextName: contextName, namespaceName: namespaceName)
        }
    }

    @MainActor
    private func refreshNamespace(clusterID: Cluster.ID, contextName: String, namespaceName: String) async {
        guard let cluster = clusters.first(where: { $0.id == clusterID }), cluster.isConnected else { return }
        do {
            let detailed = try await clusterService.loadNamespaceDetails(contextName: contextName, namespace: namespaceName)
            applyNamespaceDetails(clusterID: clusterID, namespaceDetail: detailed)
        } catch {
            if isTransientKubectlDecodeError(error) {
                KubectlDefaults.debug("Namespace \(namespaceName) decode failure during refresh; will retry on next interval.")
                return
            }
            let message = sanitizeErrorMessage(error.localizedDescription)
            if self.error == nil {
                self.error = AppModelError(message: message)
            }
        }
    }

    @MainActor
    private func mergeConnectedCluster(clusterID: Cluster.ID, updatedCluster: Cluster) {
        guard let index = clusters.firstIndex(where: { $0.id == clusterID }) else { return }
        let existing = clusters[index]
        var merged = updatedCluster

        let existingNamespaces = Dictionary(uniqueKeysWithValues: existing.namespaces.map { ($0.name, $0) })
        merged.namespaces = merged.namespaces.map { namespace in
            guard let existingNamespace = existingNamespaces[namespace.name] else { return namespace }
            let shouldReuseExistingData = !namespace.isLoaded && existingNamespace.isLoaded
            return Namespace(
                id: existingNamespace.id,
                name: namespace.name,
                workloads: shouldReuseExistingData ? existingNamespace.workloads : namespace.workloads,
                pods: shouldReuseExistingData ? existingNamespace.pods : namespace.pods,
                events: shouldReuseExistingData ? existingNamespace.events : namespace.events,
                alerts: shouldReuseExistingData ? existingNamespace.alerts : namespace.alerts,
                configResources: shouldReuseExistingData ? existingNamespace.configResources : namespace.configResources,
                services: shouldReuseExistingData ? existingNamespace.services : namespace.services,
                ingresses: shouldReuseExistingData ? existingNamespace.ingresses : namespace.ingresses,
                persistentVolumeClaims: shouldReuseExistingData ? existingNamespace.persistentVolumeClaims : namespace.persistentVolumeClaims,
                serviceAccounts: shouldReuseExistingData ? existingNamespace.serviceAccounts : namespace.serviceAccounts,
                roles: shouldReuseExistingData ? existingNamespace.roles : namespace.roles,
                roleBindings: shouldReuseExistingData ? existingNamespace.roleBindings : namespace.roleBindings,
                isLoaded: namespace.isLoaded || existingNamespace.isLoaded
            )
        }

        if merged.notes == nil {
            merged.notes = existing.notes
        }

        if merged.nodes.isEmpty, !existing.nodes.isEmpty {
            merged.nodes = existing.nodes
        }

        if merged.helmReleases.isEmpty, !existing.helmReleases.isEmpty {
            merged.helmReleases = existing.helmReleases
        }

        if merged.customResources.isEmpty, !existing.customResources.isEmpty {
            merged.customResources = existing.customResources
        }

        merged.isConnected = true
        merged.lastSynced = Date()
        clusters[index] = merged
        recordMetricsSample(for: clusterID, cluster: merged)
    }

    private func recordMetricsSample(for clusterID: Cluster.ID, cluster: Cluster) {
        let timestamp = cluster.lastSynced
        var history = clusterMetricsHistory[clusterID] ?? ClusterMetricHistory()

        func append(_ series: inout [MetricPoint], value: Double?) {
            guard let value else { return }
            series.append(MetricPoint(timestamp: timestamp, value: value))
            if series.count > metricsSampleLimit {
                series.removeFirst(series.count - metricsSampleLimit)
            }
        }

        append(&history.cpuPoints, value: clampRatio(cluster.nodeSummary.cpuUsage))
        append(&history.memoryPoints, value: clampRatio(cluster.nodeSummary.memoryUsage))
        append(&history.diskPoints, value: clampRatio(cluster.nodeSummary.diskUsage))

        if let rx = cluster.nodeSummary.networkReceiveBytes,
           let tx = cluster.nodeSummary.networkTransmitBytes {
            if let last = history.lastNetworkTotals {
                let deltaRx = max(rx - last.rxBytes, 0)
                let deltaTx = max(tx - last.txBytes, 0)
                let interval = timestamp.timeIntervalSince(last.timestamp)
                if interval > 0 {
                    let rate = (deltaRx + deltaTx) / interval
                    append(&history.networkPoints, value: rate)
                }
            }
            history.lastNetworkTotals = NetworkTotals(rxBytes: rx, txBytes: tx, timestamp: timestamp)
        }

        history.nodeHeatmap = buildNodeHeatmap(from: cluster)
        history.podHeatmap = buildPodHeatmap(from: cluster)
        clusterMetricsHistory[clusterID] = history

        clusterOverviewMetrics[clusterID] = ClusterOverviewMetrics(
            timestamp: timestamp,
            cpu: MetricSeries(points: history.cpuPoints),
            memory: MetricSeries(points: history.memoryPoints),
            disk: MetricSeries(points: history.diskPoints),
            network: MetricSeries(points: history.networkPoints),
            nodeHeatmap: history.nodeHeatmap,
            podHeatmap: history.podHeatmap
        )

        recordWorkloadHistory(for: clusterID, cluster: cluster, timestamp: timestamp)
    }

    private func recordWorkloadHistory(for clusterID: Cluster.ID, cluster: Cluster, timestamp: Date) {
        var store = workloadRolloutHistory[clusterID] ?? [:]

        func appendSample(_ series: inout [MetricPoint], replicas: Int?) {
            guard let replicas else { return }
            let value = Double(replicas)
            if let last = series.last, abs(last.timestamp.timeIntervalSince(timestamp)) < 0.5 {
                series[series.count - 1] = MetricPoint(id: last.id, timestamp: timestamp, value: value)
            } else {
                series.append(MetricPoint(timestamp: timestamp, value: value))
                if series.count > metricsSampleLimit {
                    series.removeFirst(series.count - metricsSampleLimit)
                }
            }
        }

        for namespace in cluster.namespaces where namespace.isLoaded {
            for workload in namespace.workloads {
                let key = WorkloadHistoryKey(namespace: namespace.name, name: workload.name, kind: workload.kind)
                var series = store[key] ?? WorkloadRolloutSeries()
                appendSample(&series.ready, replicas: workload.readyReplicas)
                appendSample(&series.updated, replicas: workload.updatedReplicas)
                appendSample(&series.available, replicas: workload.availableReplicas)
                store[key] = series
                emitWorkloadTelemetry(cluster: cluster, namespace: namespace, workload: workload, timestamp: timestamp)
            }
        }

        workloadRolloutHistory[clusterID] = store
    }

    private func workloadEventCounts(namespace: Namespace, workload: WorkloadSummary) -> (warnings: Int, errors: Int) {
        let workloadName = workload.name.lowercased()
        let podNames = namespace.pods
            .filter { pod in
                guard let owner = pod.controlledBy?.lowercased() else { return false }
                return owner.contains(workloadName) || owner.contains(workload.kind.displayName.lowercased())
            }
            .map { $0.name.lowercased() }
        var warnings = 0
        var errors = 0
        for event in namespace.events {
            let message = event.message.lowercased()
            let matchesWorkload = message.contains(workloadName)
            let matchesPod = podNames.contains { message.contains($0) }
            guard matchesWorkload || matchesPod else { continue }
            let count = max(event.count, 1)
            switch event.type {
            case .warning: warnings += count
            case .error: errors += count
            default: break
            }
        }
        return (warnings, errors)
    }

    private func emitWorkloadTelemetry(cluster: Cluster, namespace: Namespace, workload: WorkloadSummary, timestamp: Date) {
        let desired = workload.replicas
        let ready = workload.readyReplicas
        let available = workload.availableReplicas ?? 0
        let updated = workload.updatedReplicas ?? 0
        let readinessRatio = desired > 0 ? Double(ready) / Double(desired) : 0
        let availableRatio = desired > 0 ? Double(available) / Double(desired) : 0
        let events = workloadEventCounts(namespace: namespace, workload: workload)

        var attributes: TelemetryAttributes = [
            "cluster_id": .string(cluster.id.uuidString),
            "context": .string(cluster.contextName),
            "namespace": .string(namespace.name),
            "workload": .string(workload.name),
            "kind": .string(workload.kind.displayName),
            "desired": .int(desired),
            "ready": .int(ready),
            "available": .int(available),
            "updated": .int(updated),
            "status": .string(workload.status.displayName),
            "ready_ratio": .double(readinessRatio),
            "available_ratio": .double(availableRatio),
            "warning_events": .int(events.warnings),
            "error_events": .int(events.errors)
        ]

        if let suspension = workload.isSuspended {
            attributes["suspended"] = .bool(suspension)
        }

        Task {
            await telemetryService.record(
                TelemetryEvent(
                    name: "workload_rollout_snapshot",
                    timestamp: timestamp,
                    attributes: attributes
                )
            )
        }
    }

    private func emitServiceTelemetry(clusterID: Cluster.ID, contextName: String, namespace: Namespace) {
        guard !namespace.services.isEmpty else { return }
        let timestamp = Date()
        let services = namespace.services
        let total = services.count
        let warnings = services.filter { $0.healthState == .warning }.count
        let failing = services.filter { $0.healthState == .failing }.count
        let readyEndpoints = services.reduce(into: 0) { $0 += $1.readyEndpointCount }
        let totalEndpoints = services.reduce(into: 0) { $0 += $1.totalEndpointCount }

        let summaryAttributes: TelemetryAttributes = [
            "cluster_id": .string(clusterID.uuidString),
            "context": .string(contextName),
            "namespace": .string(namespace.name),
            "services_total": .int(total),
            "services_warning": .int(warnings),
            "services_failing": .int(failing),
            "endpoints_ready": .int(readyEndpoints),
            "endpoints_total": .int(totalEndpoints)
        ]

        Task {
            await telemetryService.record(
                TelemetryEvent(
                    name: "service_namespace_summary",
                    timestamp: timestamp,
                    attributes: summaryAttributes
                )
            )

            for service in services.prefix(50) {
                var attributes: TelemetryAttributes = [
                    "cluster_id": .string(clusterID.uuidString),
                    "context": .string(contextName),
                    "namespace": .string(namespace.name),
                    "service": .string(service.name),
                    "type": .string(service.type),
                    "health_state": .string(service.healthState.rawValue),
                    "ready_endpoints": .int(service.readyEndpointCount),
                    "not_ready_endpoints": .int(service.notReadyEndpointCount),
                    "total_endpoints": .int(service.totalEndpointCount)
                ]

                if let latencyP50 = service.latencyP50 {
                    attributes["latency_p50_ms"] = .double(latencyP50 * 1_000)
                }
                if let latencyP95 = service.latencyP95 {
                    attributes["latency_p95_ms"] = .double(latencyP95 * 1_000)
                }
                if !service.targetPods.isEmpty {
                    attributes["target_pods"] = .string(service.targetPods.joined(separator: ","))
                }

                await telemetryService.record(
                    TelemetryEvent(
                        name: "service_health_snapshot",
                        timestamp: timestamp,
                        attributes: attributes
                    )
                )
            }
        }
    }

    private func emitPortForwardEvent(name: String, request: PortForwardRequest, status: PortForwardStatus, message: String?) {
        var attributes: TelemetryAttributes = [
            "cluster_id": .string(request.clusterID.uuidString),
            "context": .string(request.contextName),
            "namespace": .string(request.namespace),
            "pod": .string(request.podName),
            "local_port": .int(request.localPort),
            "remote_port": .int(request.remotePort),
            "status": .string(portForwardStatusString(status))
        ]
        if let message, !message.isEmpty {
            attributes["message"] = .string(message)
        }

        Task {
            await telemetryService.record(
                TelemetryEvent(
                    name: name,
                    attributes: attributes
                )
            )
        }
    }

    private func emitPortForwardFailure(request: PortForwardRequest, message: String) {
        emitPortForwardEvent(name: "port_forward_failed", request: request, status: .failed(message), message: message)
    }

    private func portForwardStatusString(_ status: PortForwardStatus) -> String {
        switch status {
        case .establishing: return "establishing"
        case .active: return "active"
        case .failed: return "failed"
        }
    }

    private func buildNodeHeatmap(from cluster: Cluster) -> [HeatmapEntry] {
        let entries = cluster.nodes.compactMap { node -> HeatmapEntry? in
            let cpu = clampRatio(node.cpuUsageRatio)
            let memory = clampRatio(node.memoryUsageRatio)
            guard cpu != nil || memory != nil else { return nil }
            return HeatmapEntry(
                key: "node:\(node.name)",
                label: node.name,
                cpuRatio: cpu,
                memoryRatio: memory
            )
        }
        return Array(entries
            .sorted(by: { ($0.cpuRatio ?? 0) > ($1.cpuRatio ?? 0) })
            .prefix(12))
    }

    private func buildPodHeatmap(from cluster: Cluster) -> [HeatmapEntry] {
        let pods = cluster.namespaces.flatMap { namespace in
            namespace.pods.map { (namespace.name, $0) }
        }
        let entries = pods.compactMap { namespace, pod -> HeatmapEntry? in
            let cpu = clampRatio(pod.cpuUsageRatio)
            let memory = clampRatio(pod.memoryUsageRatio)
            guard cpu != nil || memory != nil else { return nil }
            return HeatmapEntry(
                key: "pod:\(namespace)/\(pod.name)",
                label: "\(namespace)/\(pod.name)",
                cpuRatio: cpu,
                memoryRatio: memory
            )
        }
        return Array(entries
            .sorted(by: { ($0.cpuRatio ?? 0) > ($1.cpuRatio ?? 0) })
            .prefix(12))
    }

    private func clearClusterMetrics(for clusterID: Cluster.ID) {
        clusterMetricsHistory.removeValue(forKey: clusterID)
        clusterOverviewMetrics.removeValue(forKey: clusterID)
    }

    private func clampRatio(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return min(max(value, 0), 1)
    }

    private func fetchResourceYAML(contextName: String, namespace: String?, resourceType: String, name: String) async -> Result<String, AppModelError> {
        do {
            let yaml = try await clusterService.loadResourceYAML(
                contextName: contextName,
                namespace: namespace,
                resourceType: resourceType,
                name: name
            )
            return .success(yaml)
        } catch {
            let message = sanitizeErrorMessage(error.localizedDescription)
            return .failure(AppModelError(message: message))
        }
    }

    @MainActor
    private func applyNamespaceDetails(clusterID: Cluster.ID, namespaceDetail: Namespace) {
        guard let clusterIndex = clusters.firstIndex(where: { $0.id == clusterID }) else { return }
        var cluster = clusters[clusterIndex]
        guard cluster.isConnected else { return }
        guard let namespaceIndex = cluster.namespaces.firstIndex(where: { $0.name == namespaceDetail.name }) else { return }

        var namespace = cluster.namespaces[namespaceIndex]
        namespace.workloads = namespaceDetail.workloads
        namespace.pods = namespaceDetail.pods
        namespace.events = namespaceDetail.events
        namespace.alerts = namespaceDetail.alerts
        namespace.configResources = namespaceDetail.configResources
        namespace.services = namespaceDetail.services
        namespace.ingresses = namespaceDetail.ingresses
        namespace.persistentVolumeClaims = namespaceDetail.persistentVolumeClaims
        namespace.serviceAccounts = namespaceDetail.serviceAccounts
        namespace.roles = namespaceDetail.roles
        namespace.roleBindings = namespaceDetail.roleBindings
        namespace.isLoaded = true

        cluster.namespaces[namespaceIndex] = namespace
        if namespace.workloads.contains(where: { $0.status != .healthy }) {
            cluster.health = .degraded
        }
        cluster.lastSynced = Date()
        clusters[clusterIndex] = cluster
        persistSelection()
        emitServiceTelemetry(clusterID: cluster.id, contextName: cluster.contextName, namespace: namespace)
    }

    private func applyHelmReleases(clusterID: Cluster.ID, releases: [HelmRelease]) {
        guard let index = clusters.firstIndex(where: { $0.id == clusterID }) else { return }
        clusters[index].helmReleases = releases
    }


    static var preview: AppModel {
#if DEBUG
        let model = AppModel(
            clusterService: MockClusterService(),
            logService: MockLogStreamingService(),
            execService: MockExecService(),
            portForwardService: MockPortForwardService(),
            editService: MockEditService(),
            helmService: MockHelmService(releases: []),
            telemetryService: NoopTelemetryService()
        )
#else
        let model = AppModel()
#endif
        model.clusters = MockClusterService.sampleClusters
        model.selectedClusterID = model.clusters.first?.id
        model.selectedNamespaceID = model.clusters.first?.namespaces.first?.id
        model.connectedClusterID = model.clusters.first?.id
        if !model.clusters.isEmpty {
            model.clusters[0].helmReleases = [
                HelmRelease(name: "nginx", namespace: "default", revision: 3, status: "deployed", chart: "nginx-4.0.3", appVersion: "1.16.0", updated: Date().addingTimeInterval(-7200)),
                HelmRelease(name: "loki", namespace: "observability", revision: 5, status: "deployed", chart: "loki-stack-2.9.0", appVersion: "2.8.2", updated: Date().addingTimeInterval(-18_000))
            ]
        }
        if let cluster = model.selectedCluster {
            model.activePortForwards = [
                ActivePortForward(
                    id: UUID(),
                    request: PortForwardRequest(
                        clusterID: cluster.id,
                        contextName: cluster.contextName,
                        namespace: "production",
                        podName: "checkout-service-0ddf7",
                        remotePort: 443,
                        localPort: 8443
                    ),
                    startedAt: Date(),
                    status: .active
                )
            ]
        }
        return model
    }
}

struct AppModelError: Identifiable, LocalizedError {
    let id = UUID()
    let message: String

    var errorDescription: String? { message }
}

struct BannerMessage: Identifiable {
    enum Style {
        case info
        case success
        case warning

        var tint: Color {
            switch self {
            case .info: return .blue
            case .success: return .green
            case .warning: return .orange
            }
        }

        var icon: String {
            switch self {
            case .info: return "info.circle"
            case .success: return "checkmark.circle"
            case .warning: return "exclamationmark.triangle"
            }
        }
    }

    let id = UUID()
    var text: String
    var style: Style
}

struct SecretActionFeedback: Identifiable {
    enum Status {
        case success
        case failure
    }

    let id = UUID()
    let secretName: String
    let namespace: String
    let status: Status
    let message: String
    let kubectlOutput: String?
    let diff: [SecretDiffSummary]
    let timestamp: Date = Date()
}

struct ConfigMapActionFeedback: Identifiable {
    enum Status {
        case success
        case failure
    }

    let id = UUID()
    let configMapName: String
    let namespace: String
    let status: Status
    let message: String
    let kubectlOutput: String?
    let diff: [ConfigMapDiffSummary]
    let timestamp: Date = Date()
}

struct NodeActionFeedback: Identifiable {
    let id = UUID()
    let contextName: String
    let nodeName: String
    let message: String
    let timestamp: Date = Date()
}

private extension String {
    func nilIfEmpty() -> String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}

private extension KubectlClusterService {
    func withKubeconfig(_ path: String?) -> KubectlClusterService {
        KubectlClusterService(kubeconfigPath: path ?? KubectlDefaults.defaultKubeconfigPath())
    }
}

private extension KubectlLogStreamingService {
    func withKubeconfig(_ path: String?) -> KubectlLogStreamingService {
        KubectlLogStreamingService(kubeconfigPath: path ?? KubectlDefaults.defaultKubeconfigPath())
    }
}

private extension KubectlExecService {
    func withKubeconfig(_ path: String?) -> KubectlExecService {
        KubectlExecService(kubeconfigPath: path ?? KubectlDefaults.defaultKubeconfigPath())
    }
}

private extension KubectlEditService {
    func withKubeconfig(_ path: String?) -> KubectlEditService {
        KubectlEditService(kubeconfigPath: path ?? KubectlDefaults.defaultKubeconfigPath())
    }
}

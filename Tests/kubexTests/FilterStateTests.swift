import Foundation
import Testing
@testable import kubex

@Test("Workload filter matches status and labels")
func workloadFilterMatches() {
    let workload = WorkloadSummary(
        id: UUID(),
        name: "api-gateway",
        kind: .deployment,
        replicas: 4,
        readyReplicas: 4,
        status: .healthy,
        updatedReplicas: 4,
        availableReplicas: 4,
        labels: ["app": "api", "tier": "frontend"]
    )

    var filter = WorkloadFilterState()
    #expect(filter.matches(workload))

    filter.statuses.insert(.healthy)
    #expect(filter.matches(workload))

    filter.statuses = Set([.failed])
    #expect(filter.matches(workload) == false)

    filter.statuses = Set([.healthy])
    filter.labelSelectors.insert(LabelSelector(key: "app", value: "api"))
    #expect(filter.matches(workload))

    filter.labelSelectors.insert(LabelSelector(key: "environment", value: "prod"))
    #expect(filter.matches(workload) == false)

    filter.labelSelectors.remove(LabelSelector(key: "environment", value: "prod"))
    filter.labelSelectors.insert(LabelSelector(key: "tier", value: nil))
    #expect(filter.matches(workload))
}

@Test("Pod filter honours phases, warnings, and labels")
func podFilterMatches() {
    let pod = PodSummary(
        id: UUID(),
        name: "api-123",
        namespace: "production",
        phase: .running,
        readyContainers: 1,
        totalContainers: 1,
        restarts: 2,
        nodeName: "node-a",
        containerNames: ["api"],
        warningCount: 1,
        controlledBy: "Deployment/api",
        qosClass: "Burstable",
        age: .hours(2),
        cpuUsage: "120m",
        memoryUsage: "220Mi",
        diskUsage: nil,
        cpuUsageRatio: 0.4,
        memoryUsageRatio: 0.5,
        diskUsageRatio: nil,
        labels: ["app": "api", "env": "prod"]
    )

    var filter = PodFilterState()
    #expect(filter.matches(pod))

    filter.phases.insert(.running)
    #expect(filter.matches(pod))

    filter.onlyWithWarnings = true
    #expect(filter.matches(pod))

    filter.labelSelectors.insert(LabelSelector(key: "env", value: "prod"))
    #expect(filter.matches(pod))

    filter.labelSelectors.insert(LabelSelector(key: "team", value: "payments"))
    #expect(filter.matches(pod) == false)
}

@Test("Node filter respects ready, warning, and labels")
func nodeFilterMatches() {
    let node = NodeInfo(
        id: UUID(),
        name: "node-a",
        warningCount: 2,
        cpuUsage: "1.2 cores",
        cpuUsageRatio: 0.35,
        memoryUsage: "6 GiB",
        memoryUsageRatio: 0.4,
        diskUsage: nil,
        diskRatio: nil,
        networkReceiveBytes: nil,
        networkTransmitBytes: nil,
        taints: [],
        kubeletVersion: "v1.29.2",
        age: .days(30),
        conditions: [
            NodeCondition(type: "Ready", status: "True", reason: nil, message: nil)
        ],
        labels: ["node-role.kubernetes.io/worker": "true", "zone": "us-west-2a"]
    )

    var filter = NodeFilterState()
    #expect(filter.matches(node))

    filter.onlyReady = true
    #expect(filter.matches(node))

    filter.onlyWithWarnings = true
    #expect(filter.matches(node))

    filter.labelSelectors.insert(LabelSelector(key: "zone", value: "us-west-2a"))
    #expect(filter.matches(node))

    filter.labelSelectors.insert(LabelSelector(key: "topology.kubernetes.io/region", value: "us-west-2"))
    #expect(filter.matches(node) == false)
}

@Test("Config filter applies kinds and labels")
func configFilterMatches() {
    let resource = ConfigResourceSummary(
        id: UUID(),
        name: "app-settings",
        kind: .configMap,
        typeDescription: "ConfigMap",
        dataCount: 3,
        summary: nil,
        age: .hours(12),
        secretEntries: nil,
        configMapEntries: nil,
        permissions: .fullAccess,
        labels: ["app": "checkout", "env": "prod"]
    )

    var filter = ConfigFilterState()
    #expect(filter.matches(resource))

    filter.kinds.insert(.configMap)
    #expect(filter.matches(resource))

    filter.labelSelectors.insert(LabelSelector(key: "env", value: "prod"))
    #expect(filter.matches(resource))

    filter.labelSelectors.insert(LabelSelector(key: "team", value: "core"))
    #expect(filter.matches(resource) == false)
}

@MainActor
@Test("Sort and filter preferences persist across model instances")
func sortAndFilterPersistence() async {
    let defaults = UserDefaults.standard
    let keys = [
        "kubex.sort.workloads",
        "kubex.sort.nodes",
        "kubex.filter.workloads",
        "kubex.filter.pods",
        "kubex.filter.nodes",
        "kubex.filter.config"
    ]
    keys.forEach { defaults.removeObject(forKey: $0) }

    let firstModel = AppModel(
        clusterService: MockClusterService(),
        logService: MockLogStreamingService(),
        execService: MockExecService(),
        portForwardService: MockPortForwardService(),
        editService: MockEditService(),
        helmService: MockHelmService(releases: []),
        telemetryService: NoopTelemetryService()
    )

    await firstModel.refreshClusters()

    firstModel.workloadSortOption = WorkloadSortOption(field: .age, direction: .descending)
    firstModel.nodeSortOption = NodeSortOption(field: .cpu, direction: .descending)
    firstModel.workloadFilterState = WorkloadFilterState(statuses: Set([.failed]), labelSelectors: Set([LabelSelector(key: "app", value: "checkout")]))
    firstModel.podFilterState = PodFilterState(phases: Set([.running]), onlyWithWarnings: true, labelSelectors: Set([LabelSelector(key: "env", value: "prod")]))
    firstModel.nodeFilterState = NodeFilterState(onlyReady: true, onlyWithWarnings: false, labelSelectors: Set([LabelSelector(key: "zone", value: "us-west-2a")]))
    firstModel.configFilterState = ConfigFilterState(kinds: Set([.configMap]), labelSelectors: Set([LabelSelector(key: "app", value: "checkout")]))

    await Task.yield()

    let secondModel = AppModel(
        clusterService: MockClusterService(),
        logService: MockLogStreamingService(),
        execService: MockExecService(),
        portForwardService: MockPortForwardService(),
        editService: MockEditService(),
        helmService: MockHelmService(releases: []),
        telemetryService: NoopTelemetryService()
    )

    #expect(secondModel.workloadSortOption.field == .age)
    #expect(secondModel.workloadSortOption.direction == .descending)
    #expect(secondModel.nodeSortOption.field == .cpu)
    #expect(secondModel.nodeSortOption.direction == .descending)
    #expect(secondModel.workloadFilterState.statuses == Set([.failed]))
    #expect(secondModel.workloadFilterState.labelSelectors.contains(LabelSelector(key: "app", value: "checkout")))
    #expect(secondModel.podFilterState.onlyWithWarnings)
    #expect(secondModel.nodeFilterState.onlyReady)
    #expect(secondModel.configFilterState.kinds.contains(.configMap))

    keys.forEach { defaults.removeObject(forKey: $0) }
}

@Test("Namespace permission stores denial reasons")
func namespacePermissionReason() {
    var permissions = NamespacePermissions()
    permissions.apply(PermissionGate(isAllowed: false, reason: "forbidden"), to: .viewPodLogs)

    #expect(!permissions.canViewPodLogs)
    #expect(permissions.reason(for: .viewPodLogs) == "forbidden")
}

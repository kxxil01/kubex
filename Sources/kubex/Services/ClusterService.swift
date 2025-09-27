import Foundation

@MainActor
protocol ClusterService {
    func loadClusters() async throws -> [Cluster]
    func loadClusterDetails(contextName: String, focusNamespace: String?) async throws -> Cluster
    func loadNamespaceDetails(contextName: String, namespace: String) async throws -> Namespace
    func loadPodDetail(contextName: String, namespace: String, pod: String) async throws -> PodDetailData
    func loadResourceYAML(contextName: String, namespace: String?, resourceType: String, name: String) async throws -> String
    func applyResourceYAML(contextName: String, manifestYAML: String) async throws -> String
    func updateSecret(
        contextName: String,
        namespace: String,
        name: String,
        type: String?,
        encodedData: [String: String]
    ) async throws -> String
}

@MainActor
final class MockClusterService: ClusterService {
    static let sampleClusters: [Cluster] = {
        let now = Date()
        let devNamespace = Namespace(
            id: UUID(),
            name: "development",
            workloads: [
                WorkloadSummary(
                    id: UUID(),
                    name: "api-gateway",
                    kind: .deployment,
                    replicas: 4,
                    readyReplicas: 4,
                    status: .healthy
                ),
                WorkloadSummary(
                    id: UUID(),
                    name: "jobs-runner",
                    kind: .cronJob,
                    replicas: 1,
                    readyReplicas: 1,
                    status: .healthy
                ),
                WorkloadSummary(
                    id: UUID(),
                    name: "redis-cache",
                    kind: .statefulSet,
                    replicas: 3,
                    readyReplicas: 3,
                    status: .healthy
                )
            ],
            pods: [
                PodSummary(id: UUID(), name: "api-gateway-5f464", namespace: "development", phase: .running, readyContainers: 2, totalContainers: 2, restarts: 0, nodeName: "node-a", containerNames: ["gateway", "sidecar"], warningCount: 0, controlledBy: "Deployment/api-gateway", qosClass: "Burstable", age: .hours(2), cpuUsage: nil, memoryUsage: nil, diskUsage: nil, cpuUsageRatio: nil, memoryUsageRatio: nil, diskUsageRatio: nil),
                PodSummary(id: UUID(), name: "redis-cache-0", namespace: "development", phase: .running, readyContainers: 1, totalContainers: 1, restarts: 0, nodeName: "node-b", containerNames: ["redis"], warningCount: 0, controlledBy: "StatefulSet/redis-cache", qosClass: "Guaranteed", age: .hours(4), cpuUsage: nil, memoryUsage: nil, diskUsage: nil, cpuUsageRatio: nil, memoryUsageRatio: nil, diskUsageRatio: nil),
                PodSummary(id: UUID(), name: "jobs-runner-120391", namespace: "development", phase: .succeeded, readyContainers: 1, totalContainers: 1, restarts: 0, nodeName: "node-c", containerNames: ["runner"], warningCount: 0, controlledBy: "CronJob/jobs-runner", qosClass: "Burstable", age: .hours(1), cpuUsage: nil, memoryUsage: nil, diskUsage: nil, cpuUsageRatio: nil, memoryUsageRatio: nil, diskUsageRatio: nil)
            ],
            events: [
                EventSummary(id: UUID(), message: "Deployment rollout completed", type: .normal, count: 1, age: .minutes(3), timestamp: Date().addingTimeInterval(-180)),
                EventSummary(id: UUID(), message: "CronJob scheduled execution", type: .normal, count: 2, age: .hours(1), timestamp: Date().addingTimeInterval(-3_600))
            ],
            alerts: [],
            configResources: [
                ConfigResourceSummary(
                    id: UUID(),
                    name: "app-settings",
                    kind: .configMap,
                    typeDescription: "ConfigMap",
                    dataCount: 5,
                    summary: "application.yaml",
                    age: .hours(6)
                ),
                ConfigResourceSummary(
                    id: UUID(),
                    name: "ci-bot",
                    kind: .secret,
                    typeDescription: "Opaque",
                    dataCount: 3,
                    summary: "Token + SSH key",
                    age: .hours(12)
                )
            ],
            services: [
                ServiceSummary(name: "api-service", type: "ClusterIP", clusterIP: "10.12.0.15", ports: "80/TCP", age: .hours(18))
            ],
            ingresses: [
                IngressSummary(name: "api-ingress", className: "nginx", hostRules: "api.dev.company.com → /", serviceTargets: "api-service:80", tls: true, age: .hours(18))
            ],
            persistentVolumeClaims: [
                PersistentVolumeClaimSummary(name: "redis-data", status: "Bound", capacity: "20 GiB", storageClass: "gp2", volumeName: "pvc-redis-dev", age: .days(4))
            ],
            serviceAccounts: [ServiceAccountSummary(name: "deploy-bot", secretCount: 2, age: .hours(24))],
            roles: [RoleSummary(name: "dev-editor", ruleCount: 5, age: .hours(24))],
            roleBindings: [RoleBindingSummary(name: "dev-editor-binding", subjectCount: 1, roleRef: "Role/dev-editor", age: .hours(24))],
            isLoaded: true
        )

        let prodNamespace = Namespace(
            id: UUID(),
            name: "production",
            workloads: [
                WorkloadSummary(
                    id: UUID(),
                    name: "checkout-service",
                    kind: .deployment,
                    replicas: 6,
                    readyReplicas: 5,
                    status: .degraded
                ),
                WorkloadSummary(
                    id: UUID(),
                    name: "orders-db",
                    kind: .statefulSet,
                    replicas: 3,
                    readyReplicas: 3,
                    status: .healthy
                ),
                WorkloadSummary(
                    id: UUID(),
                    name: "event-bus",
                    kind: .daemonSet,
                    replicas: 5,
                    readyReplicas: 5,
                    status: .healthy
                )
            ],
            pods: [
                PodSummary(id: UUID(), name: "checkout-service-0ddf7", namespace: "production", phase: .running, readyContainers: 1, totalContainers: 1, restarts: 0, nodeName: "node-a", containerNames: ["checkout"], warningCount: 0, controlledBy: "ReplicaSet/checkout-service", qosClass: "Burstable", age: .hours(6), cpuUsage: nil, memoryUsage: nil, diskUsage: nil, cpuUsageRatio: nil, memoryUsageRatio: nil, diskUsageRatio: nil),
                PodSummary(id: UUID(), name: "checkout-service-0ddf8", namespace: "production", phase: .running, readyContainers: 1, totalContainers: 1, restarts: 1, nodeName: "node-b", containerNames: ["checkout"], warningCount: 1, controlledBy: "ReplicaSet/checkout-service", qosClass: "Burstable", age: .hours(6), cpuUsage: nil, memoryUsage: nil, diskUsage: nil, cpuUsageRatio: nil, memoryUsageRatio: nil, diskUsageRatio: nil),
                PodSummary(id: UUID(), name: "checkout-service-0ddf9", namespace: "production", phase: .running, readyContainers: 0, totalContainers: 1, restarts: 4, nodeName: "node-c", containerNames: ["checkout"], warningCount: 1, controlledBy: "ReplicaSet/checkout-service", qosClass: "Burstable", age: .hours(6), cpuUsage: nil, memoryUsage: nil, diskUsage: nil, cpuUsageRatio: nil, memoryUsageRatio: nil, diskUsageRatio: nil)
            ],
            events: [
                EventSummary(id: UUID(), message: "Liveness probe failed: checkout-service", type: .warning, count: 3, age: .minutes(10), timestamp: Date().addingTimeInterval(-600)),
                EventSummary(id: UUID(), message: "Scaled deployment checkout-service to 6", type: .normal, count: 1, age: .hours(3), timestamp: Date().addingTimeInterval(-10_800))
            ],
            alerts: ["checkout-service has 1 unhealthy pod"],
            configResources: [
                ConfigResourceSummary(
                    id: UUID(),
                    name: "checkout-config",
                    kind: .configMap,
                    typeDescription: "ConfigMap",
                    dataCount: 8,
                    summary: "Feature flags",
                    age: .hours(8)
                ),
                ConfigResourceSummary(
                    id: UUID(),
                    name: "payments-api-key",
                    kind: .secret,
                    typeDescription: "kubernetes.io/tls",
                    dataCount: 2,
                    summary: "TLS cert",
                    age: .days(2)
                ),
                ConfigResourceSummary(
                    id: UUID(),
                    name: "production-quota",
                    kind: .resourceQuota,
                    typeDescription: "ResourceQuota",
                    dataCount: 4,
                    summary: "cpu=40, memory=160Gi",
                    age: .days(5)
                ),
                ConfigResourceSummary(
                    id: UUID(),
                    name: "pod-limits",
                    kind: .limitRange,
                    typeDescription: "Pod",
                    dataCount: 2,
                    summary: "cpu 100m-2",
                    age: .days(14)
                )
            ],
            services: [
                ServiceSummary(name: "checkout", type: "ClusterIP", clusterIP: "10.40.0.12", ports: "8080/TCP", age: .hours(36)),
                ServiceSummary(name: "orders-db", type: "ClusterIP", clusterIP: "10.40.0.15", ports: "5432/TCP", age: .days(5))
            ],
            ingresses: [
                IngressSummary(name: "checkout-ingress", className: "nginx", hostRules: "checkout.company.com → /", serviceTargets: "checkout:8080", tls: true, age: .hours(32))
            ],
            persistentVolumeClaims: [
                PersistentVolumeClaimSummary(name: "orders-db-claim", status: "Bound", capacity: "100 GiB", storageClass: "gp3", volumeName: "pvc-orders-primary", age: .days(60))
            ],
            serviceAccounts: [ServiceAccountSummary(name: "checkout-sa", secretCount: 1, age: .days(90))],
            roles: [RoleSummary(name: "checkout-deployer", ruleCount: 6, age: .days(45))],
            roleBindings: [RoleBindingSummary(name: "checkout-deployer-binding", subjectCount: 1, roleRef: "Role/checkout-deployer", age: .days(45))],
            isLoaded: true
        )

        let observabilityNamespace = Namespace(
            id: UUID(),
            name: "observability",
            workloads: [
                WorkloadSummary(
                    id: UUID(),
                    name: "prometheus",
                    kind: .statefulSet,
                    replicas: 2,
                    readyReplicas: 2,
                    status: .healthy
                ),
                WorkloadSummary(
                    id: UUID(),
                    name: "grafana",
                    kind: .deployment,
                    replicas: 2,
                    readyReplicas: 2,
                    status: .healthy
                )
            ],
            pods: [
                PodSummary(id: UUID(), name: "grafana-755fd9", namespace: "observability", phase: .running, readyContainers: 1, totalContainers: 1, restarts: 0, nodeName: "node-a", containerNames: ["grafana"], warningCount: 0, controlledBy: "Deployment/grafana", qosClass: "Burstable", age: .hours(3), cpuUsage: nil, memoryUsage: nil, diskUsage: nil, cpuUsageRatio: nil, memoryUsageRatio: nil, diskUsageRatio: nil)
            ],
            events: [
                EventSummary(id: UUID(), message: "Prometheus scraping succeeded", type: .normal, count: 6, age: .minutes(30), timestamp: Date().addingTimeInterval(-1_800))
            ],
            alerts: [],
            configResources: [
                ConfigResourceSummary(
                    id: UUID(),
                    name: "grafana-dashboards",
                    kind: .configMap,
                    typeDescription: "ConfigMap",
                    dataCount: 12,
                    summary: "JSON dashboards",
                    age: .hours(20)
                )
            ],
            isLoaded: true
        )

        let prodNodes: [NodeInfo] = [
            NodeInfo(
                id: UUID(),
                name: "node-a",
                warningCount: 0,
                cpuUsage: "1.2 cores",
                cpuUsageRatio: 0.24,
                memoryUsage: "6.1 GiB",
                memoryUsageRatio: 0.38,
                diskUsage: "420 GiB / 1.0 TiB (41%)",
                diskRatio: 0.41,
                networkReceiveBytes: 12_500_000_000,
                networkTransmitBytes: 9_800_000_000,
                taints: ["node-role.kubernetes.io/control-plane"],
                kubeletVersion: "v1.29.2",
                age: .days(120),
                conditions: [
                    NodeCondition(type: "Ready", status: "True", reason: nil, message: nil),
                    NodeCondition(type: "DiskPressure", status: "False", reason: nil, message: nil)
                ]
            ),
            NodeInfo(
                id: UUID(),
                name: "node-b",
                warningCount: 1,
                cpuUsage: "2.8 cores",
                cpuUsageRatio: 0.56,
                memoryUsage: "12.4 GiB",
                memoryUsageRatio: 0.62,
                diskUsage: "560 GiB / 960 GiB (58%)",
                diskRatio: 0.58,
                networkReceiveBytes: 8_200_000_000,
                networkTransmitBytes: 11_400_000_000,
                taints: [],
                kubeletVersion: "v1.29.2",
                age: .days(98),
                conditions: [
                    NodeCondition(type: "Ready", status: "True", reason: nil, message: nil),
                    NodeCondition(type: "MemoryPressure", status: "False", reason: nil, message: nil)
                ]
            )
        ]

        let devNodes: [NodeInfo] = [
            NodeInfo(
                id: UUID(),
                name: "dev-node-1",
                warningCount: 0,
                cpuUsage: "0.6 cores",
                cpuUsageRatio: 0.18,
                memoryUsage: "3.2 GiB",
                memoryUsageRatio: 0.41,
                diskUsage: "120 GiB / 340 GiB (35%)",
                diskRatio: 0.35,
                networkReceiveBytes: 3_100_000_000,
                networkTransmitBytes: 2_700_000_000,
                taints: [],
                kubeletVersion: "v1.28.6",
                age: .days(45),
                conditions: [NodeCondition(type: "Ready", status: "True", reason: nil, message: nil)]
            )
        ]

        let clusters = [
            Cluster(
                id: UUID(),
                name: "Prod Cluster",
                contextName: "prod-us-west-2",
                server: "https://prod.k8s.company.com",
                health: .degraded,
                kubernetesVersion: "1.29.2",
                nodeSummary: NodeSummary(total: 12, ready: 11, cpuUsage: 0.68, memoryUsage: 0.74, diskUsage: 0.57, networkReceiveBytes: nil, networkTransmitBytes: nil),
                nodes: prodNodes,
                namespaces: [prodNamespace, observabilityNamespace],
                lastSynced: now,
                notes: "Checkout service experiencing probe failures.",
                isConnected: true,
                helmReleases: [
                    HelmRelease(name: "checkout", namespace: "production", revision: 6, status: "deployed", chart: "checkout-1.8.4", appVersion: "4.2.0", updated: now.addingTimeInterval(-3_600)),
                    HelmRelease(name: "orders-db", namespace: "production", revision: 2, status: "deployed", chart: "postgresql-12.1.0", appVersion: "15.3", updated: now.addingTimeInterval(-50_000))
                ],
                customResources: [
                    CustomResourceDefinitionSummary(name: "prometheuses.monitoring.coreos.com", group: "monitoring.coreos.com", version: "v1", kind: "Prometheus", scope: "Namespaced", shortNames: ["prom"], age: .days(120)),
                    CustomResourceDefinitionSummary(name: "grafanas.integreatly.org", group: "integreatly.org", version: "v1beta1", kind: "Grafana", scope: "Namespaced", shortNames: ["gf"], age: .days(60))
                ]
            ),
            Cluster(
                id: UUID(),
                name: "Dev Cluster",
                contextName: "dev-us-west-2",
                server: "https://dev.k8s.company.com",
                health: .healthy,
                kubernetesVersion: "1.28.6",
                nodeSummary: NodeSummary(total: 5, ready: 5, cpuUsage: 0.41, memoryUsage: 0.35, diskUsage: 0.31, networkReceiveBytes: nil, networkTransmitBytes: nil),
                nodes: devNodes,
                namespaces: [devNamespace],
                lastSynced: now,
                notes: "Feature branches deploy here.",
                isConnected: true,
                helmReleases: [
                    HelmRelease(name: "dev-api", namespace: "development", revision: 9, status: "deployed", chart: "api-0.7.1", appVersion: "0.7.1", updated: now.addingTimeInterval(-1_800)),
                    HelmRelease(name: "feature-x", namespace: "development", revision: 1, status: "pending", chart: "feature-x-0.1.0", appVersion: "0.1.0", updated: nil)
                ],
                customResources: [
                    CustomResourceDefinitionSummary(name: "experiments.iter8.tools", group: "iter8.tools", version: "v1alpha2", kind: "Experiment", scope: "Namespaced", shortNames: ["exp"], age: .days(20))
                ]
            )
        ]

        return clusters
    }()

    func loadClusters() async throws -> [Cluster] {
        try await Task.sleep(nanoseconds: 250_000_000)
        return Self.sampleClusters.map { cluster in
            var summary = cluster
            summary.isConnected = false
            summary.namespaces = summary.namespaces.map { namespace in
                var copy = namespace
                copy.isLoaded = false
                copy.workloads = []
                copy.pods = []
                copy.events = []
                copy.configResources = []
                return copy
            }
            summary.nodeSummary = NodeSummary(total: cluster.nodeSummary.total, ready: cluster.nodeSummary.ready, cpuUsage: nil, memoryUsage: nil, diskUsage: nil, networkReceiveBytes: nil, networkTransmitBytes: nil)
            summary.nodes = []
            summary.notes = nil
            return summary
        }
    }

    func loadClusterDetails(contextName: String, focusNamespace: String?) async throws -> Cluster {
        try await Task.sleep(nanoseconds: 150_000_000)
        guard let cluster = Self.sampleClusters.first(where: { $0.contextName == contextName }) else {
            throw KubectlError(message: "Cluster not found in mock data", output: nil)
        }
        return cluster
    }

    func loadNamespaceDetails(contextName: String, namespace: String) async throws -> Namespace {
        try await Task.sleep(nanoseconds: 100_000_000)
        guard let cluster = Self.sampleClusters.first(where: { $0.contextName == contextName }),
              let namespace = cluster.namespaces.first(where: { $0.name == namespace }) else {
            throw KubectlError(message: "Namespace not found in mock data", output: nil)
        }
        return namespace
    }

    func loadPodDetail(contextName: String, namespace: String, pod: String) async throws -> PodDetailData {
        try await Task.sleep(nanoseconds: 80_000_000)
        guard let cluster = Self.sampleClusters.first(where: { $0.contextName == contextName }),
              let namespaceModel = cluster.namespaces.first(where: { $0.name == namespace }),
              let podSummary = namespaceModel.pods.first(where: { $0.name == pod }) else {
            throw KubectlError(message: "Pod not found in mock data", output: nil)
        }

        return PodDetailData(
            name: podSummary.name,
            namespace: namespace,
            createdAt: Date().addingTimeInterval(-3_600),
            labels: ["app": "mock"],
            annotations: ["example": "annotation"],
            controlledBy: podSummary.controlledBy,
            status: podSummary.phase.displayName,
            nodeName: podSummary.nodeName,
            podIP: "10.0.0.10",
            podIPs: ["10.0.0.10"],
            serviceAccount: "default",
            qosClass: podSummary.qosClass,
            conditions: [PodCondition(type: "Ready", status: "True", reason: nil, message: nil)],
            tolerations: [],
            volumes: [PodVolume(name: "config", type: "ConfigMap", detail: nil)],
            initContainers: [],
            containers: [
                ContainerDetail(
                    name: podSummary.primaryContainer ?? "container",
                    image: "example.com/mock-image:latest",
                    status: .running,
                    ready: true,
                    ports: ["80/TCP"],
                    envCount: 3,
                    mountCount: 1,
                    args: [],
                    command: [],
                    requests: [:],
                    limits: [:],
                    livenessProbe: nil,
                    readinessProbe: nil,
                    startupProbe: nil
                )
            ]
        )
    }

    func loadResourceYAML(contextName: String, namespace: String?, resourceType: String, name: String) async throws -> String {
        _ = contextName
        let namespaceLine = namespace.map { "  namespace: \($0)\n" } ?? ""
        return """
        apiVersion: v1
        kind: \(resourceType.capitalized)
        metadata:
          name: \(name)
        \(namespaceLine)spec: {}
        """
    }

    func updateSecret(
        contextName: String,
        namespace: String,
        name: String,
        type: String?,
        encodedData: [String: String]
    ) async throws -> String {
        _ = (contextName, namespace, name, type, encodedData)
        return "mock apply"
    }

    func applyResourceYAML(contextName: String, manifestYAML: String) async throws -> String {
        _ = (contextName, manifestYAML)
        return "mock apply"
    }
}

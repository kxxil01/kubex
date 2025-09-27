import Foundation
import SwiftUI

struct Cluster: Identifiable, Hashable {
    let id: UUID
    var name: String
    var contextName: String
    var server: String
    var health: ClusterHealth
    var kubernetesVersion: String
    var nodeSummary: NodeSummary
    var nodes: [NodeInfo] = []
    var namespaces: [Namespace]
    var lastSynced: Date
    var notes: String?
    var isConnected: Bool
    var helmReleases: [HelmRelease] = []
    var customResources: [CustomResourceDefinitionSummary] = []

    var unhealthyWorkloadCount: Int {
        namespaces.reduce(0) { partialResult, namespace in
            partialResult + namespace.workloads.filter { $0.status != .healthy }.count
        }
    }
}

struct NodeSummary: Hashable {
    var total: Int
    var ready: Int
    var cpuUsage: Double?
    var memoryUsage: Double?
    var diskUsage: Double?
    var networkReceiveBytes: Double?
    var networkTransmitBytes: Double?

    var readyPercentage: Double {
        guard total > 0 else { return 0 }
        return Double(ready) / Double(total)
    }
}

struct NodeInfo: Identifiable, Hashable {
    let id: UUID
    var name: String
    var warningCount: Int
    var cpuUsage: String?
    var cpuUsageRatio: Double?
    var memoryUsage: String?
    var memoryUsageRatio: Double?
    var diskUsage: String?
    var diskRatio: Double?
    var networkReceiveBytes: Double?
    var networkTransmitBytes: Double?
    var taints: [String]
    var kubeletVersion: String
    var age: EventAge?
    var conditions: [NodeCondition]

    var taintSummary: String {
        taints.isEmpty ? "—" : taints.joined(separator: "\n")
    }

    var conditionSummary: String {
        conditions.isEmpty ? "—" : conditions.map { "\($0.type): \($0.status)" }.joined(separator: "\n")
    }

    var cpuDisplay: String { cpuUsage ?? "—" }
    var memoryDisplay: String { memoryUsage ?? "—" }
    var diskDisplay: String { diskUsage ?? "—" }
}

struct MetricPoint: Identifiable, Equatable, Hashable {
    let id: UUID
    let timestamp: Date
    let value: Double

    init(id: UUID = UUID(), timestamp: Date, value: Double) {
        self.id = id
        self.timestamp = timestamp
        self.value = value
    }
}

struct MetricSeries: Equatable, Hashable {
    var points: [MetricPoint]

    var latest: Double? { points.last?.value }

    static let empty = MetricSeries(points: [])
}

struct WorkloadRolloutSeries: Equatable, Hashable {
    var ready: [MetricPoint] = []
    var updated: [MetricPoint] = []
    var available: [MetricPoint] = []

    var hasSamples: Bool {
        !ready.isEmpty || !updated.isEmpty || !available.isEmpty
    }
}

struct HeatmapEntry: Identifiable, Equatable, Hashable {
    let key: String
    var label: String
    var cpuRatio: Double?
    var memoryRatio: Double?

    var id: String { key }
}

struct ClusterOverviewMetrics: Equatable, Hashable {
    var timestamp: Date
    var cpu: MetricSeries
    var memory: MetricSeries
    var disk: MetricSeries
    var network: MetricSeries
    var nodeHeatmap: [HeatmapEntry]
    var podHeatmap: [HeatmapEntry]

    var hasSamples: Bool {
        !cpu.points.isEmpty || !memory.points.isEmpty || !disk.points.isEmpty || !network.points.isEmpty
    }

    static let empty = ClusterOverviewMetrics(
        timestamp: Date.distantPast,
        cpu: .empty,
        memory: .empty,
        disk: .empty,
        network: .empty,
        nodeHeatmap: [],
        podHeatmap: []
    )
}

struct NodeCondition: Hashable {
    var type: String
    var status: String
    var reason: String?
    var message: String?
}

enum ClusterHealth: String, CaseIterable, Hashable {
    case healthy
    case degraded
    case unreachable

    var displayName: String {
        rawValue.capitalized
    }

    var tint: Color {
        switch self {
        case .healthy: return .green
        case .degraded: return .orange
        case .unreachable: return .red
        }
    }

    var systemImage: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .degraded: return "exclamationmark.circle.fill"
        case .unreachable: return "xmark.octagon.fill"
        }
    }
}

struct Namespace: Identifiable, Hashable {
    let id: UUID
    var name: String
    var workloads: [WorkloadSummary]
    var pods: [PodSummary]
    var events: [EventSummary]
    var alerts: [String]
    var configResources: [ConfigResourceSummary] = []
    var services: [ServiceSummary] = []
    var ingresses: [IngressSummary] = []
    var persistentVolumeClaims: [PersistentVolumeClaimSummary] = []
    var serviceAccounts: [ServiceAccountSummary] = []
    var roles: [RoleSummary] = []
    var roleBindings: [RoleBindingSummary] = []
    var isLoaded: Bool

    var alertCount: Int { alerts.count }

    var summaryLine: String? {
        guard !workloads.isEmpty else { return nil }
        let deployments = workloads.filter { $0.kind == .deployment }.count
        let statefulSets = workloads.filter { $0.kind == .statefulSet }.count
        let daemonSets = workloads.filter { $0.kind == .daemonSet }.count
        let cronJobs = workloads.filter { $0.kind == .cronJob }.count
        let parts: [String] = [
            deployments > 0 ? "\(deployments) Deployments" : nil,
            statefulSets > 0 ? "\(statefulSets) StatefulSets" : nil,
            daemonSets > 0 ? "\(daemonSets) DaemonSets" : nil,
            cronJobs > 0 ? "\(cronJobs) CronJobs" : nil
        ].compactMap { $0 }
        return parts.joined(separator: " · ")
    }
}

enum ConfigResourceKind: String, CaseIterable, Codable, Hashable {
    case configMap
    case secret
    case resourceQuota
    case limitRange

    var displayName: String {
        switch self {
        case .configMap: return "ConfigMap"
        case .secret: return "Secret"
        case .resourceQuota: return "ResourceQuota"
        case .limitRange: return "LimitRange"
        }
    }

    var systemImage: String {
        switch self {
        case .configMap: return "doc.text"
        case .secret: return "lock"
        case .resourceQuota: return "square.grid.2x2"
        case .limitRange: return "speedometer"
        }
    }

    var pluralDisplayName: String {
        switch self {
        case .configMap: return "ConfigMaps"
        case .secret: return "Secrets"
        case .resourceQuota: return "Resource Quotas"
        case .limitRange: return "Limit Ranges"
        }
    }
}

struct ConfigResourceSummary: Identifiable, Hashable {
    let id: UUID
    var name: String
    var kind: ConfigResourceKind
    var typeDescription: String?
    var dataCount: Int?
    var summary: String?
    var age: EventAge?
    var secretEntries: [SecretDataEntry]? = nil
    var permissions: ConfigResourcePermissions = .fullAccess
}

struct ConfigResourcePermissions: Hashable {
    var canReveal: Bool
    var canEdit: Bool

    static let fullAccess = ConfigResourcePermissions(canReveal: true, canEdit: true)
}

struct SecretDataEntry: Identifiable, Hashable {
    let id = UUID()
    var key: String
    var encodedValue: String
}

struct SecretEntryEditor: Identifiable, Hashable {
    enum EditingMode: Hashable {
        case base64
        case plaintext
    }

    let id = UUID()
    let key: String
    private let originalEncodedValue: String
    private(set) var encodedValue: String
    private var decodedStorage: String?
    private(set) var canDecode: Bool
    private(set) var editingMode: EditingMode = .base64

    init(entry: SecretDataEntry) {
        self.key = entry.key
        self.originalEncodedValue = entry.encodedValue
        self.encodedValue = entry.encodedValue
        if let data = Data(base64Encoded: entry.encodedValue),
           let string = String(data: data, encoding: .utf8) {
            self.decodedStorage = string
            self.canDecode = true
        } else {
            self.decodedStorage = nil
            self.canDecode = false
        }
    }

    var isDecodedVisible: Bool { editingMode == .plaintext }

    var decodedValue: String {
        get { decodedStorage ?? "" }
        set {
            decodedStorage = newValue
            if let data = newValue.data(using: .utf8) {
                encodedValue = data.base64EncodedString()
                canDecode = true
            }
        }
    }

    var encodedDisplay: String { encodedValue }

    var base64EditorValue: String {
        get { encodedValue }
        set { updateEncodedValue(newValue) }
    }

    mutating func toggleVisibility() {
        guard canDecode else { return }
        switch editingMode {
        case .base64:
            if decodedStorage == nil {
                if let data = Data(base64Encoded: encodedValue),
                   let string = String(data: data, encoding: .utf8) {
                    decodedStorage = string
                } else {
                    decodedStorage = ""
                }
            }
            editingMode = .plaintext
        case .plaintext:
            if let data = decodedValue.data(using: .utf8) {
                encodedValue = data.base64EncodedString()
            }
            editingMode = .base64
        }
    }

    func encodedValueForSave() -> String {
        return encodedValue
    }

    mutating func updateEncodedValue(_ value: String) {
        encodedValue = value
        if let data = Data(base64Encoded: value),
           let string = String(data: data, encoding: .utf8) {
            decodedStorage = string
            canDecode = true
        } else {
            decodedStorage = nil
            canDecode = false
            editingMode = .base64
        }
    }

    var hasChanges: Bool {
        encodedValue != originalEncodedValue
    }

    var isBinary: Bool { !canDecode }

    var originalValueForDisplay: String { originalEncodedValue }
}

struct SecretDiffSummary: Identifiable, Hashable {
    enum ChangeKind: String, Hashable {
        case added
        case removed
        case modified
    }

    let id = UUID()
    let key: String
    let kind: ChangeKind
    let previousBase64: String?
    let currentBase64: String?
    let previousPlaintext: String?
    let currentPlaintext: String?
    let isBinary: Bool

    static func compute(original: [SecretDataEntry]?, updated: [SecretEntryEditor]) -> [SecretDiffSummary] {
        let originalByKey = Dictionary(uniqueKeysWithValues: (original ?? []).map { ($0.key, $0.encodedValue) })
        let updatedByKey = Dictionary(uniqueKeysWithValues: updated.map { ($0.key, $0.encodedValueForSave()) })

        let keys = Set(originalByKey.keys).union(updatedByKey.keys).sorted()
        var diffs: [SecretDiffSummary] = []

        for key in keys {
            let previous = originalByKey[key]
            let current = updatedByKey[key]
            if previous == current { continue }

            let kind: ChangeKind
            if previous == nil {
                kind = .added
            } else if current == nil {
                kind = .removed
            } else {
                kind = .modified
            }

            let previousPlain = previous.flatMap(Self.decodeBase64Plaintext)
            let currentPlain = current.flatMap(Self.decodeBase64Plaintext)
            let isBinary = ((previous != nil && previousPlain == nil) || (current != nil && currentPlain == nil))

            diffs.append(
                SecretDiffSummary(
                    key: key,
                    kind: kind,
                    previousBase64: previous,
                    currentBase64: current,
                    previousPlaintext: previousPlain,
                    currentPlaintext: currentPlain,
                    isBinary: isBinary
                )
            )
        }
        return diffs
    }

    private static func decodeBase64Plaintext(_ value: String) -> String? {
        guard let data = Data(base64Encoded: value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

struct HelmRelease: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var namespace: String
    var revision: Int
    var status: String
    var chart: String
    var appVersion: String?
    var updated: Date?

    var statusColor: Color {
        switch status.lowercased() {
        case "deployed", "superseded": return .green
        case "pending", "pending-install", "pending-upgrade": return .blue
        case "failed": return .red
        default: return .secondary
        }
    }

    var updatedDisplay: String {
        guard let updated else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: updated, relativeTo: Date())
    }
}

struct CustomResourceDefinitionSummary: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var group: String
    var version: String
    var kind: String
    var scope: String
    var shortNames: [String]
    var age: EventAge?
}

struct ServiceSummary: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var type: String
    var clusterIP: String
    var ports: String
    var age: EventAge?
    var selector: [String: String] = [:]
    var targetPods: [String] = []
    var endpointCount: Int = 0
    var latencyP50: TimeInterval?
    var latencyP95: TimeInterval?
}

struct IngressSummary: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var className: String?
    var hostRules: String
    var serviceTargets: String
    var tls: Bool
    var age: EventAge?
}

struct PersistentVolumeClaimSummary: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var status: String
    var capacity: String?
    var storageClass: String?
    var volumeName: String?
    var age: EventAge?
}

struct ServiceAccountSummary: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var secretCount: Int
    var age: EventAge?
}

struct RoleSummary: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var ruleCount: Int
    var age: EventAge?
}

struct RoleBindingSummary: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var subjectCount: Int
    var roleRef: String
    var age: EventAge?
}

struct WorkloadSummary: Identifiable, Hashable {
    let id: UUID
    var name: String
    var kind: WorkloadKind
    var replicas: Int
    var readyReplicas: Int
    var status: WorkloadStatus
    var updatedReplicas: Int? = nil
    var availableReplicas: Int? = nil
    var age: EventAge? = nil
    var activeCount: Int? = nil
    var succeededCount: Int? = nil
    var failedCount: Int? = nil
    var schedule: String? = nil
    var isSuspended: Bool? = nil

    var desiredDisplay: String {
        NumberFormatter.workloadNumber.string(from: NSNumber(value: replicas)) ?? "\(replicas)"
    }

    var readyDisplay: String {
        "\(readyReplicas)/\(replicas)"
    }

    var updatedDisplay: String {
        guard let value = updatedReplicas else { return "—" }
        return NumberFormatter.workloadNumber.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    var availableDisplay: String {
        guard let value = availableReplicas else { return "—" }
        return NumberFormatter.workloadNumber.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    var ageDisplay: String { age?.displayText ?? "—" }

    var activeDisplay: String {
        guard let value = activeCount else { return "—" }
        return NumberFormatter.workloadNumber.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    var succeededDisplay: String {
        guard let value = succeededCount else { return "—" }
        return NumberFormatter.workloadNumber.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    var failedDisplay: String {
        guard let value = failedCount else { return "—" }
        return NumberFormatter.workloadNumber.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    var scheduleDisplay: String { schedule ?? "—" }

    var suspensionDisplay: String {
        guard let isSuspended else { return "—" }
        return isSuspended ? "Paused" : "Active"
    }
}

enum WorkloadKind: String, CaseIterable, Codable, Hashable {
    case deployment
    case statefulSet
    case daemonSet
    case cronJob
    case replicaSet
    case replicationController
    case job

    var displayName: String {
        switch self {
        case .deployment: return "Deployment"
        case .statefulSet: return "StatefulSet"
        case .daemonSet: return "DaemonSet"
        case .cronJob: return "CronJob"
        case .replicaSet: return "ReplicaSet"
        case .replicationController: return "ReplicationController"
        case .job: return "Job"
        }
    }

    var systemImage: String {
        switch self {
        case .deployment: return "shippingbox.circle"
        case .statefulSet: return "cube.transparent"
        case .daemonSet: return "bolt.horizontal.circle"
        case .cronJob: return "clock"
        case .replicaSet: return "rectangle.grid.2x2"
        case .replicationController: return "wand.and.stars"
        case .job: return "briefcase"
        }
    }
}

extension WorkloadKind {
    var kubectlResourceName: String? {
        switch self {
        case .deployment: return "deployment"
        case .statefulSet: return "statefulset"
        case .daemonSet: return "daemonset"
        case .cronJob: return "cronjob"
        case .replicaSet: return "replicaset"
        case .replicationController: return "replicationcontroller"
        case .job: return "job"
        }
    }

    var supportsScaling: Bool {
        switch self {
        case .deployment, .statefulSet, .replicaSet, .replicationController:
            return true
        case .daemonSet, .cronJob, .job:
            return false
        }
    }

    var supportsEdit: Bool { true }
}

enum WorkloadStatus: String, CaseIterable, Codable, Hashable {
    case healthy
    case degraded
    case progressing
    case failed

    var displayName: String { rawValue.capitalized }

    var tint: Color {
        switch self {
        case .healthy: return .green
        case .degraded: return .orange
        case .progressing: return .blue
        case .failed: return .red
        }
    }
}

struct PodSummary: Identifiable, Hashable {
    let id: UUID
    var name: String
    var namespace: String
    var phase: PodPhase
    var readyContainers: Int
    var totalContainers: Int
    var restarts: Int
    var nodeName: String
    var containerNames: [String]
    var warningCount: Int
    var controlledBy: String?
    var qosClass: String?
    var age: EventAge?
    var cpuUsage: String?
    var memoryUsage: String?
    var diskUsage: String?
    var cpuUsageRatio: Double?
    var memoryUsageRatio: Double?
    var diskUsageRatio: Double?

    var primaryContainer: String? { containerNames.first }
    var containerSummary: String { containerNames.joined(separator: ", ") }
    var qosDisplay: String { qosClass ?? "—" }
    var ageDisplay: String { age?.displayText ?? "—" }
    var cpuDisplay: String { cpuUsage ?? "—" }
    var memoryDisplay: String { memoryUsage ?? "—" }
    var diskDisplay: String { diskUsage ?? "—" }
}

struct PodDetailData {
    var name: String
    var namespace: String
    var createdAt: Date?
    var labels: [String: String]
    var annotations: [String: String]
    var controlledBy: String?
    var status: String
    var nodeName: String
    var podIP: String?
    var podIPs: [String]
    var serviceAccount: String?
    var qosClass: String?
    var conditions: [PodCondition]
    var tolerations: [PodToleration]
    var volumes: [PodVolume]
    var initContainers: [ContainerDetail]
    var containers: [ContainerDetail]
}

struct PodCondition: Hashable {
    var type: String
    var status: String
    var reason: String?
    var message: String?
}

struct PodToleration: Hashable {
    var key: String?
    var `operator`: String?
    var value: String?
    var effect: String?
    var tolerationSeconds: Int?
}

struct PodVolume: Hashable {
    var name: String
    var type: String
    var detail: String?
}

struct ContainerDetail: Hashable {
    enum ContainerState: String, Hashable { case running, waiting, terminated, unknown }

    var name: String
    var image: String
    var status: ContainerState
    var ready: Bool
    var ports: [String]
    var envCount: Int
    var mountCount: Int
    var args: [String]
    var command: [String]
    var requests: [String: String]
    var limits: [String: String]
    var livenessProbe: ProbeDetail?
    var readinessProbe: ProbeDetail?
    var startupProbe: ProbeDetail?
}

struct ProbeDetail: Hashable {
    var type: String
    var detail: String
}

enum PodPhase: String, CaseIterable, Codable, Hashable {
    case running
    case pending
    case succeeded
    case failed
    case unknown

    var displayName: String { rawValue.capitalized }

    var tint: Color {
        switch self {
        case .running: return .green
        case .pending: return .blue
        case .succeeded: return .gray
        case .failed: return .red
        case .unknown: return .orange
        }
    }
}

struct EventSummary: Identifiable, Hashable {
    let id: UUID
    var message: String
    var type: EventType
    var count: Int
    var age: EventAge
    var timestamp: Date?
}

enum EventType: String, Codable, Hashable {
    case normal
    case warning
    case error

    var tint: Color {
        switch self {
        case .normal: return .gray
        case .warning: return .orange
        case .error: return .red
        }
    }

    var icon: String {
        switch self {
        case .normal: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        }
    }
}

enum EventAge: Hashable {
    case minutes(Int)
    case hours(Int)
    case days(Int)

    var displayText: String {
        switch self {
        case .minutes(let value): return "\(value)m"
        case .hours(let value): return "\(value)h"
        case .days(let value): return "\(value)d"
        }
    }

    var totalMinutes: Double {
        switch self {
        case .minutes(let value): return Double(value)
        case .hours(let value): return Double(value * 60)
        case .days(let value): return Double(value * 1_440)
        }
    }
}

extension EventAge {
    static func from(date: Date) -> EventAge {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: now)
        if let day = components.day, day > 0 { return .days(day) }
        if let hour = components.hour, hour > 0 { return .hours(hour) }
        let minutes = max(components.minute ?? 0, 0)
        return .minutes(minutes)
    }
}

extension NumberFormatter {
    static let workloadNumber: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = ""
        return formatter
    }()
}

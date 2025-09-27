import Foundation

struct LabelSelector: Hashable, Codable, Identifiable {
    var key: String
    var value: String?

    var id: String {
        if let value, !value.isEmpty {
            return "\(key)=\(value)"
        }
        return key
    }

    var displayName: String {
        if let value, !value.isEmpty {
            return "\(key)=\(value)"
        }
        return key
    }

    func matches(_ labels: [String: String]) -> Bool {
        guard !key.isEmpty else { return false }
        if let value, !value.isEmpty {
            return labels[key] == value
        }
        return labels.keys.contains(key)
    }
}

struct WorkloadFilterState: Equatable, Codable {
    var statuses: Set<WorkloadStatus> = []
    var labelSelectors: Set<LabelSelector> = []

    static let empty = WorkloadFilterState()

    func matches(_ workload: WorkloadSummary) -> Bool {
        let statusMatches = statuses.isEmpty || statuses.contains(workload.status)
        let labelMatches = labelSelectors.matches(labels: workload.labels)
        return statusMatches && labelMatches
    }

    var isEmpty: Bool { statuses.isEmpty && labelSelectors.isEmpty }
}

struct PodFilterState: Equatable, Codable {
    var phases: Set<PodPhase> = []
    var onlyWithWarnings: Bool = false
    var labelSelectors: Set<LabelSelector> = []

    static let empty = PodFilterState()

    func matches(_ pod: PodSummary) -> Bool {
        let phaseMatches = phases.isEmpty || phases.contains(pod.phase)
        let warningsMatch = !onlyWithWarnings || pod.warningCount > 0
        let labelMatches = labelSelectors.matches(labels: pod.labels)
        return phaseMatches && warningsMatch && labelMatches
    }

    var isEmpty: Bool { phases.isEmpty && !onlyWithWarnings && labelSelectors.isEmpty }
}

struct NodeFilterState: Equatable, Codable {
    var onlyReady: Bool = false
    var onlyWithWarnings: Bool = false
    var labelSelectors: Set<LabelSelector> = []

    static let empty = NodeFilterState()

    func matches(_ node: NodeInfo) -> Bool {
        let readyMatch: Bool
        if onlyReady {
            readyMatch = node.conditions.contains { $0.type == "Ready" && $0.status.lowercased() == "true" }
        } else {
            readyMatch = true
        }
        let warningsMatch = !onlyWithWarnings || node.warningCount > 0
        let labelMatches = labelSelectors.matches(labels: node.labels)
        return readyMatch && warningsMatch && labelMatches
    }

    var isEmpty: Bool { !onlyReady && !onlyWithWarnings && labelSelectors.isEmpty }
}

struct ConfigFilterState: Equatable, Codable {
    var kinds: Set<ConfigResourceKind> = []
    var labelSelectors: Set<LabelSelector> = []

    static let empty = ConfigFilterState()

    func matches(_ resource: ConfigResourceSummary) -> Bool {
        let kindMatches = kinds.isEmpty || kinds.contains(resource.kind)
        let labelMatches = labelSelectors.matches(labels: resource.labels)
        return kindMatches && labelMatches
    }

    var isEmpty: Bool { kinds.isEmpty && labelSelectors.isEmpty }
}

extension Set where Element == LabelSelector {
    func matches(labels: [String: String]) -> Bool {
        guard !isEmpty else { return true }
        for selector in self {
            if !selector.matches(labels) {
                return false
            }
        }
        return true
    }
}

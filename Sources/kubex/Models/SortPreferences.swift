import Foundation

enum SortDirection: String, CaseIterable, Codable {
    case ascending
    case descending

    mutating func toggle() {
        self = self == .ascending ? .descending : .ascending
    }

    var symbolName: String {
        switch self {
        case .ascending: return "arrow.up"
        case .descending: return "arrow.down"
        }
    }

    var shortGlyph: String {
        switch self {
        case .ascending: return "↑"
        case .descending: return "↓"
        }
    }

    var toggleLabel: String {
        switch self {
        case .ascending: return "Sort Descending"
        case .descending: return "Sort Ascending"
        }
    }
}

struct WorkloadSortOption: Equatable, Codable {
    var field: WorkloadSortField
    var direction: SortDirection

    mutating func toggleDirection() {
        direction.toggle()
    }

    var description: String {
        "\(field.title) \(direction.shortGlyph)"
    }

    static let `default` = WorkloadSortOption(field: .name, direction: .ascending)
}

enum WorkloadSortField: String, CaseIterable, Identifiable, Codable {
    case name
    case age
    case readiness

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: return "Name"
        case .age: return "Age"
        case .readiness: return "Ready"
        }
    }
}

struct NodeSortOption: Equatable, Codable {
    var field: NodeSortField
    var direction: SortDirection

    mutating func toggleDirection() {
        direction.toggle()
    }

    var description: String {
        "\(field.title) \(direction.shortGlyph)"
    }

    static let `default` = NodeSortOption(field: .name, direction: .ascending)
}

enum NodeSortField: String, CaseIterable, Identifiable, Codable {
    case name
    case warnings
    case cpu
    case memory
    case disk
    case age

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: return "Name"
        case .warnings: return "Warnings"
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .disk: return "Disk"
        case .age: return "Age"
        }
    }
}

extension WorkloadSortField {
    var sortDescriptor: (WorkloadSummary, WorkloadSummary) -> Bool {
        switch self {
        case .name:
            return { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        case .age:
            return { lhs, rhs in
                lhs.age.sortMinutes < rhs.age.sortMinutes
            }
        case .readiness:
            return { lhs, rhs in
                if lhs.readyReplicas == rhs.readyReplicas {
                    return lhs.replicas < rhs.replicas
                }
                return lhs.readyReplicas < rhs.readyReplicas
            }
        }
    }
}

extension NodeSortField {
    var sortDescriptor: (NodeInfo, NodeInfo) -> Bool {
        switch self {
        case .name:
            return { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        case .warnings:
            return { $0.warningCount < $1.warningCount }
        case .cpu:
            return { ($0.cpuUsageRatio ?? 0) < ($1.cpuUsageRatio ?? 0) }
        case .memory:
            return { ($0.memoryUsageRatio ?? 0) < ($1.memoryUsageRatio ?? 0) }
        case .disk:
            return { ($0.diskRatio ?? 0) < ($1.diskRatio ?? 0) }
        case .age:
            return { $0.age.sortMinutes < $1.age.sortMinutes }
        }
    }
}

private extension EventAge {
    var minutesValue: Double {
        switch self {
        case .minutes(let value): return Double(value)
        case .hours(let value): return Double(value * 60)
        case .days(let value): return Double(value * 1_440)
        }
    }
}

private extension Optional where Wrapped == EventAge {
    var sortMinutes: Double {
        switch self {
        case .some(let age): return age.minutesValue
        case .none: return .greatestFiniteMagnitude
        }
    }
}

import Foundation

struct LogStreamRequest: Hashable, Sendable {
    var clusterID: Cluster.ID
    var contextName: String
    var namespace: String
    var podName: String
    var containerName: String?
    var includeTimestamps: Bool = true
    var follow: Bool = true
}

enum LogStreamEvent: Equatable, Sendable {
    case line(String, Date)
    case truncated
}

protocol LogStreamingService: Sendable {
    func streamLogs(for request: LogStreamRequest) -> AsyncThrowingStream<LogStreamEvent, Error>
}

struct ExecSession: Identifiable, Hashable, Sendable {
    let id: UUID
    var clusterID: Cluster.ID
    var contextName: String
    var namespace: String
    var podName: String
    var containerName: String?
    var command: [String]
    var startedAt: Date
}

protocol ExecService: Sendable {
    func openShell(for session: ExecSession) async throws -> ExecSession
}

struct PortForwardRequest: Hashable, Sendable {
    var clusterID: Cluster.ID
    var contextName: String
    var namespace: String
    var podName: String
    var remotePort: Int
    var localPort: Int
}

struct ActivePortForward: Identifiable, Hashable, Sendable {
    let id: UUID
    var request: PortForwardRequest
    var startedAt: Date
    var status: PortForwardStatus
}

enum PortForwardStatus: Hashable, Sendable {
    case establishing
    case active
    case failed(String)
}

enum PortForwardLifecycleEvent: Sendable {
    case terminated(id: UUID, request: PortForwardRequest, error: KubectlError?)
}

protocol PortForwardService: Sendable {
    func startForward(
        _ request: PortForwardRequest,
        eventHandler: @escaping @Sendable (PortForwardLifecycleEvent) -> Void
    ) async throws -> ActivePortForward
    func stopForward(_ forward: ActivePortForward) async throws
}

extension PortForwardService {
    func startForward(_ request: PortForwardRequest) async throws -> ActivePortForward {
        try await startForward(request, eventHandler: { _ in })
    }
}

struct ResourceEditRequest: Hashable, Sendable {
    var contextName: String
    var namespace: String?
    var kind: String
    var name: String
}

protocol EditService: Sendable {
    func editResource(_ request: ResourceEditRequest) async throws
}

// MARK: - Mock Implementations

struct MockLogStreamingService: LogStreamingService {
    func streamLogs(for request: LogStreamRequest) -> AsyncThrowingStream<LogStreamEvent, Error> {
        let container = request.containerName ?? "container"
        let sampleLines = [
            "Connecting to pod \(request.podName)...",
            "Proxy established for container \(container)",
            "GET /healthz 200 15ms",
            "POST /api/checkout 500 120ms",
            "Retrying POST /api/checkout",
            "POST /api/checkout 204 87ms"
        ]

        return AsyncThrowingStream { continuation in
            Task {
                for (index, line) in sampleLines.enumerated() {
                    try await Task.sleep(nanoseconds: UInt64(200_000_000 * (index + 1)))
                    continuation.yield(.line(line, Date()))
                }
                continuation.finish()
            }
        }
    }
}

struct MockExecService: ExecService {
    func openShell(for session: ExecSession) async throws -> ExecSession {
        try await Task.sleep(nanoseconds: 150_000_000)
        return session
    }
}

actor MockPortForwardService: PortForwardService {
    private var handlers: [UUID: @Sendable (PortForwardLifecycleEvent) -> Void] = [:]

    func startForward(
        _ request: PortForwardRequest,
        eventHandler: @escaping @Sendable (PortForwardLifecycleEvent) -> Void
    ) async throws -> ActivePortForward {
        try await Task.sleep(nanoseconds: 150_000_000)
        let forward = ActivePortForward(
            id: UUID(),
            request: request,
            startedAt: Date(),
            status: .active
        )
        handlers[forward.id] = eventHandler
        return forward
    }

    func stopForward(_ forward: ActivePortForward) async throws {
        if let handler = handlers.removeValue(forKey: forward.id) {
            handler(.terminated(id: forward.id, request: forward.request, error: nil))
        }
    }
}

struct MockEditService: EditService {
    func editResource(_ request: ResourceEditRequest) async throws {
        _ = request
        try await Task.sleep(nanoseconds: 100_000_000)
    }
}

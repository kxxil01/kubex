import Foundation
import Testing
@testable import kubex

@MainActor
@Test("node stats cache reuse within TTL")
func nodeStatsCacheReuseWithinTTL() async throws {
    let runner = MockKubectlRunner()
    runner.registerJSON(
        arguments: ["--context", "test", "get", "nodes", "-o", "json", "--request-timeout=15s"],
        json: Fixtures.nodeListJSON
    )
    runner.registerJSON(
        arguments: ["--context", "test", "get", "--raw", "/apis/metrics.k8s.io/v1beta1/nodes"],
        json: Fixtures.nodeMetricsJSON
    )
    runner.registerJSON(
        arguments: ["--context", "test", "get", "--raw", "/api/v1/nodes/node-a/proxy/stats/summary"],
        json: Fixtures.nodeStatsJSON
    )

    let service = KubectlClusterService(runner: runner)

    _ = try await service._test_loadNodeData(contextName: "test")
    let firstCount = runner.callCount(for: ["--context", "test", "get", "--raw", "/api/v1/nodes/node-a/proxy/stats/summary"])
    #expect(firstCount == 1)

    _ = try await service._test_loadNodeData(contextName: "test")
    let secondCount = runner.callCount(for: ["--context", "test", "get", "--raw", "/api/v1/nodes/node-a/proxy/stats/summary"])
    #expect(secondCount == 1)
}

@MainActor
@Test("pod disk usage includes filesystem stats")
func podDiskUsageIncludesFilesystemStats() async throws {
    let runner = MockKubectlRunner()
    runner.registerJSON(
        arguments: ["-n", "default", "--context", "test", "get", "pods", "-o", "json", "--request-timeout=20s"],
        json: Fixtures.podListJSON
    )
    runner.registerJSON(
        arguments: ["--context", "test", "get", "--raw", "/apis/metrics.k8s.io/v1beta1/namespaces/default/pods"],
        json: Fixtures.podMetricsJSON
    )
    runner.registerJSON(
        arguments: ["--context", "test", "get", "nodes", "-o", "json", "--request-timeout=15s"],
        json: Fixtures.nodeListJSON
    )
    runner.registerJSON(
        arguments: ["--context", "test", "get", "--raw", "/apis/metrics.k8s.io/v1beta1/nodes"],
        json: Fixtures.nodeMetricsJSON
    )
    runner.registerJSON(
        arguments: ["--context", "test", "get", "--raw", "/api/v1/nodes/node-a/proxy/stats/summary"],
        json: Fixtures.podStatsJSON
    )

    let service = KubectlClusterService(runner: runner)
    let pods = try await service._test_loadPods(contextName: "test", namespace: "default")
    guard let pod = pods.first else {
        Issue.record("Expected pod data")
        return
    }
    #expect(pod.diskUsage != nil)
    if let disk = pod.diskUsage {
        #expect(disk.contains("50"))
    }
    #expect(pod.cpuUsage != nil)
    if let cpu = pod.cpuUsage {
        #expect(cpu.contains("of limit"))
    }
}

@MainActor
@Test("secret permission cache reuses auth checks")
func secretPermissionCacheReusesAuthChecks() async {
    let runner = MockKubectlRunner()
    let contextName = "test"
    let namespace = "default"
    let secretNames = ["alpha", "beta"]

    for name in secretNames {
        runner.register(
            arguments: ["auth", "can-i", "get", "secret/\(name)", "--namespace", namespace, "--context", contextName],
            response: "yes"
        )
        runner.register(
            arguments: ["auth", "can-i", "update", "secret/\(name)", "--namespace", namespace, "--context", contextName],
            response: "yes"
        )
    }

    let service = KubectlClusterService(runner: runner)

    let first = await service._test_fetchSecretPermissions(contextName: contextName, namespace: namespace, names: secretNames)
    #expect(first.count == secretNames.count)
    #expect(first["alpha"]?.canReveal == true)
    #expect(first["beta"]?.canEdit == true)

    let getAlphaArgs = ["auth", "can-i", "get", "secret/alpha", "--namespace", namespace, "--context", contextName]
    let updateAlphaArgs = ["auth", "can-i", "update", "secret/alpha", "--namespace", namespace, "--context", contextName]
    let getBetaArgs = ["auth", "can-i", "get", "secret/beta", "--namespace", namespace, "--context", contextName]
    let updateBetaArgs = ["auth", "can-i", "update", "secret/beta", "--namespace", namespace, "--context", contextName]

    let initialGetAlpha = runner.callCount(for: getAlphaArgs)
    let initialUpdateAlpha = runner.callCount(for: updateAlphaArgs)
    let initialGetBeta = runner.callCount(for: getBetaArgs)
    let initialUpdateBeta = runner.callCount(for: updateBetaArgs)

    let second = await service._test_fetchSecretPermissions(contextName: contextName, namespace: namespace, names: secretNames)
    #expect(second == first)

    #expect(runner.callCount(for: getAlphaArgs) == initialGetAlpha)
    #expect(runner.callCount(for: updateAlphaArgs) == initialUpdateAlpha)
    #expect(runner.callCount(for: getBetaArgs) == initialGetBeta)
    #expect(runner.callCount(for: updateBetaArgs) == initialUpdateBeta)
}

// MARK: - Fixtures

private enum Fixtures {
    static let nodeListJSON = """
    {
      "items": [
        {
          "metadata": {
            "name": "node-a",
            "uid": "node-a"
          },
          "status": {
            "capacity": {
              "cpu": "8",
              "memory": "32Gi"
            },
            "conditions": [
              { "type": "Ready", "status": "True" },
              { "type": "MemoryPressure", "status": "False" }
            ]
          }
        }
      ]
    }
    """

    static let nodeMetricsJSON = """
    {
      "items": [
        {
          "metadata": { "name": "node-a" },
          "usage": { "cpu": "300m", "memory": "5120Mi" }
        }
      ]
    }
    """

    static let nodeStatsJSON = """
    {
      "node": {
        "runtime": {
          "imageFs": {
            "usedBytes": 536870912,
            "capacityBytes": 2147483648
          }
        }
      }
    }
    """

    static let podListJSON = """
    {
      "items": [
        {
          "metadata": {
            "name": "test-pod",
            "namespace": "default",
            "uid": "test-pod"
          },
          "spec": {
            "nodeName": "node-a",
            "containers": [
              {
                "name": "app",
                "resources": {
                  "limits": {
                    "cpu": "1",
                    "memory": "512Mi",
                    "ephemeral-storage": "300Mi"
                  }
                }
              }
            ]
          },
          "status": {
            "phase": "Running",
            "containerStatuses": [
              {
                "name": "app",
                "ready": true,
                "restartCount": 0
              }
            ],
            "conditions": [
              { "type": "Ready", "status": "True" }
            ]
          }
        }
      ]
    }
    """

    static let podMetricsJSON = """
    {
      "items": [
        {
          "metadata": { "name": "test-pod", "namespace": "default" },
          "containers": [
            {
              "name": "app",
              "usage": { "cpu": "250m", "memory": "128Mi" }
            }
          ]
        }
      ]
    }
    """

    static let podStatsJSON = """
    {
      "node": {
        "fs": {
          "usedBytes": 536870912,
          "capacityBytes": 1073741824
        }
      },
      "pods": [
        {
          "podRef": { "name": "test-pod", "namespace": "default" },
          "containers": [
            {
              "name": "app",
              "rootfs": { "usedBytes": 104857600, "capacityBytes": 209715200 },
              "logs": { "usedBytes": 0, "capacityBytes": 209715200 }
            }
          ],
          "volumeStats": [
            { "name": "data", "usedBytes": 52428800, "capacityBytes": 209715200 }
          ]
        }
      ]
    }
    """
}

// MARK: - Mocks

final class MockKubectlRunner: KubectlExecuting, @unchecked Sendable {
    private var responses: [String: String] = [:]
    private var callCounts: [String: Int] = [:]
    private let lock = NSLock()

    func registerJSON(arguments: [String], json: String) {
        lock.withLock {
            responses[key(for: arguments)] = json
        }
    }

    func register(arguments: [String], response: String) {
        lock.withLock {
            responses[key(for: arguments)] = response
        }
    }

    func run(arguments: [String], kubeconfigPath: String?, configuration overrideConfiguration: KubectlRunner.Configuration?) async throws -> String {
        let key = key(for: arguments)
        let response = lock.withLock { () -> String? in
            callCounts[key, default: 0] += 1
            return responses[key]
        }
        if let response {
            return response
        }
        throw KubectlError(message: "No stubbed response for \(key)", output: nil)
    }

    func runJSON<T>(
        arguments: [String],
        kubeconfigPath: String?,
        decoder: JSONDecoder,
        configuration overrideConfiguration: KubectlRunner.Configuration?
    ) async throws -> T where T : Decodable {
        let response = try await run(arguments: arguments, kubeconfigPath: kubeconfigPath, configuration: overrideConfiguration)
        let data = Data(response.utf8)
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    func callCount(for arguments: [String]) -> Int {
        lock.withLock {
            callCounts[key(for: arguments), default: 0]
        }
    }

    private func key(for arguments: [String]) -> String {
        arguments.joined(separator: " ")
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}

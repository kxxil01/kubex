import Foundation
import Testing
@testable import kubex

@MainActor
private func makeModel() -> AppModel {
    AppModel(
        clusterService: MockClusterService(),
        logService: MockLogStreamingService(),
        execService: MockExecService(),
        portForwardService: MockPortForwardService(),
        editService: MockEditService(),
        helmService: MockHelmService(releases: []),
        telemetryService: NoopTelemetryService()
    )
}

@MainActor
@Test("applyPodYAML succeeds and surfaces success message")
func applyPodYAMLSuccess() async {
    let model = makeModel()
    guard let cluster = MockClusterService.sampleClusters.first,
          let namespace = cluster.namespaces.first,
          let pod = namespace.pods.first else {
        Issue.record("Mock cluster data unavailable")
        return
    }

    let yaml = "apiVersion: v1\nkind: Pod\nmetadata:\n  name: \(pod.name)"
    let result = await model.applyPodYAML(cluster: cluster, namespace: namespace, pod: pod, yaml: yaml)

    switch result {
    case .success(let output):
        #expect(output == "mock apply")
    case .failure(let error):
        Issue.record("Unexpected failure: \(error.message)")
    }

    #expect(model.banner?.text == "Pod \(pod.name) updated")
}

@MainActor
@Test("applyPodYAML rejects empty manifests")
func applyPodYAMLEmpty() async {
    let model = makeModel()
    guard let cluster = MockClusterService.sampleClusters.first,
          let namespace = cluster.namespaces.first,
          let pod = namespace.pods.first else {
        Issue.record("Mock cluster data unavailable")
        return
    }

    let result = await model.applyPodYAML(cluster: cluster, namespace: namespace, pod: pod, yaml: "   \n")
    switch result {
    case .success:
        Issue.record("Expected failure for empty manifest")
    case .failure(let error):
        #expect(error.message.contains("Manifest is empty"))
    }

    #expect(model.banner == nil)
}

@MainActor
@Test("applyPodYAML fails when cluster disconnected")
func applyPodYAMLDisconnected() async {
    let model = makeModel()
    guard var cluster = MockClusterService.sampleClusters.first,
          let namespace = cluster.namespaces.first,
          let pod = namespace.pods.first else {
        Issue.record("Mock cluster data unavailable")
        return
    }
    cluster.isConnected = false

    let result = await model.applyPodYAML(cluster: cluster, namespace: namespace, pod: pod, yaml: "metadata: {}")
    switch result {
    case .success:
        Issue.record("Expected failure for disconnected cluster")
    case .failure(let error):
        #expect(error.message.contains("Connect to the cluster before applying manifests"))
    }

    #expect(model.banner == nil)
}

@MainActor
@Test("applyWorkloadYAML surfaces success and banner")
func applyWorkloadYAMLSuccess() async {
    let model = makeModel()
    guard let cluster = MockClusterService.sampleClusters.first,
          let namespace = cluster.namespaces.first,
          let workload = namespace.workloads.first else {
        Issue.record("Mock workload data unavailable")
        return
    }

    let yaml = "apiVersion: apps/v1\nkind: Deployment\nmetadata:\n  name: \(workload.name)"
    let result = await model.applyWorkloadYAML(cluster: cluster, namespace: namespace, workload: workload, yaml: yaml)

    switch result {
    case .success(let output):
        #expect(output == "mock apply")
    case .failure(let error):
        Issue.record("Unexpected failure: \(error.message)")
    }

    #expect(model.banner?.text == "Applied changes to \(workload.name)")
}

@MainActor
@Test("executePodCommand returns failure for disconnected cluster")
func executePodCommandDisconnected() async {
    let model = makeModel()
    guard var cluster = MockClusterService.sampleClusters.first,
          let namespace = cluster.namespaces.first,
          let pod = namespace.pods.first else {
        Issue.record("Mock pod data unavailable")
        return
    }
    cluster.isConnected = false

    let result = await model.executePodCommand(cluster: cluster, namespace: namespace, pod: pod, container: pod.primaryContainer, command: "env")
    switch result {
    case .success:
        Issue.record("Expected failure for disconnected cluster")
    case .failure(let error):
        #expect(error.message.contains("Connect to the cluster before running exec commands"))
    }
}

@MainActor
@Test("executePodCommand rejects empty command strings")
func executePodCommandEmpty() async {
    let model = makeModel()
    guard let cluster = MockClusterService.sampleClusters.first,
          let namespace = cluster.namespaces.first,
          let pod = namespace.pods.first else {
        Issue.record("Mock pod data unavailable")
        return
    }

    let result = await model.executePodCommand(cluster: cluster, namespace: namespace, pod: pod, container: pod.primaryContainer, command: "   ")
    switch result {
    case .success:
        Issue.record("Expected failure for empty command")
    case .failure(let error):
        #expect(error.message == "Enter a command to execute.")
    }
}

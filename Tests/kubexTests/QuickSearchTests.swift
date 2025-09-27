import Foundation
import Testing
@testable import kubex

@MainActor
private func prepareQuickSearchModel(clusterIndex: Int = 0) async -> AppModel? {
    let defaults = UserDefaults.standard
    [
        "kubex.sort.workloads",
        "kubex.sort.nodes",
        "kubex.filter.workloads",
        "kubex.filter.pods",
        "kubex.filter.nodes",
        "kubex.filter.config"
    ].forEach { defaults.removeObject(forKey: $0) }

    let model = AppModel(
        clusterService: MockClusterService(),
        logService: MockLogStreamingService(),
        execService: MockExecService(),
        portForwardService: MockPortForwardService(),
        editService: MockEditService(),
        helmService: MockHelmService(releases: MockClusterService.sampleClusters.flatMap { $0.helmReleases })
    )

    await model.refreshClusters()
    guard !model.clusters.isEmpty else {
        Issue.record("Mock clusters failed to load")
        return nil
    }

    if model.clusters.indices.contains(clusterIndex) {
        model.selectedClusterID = model.clusters[clusterIndex].id
    }

    await model.connectSelectedCluster()
    return model
}

@MainActor
@Test("Quick search returns checkout deployment in production")
func quickSearchFindsCheckoutDeployment() async {
    guard let model = await prepareQuickSearchModel(clusterIndex: 0),
          let cluster = model.selectedCluster,
          let production = cluster.namespaces.first(where: { $0.name == "production" }) else {
        return
    }

    model.presentQuickSearch()
    model.quickSearchNamespaceFilter = AppModel.allNamespacesNamespaceID
    model.quickSearchQuery = "checkout"

    let results = model.quickSearchResults
    #expect(!results.isEmpty)

    guard let deploymentResult = results.first(where: { result in
        if case let .workload(kind, namespaceID, _) = result.target {
            return kind == .deployment && namespaceID == production.id
        }
        return false
    }) else {
        Issue.record("Expected checkout deployment in quick search results")
        return
    }

    #expect(deploymentResult.title.lowercased().contains("checkout"))
    #expect(deploymentResult.category == WorkloadKind.deployment.displayName)
}

@MainActor
@Test("Namespace filter restricts quick search scope")
func quickSearchRespectsNamespaceFilter() async {
    guard let model = await prepareQuickSearchModel(clusterIndex: 1),
          let cluster = model.selectedCluster,
          let development = cluster.namespaces.first(where: { $0.name == "development" }) else {
        return
    }

    model.presentQuickSearch()
    model.quickSearchNamespaceFilter = development.id

    model.quickSearchQuery = "checkout"
    #expect(model.quickSearchResults.isEmpty)

    model.quickSearchQuery = "api"
    let results = model.quickSearchResults
    #expect(!results.isEmpty)

    for result in results {
        switch result.target {
        case let .namespace(namespaceID):
            #expect(namespaceID == development.id)
        case let .workload(_, namespaceID, _):
            #expect(namespaceID == development.id)
        case let .pod(namespaceID, _):
            #expect(namespaceID == development.id)
        case let .service(namespaceID, _):
            #expect(namespaceID == development.id)
        case let .ingress(namespaceID, _):
            #expect(namespaceID == development.id)
        case let .persistentVolumeClaim(namespaceID, _):
            #expect(namespaceID == development.id)
        case let .configResource(_, namespaceID, _):
            #expect(namespaceID == development.id)
        case let .helm(releaseID):
            let release = cluster.helmReleases.first(where: { $0.id == releaseID })
            #expect(release?.namespace == development.name)
        case .node:
            Issue.record("Node result should not appear for namespace-scoped search")
        case .tab:
            continue
        }
    }
}

@MainActor
@Test("Selecting a workload result updates model state")
func quickSearchSelectionUpdatesModel() async {
    guard let model = await prepareQuickSearchModel(clusterIndex: 0),
          let cluster = model.selectedCluster,
          let production = cluster.namespaces.first(where: { $0.name == "production" }) else {
        return
    }

    model.presentQuickSearch()
    model.quickSearchNamespaceFilter = AppModel.allNamespacesNamespaceID
    model.quickSearchQuery = "checkout"

    guard let workloadResult = model.quickSearchResults.first(where: { result in
        if case let .workload(kind, namespaceID, _) = result.target {
            return kind == .deployment && namespaceID == production.id
        }
        return false
    }) else {
        Issue.record("Expected checkout deployment result for selection test")
        return
    }

    model.handleQuickSearchSelection(workloadResult)

    #expect(!model.isQuickSearchPresented)
    #expect(model.selectedNamespaceID == production.id)
    #expect(model.selectedResourceTab == .workloadsDeployments)

    if case let .workload(_, namespaceID, workloadID) = workloadResult.target {
        #expect(namespaceID == production.id)
        if case let .workload(_, selectedNamespaceID, selectedWorkloadID) = model.inspectorSelection {
            #expect(selectedNamespaceID == production.id)
            #expect(selectedWorkloadID == workloadID)
        } else {
            Issue.record("Inspector selection not updated for workload")
        }
        #expect(model.quickSearchFocus?.target == workloadResult.target)
    } else {
        Issue.record("Unexpected target type for workload selection")
    }
}

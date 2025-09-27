import Foundation
import Testing
@testable import kubex

@MainActor
@Test("metric series reports latest value")
func metricSeriesLatestValue() {
    let timestamp = Date()
    let series = MetricSeries(points: [MetricPoint(timestamp: timestamp.addingTimeInterval(-30), value: 0.3), MetricPoint(timestamp: timestamp, value: 0.6)])
    #expect(series.latest == 0.6)
}

@MainActor
@Test("cluster overview metrics sample detection")
func clusterOverviewMetricsSampleDetection() {
    let timestamp = Date()
    var metrics = ClusterOverviewMetrics(
        timestamp: timestamp,
        cpu: .empty,
        memory: .empty,
        disk: .empty,
        network: .empty,
        nodeHeatmap: [],
        podHeatmap: []
    )
    #expect(metrics.hasSamples == false)
    metrics.cpu = MetricSeries(points: [MetricPoint(timestamp: timestamp, value: 0.2)])
    #expect(metrics.hasSamples == true)
}

@MainActor
@Test("heatmap entry key acts as stable identifier")
func heatmapEntryIdentifier() {
    let entry = HeatmapEntry(key: "node:demo", label: "node-1", cpuRatio: 0.5, memoryRatio: 0.4)
    #expect(entry.id == "node:demo")
}

import Foundation
import Testing
@testable import kubex

@Test("config map diff captures additions and modifications")
func configMapDiffCapturesChanges() {
    let originalEntries = [
        ConfigMapEntry(key: "app.yaml", value: "mode: dev", isBinary: false),
        ConfigMapEntry(key: "binary", value: "YWJj", isBinary: true)
    ]

    var editors = originalEntries.map { ConfigMapEntryEditor(entry: $0) }
    if let index = editors.firstIndex(where: { $0.key == "app.yaml" }) {
        editors[index].updateValue("mode: prod")
    }
    let newEditor = ConfigMapEntryEditor(entry: ConfigMapEntry(key: "feature", value: "enabled", isBinary: false))
    editors.append(newEditor)

    let diffs = ConfigMapDiffSummary.compute(original: originalEntries, updated: editors)
    #expect(diffs.count == 2)

    guard let modified = diffs.first(where: { $0.key == "app.yaml" }) else {
        Issue.record("Missing modified diff for app.yaml")
        return
    }
    #expect(modified.kind == .modified)
    #expect(modified.before == "mode: dev")
    #expect(modified.after == "mode: prod")

    guard let added = diffs.first(where: { $0.key == "feature" }) else {
        Issue.record("Missing added diff for feature")
        return
    }
    #expect(added.kind == .added)
    #expect(added.before == nil)
    #expect(added.after == "enabled")
}

@Test("binary config map entries remain read-only")
func configMapBinaryEntriesReadOnly() {
    let binaryEntry = ConfigMapEntry(key: "binary", value: "YWJj", isBinary: true)
    var editor = ConfigMapEntryEditor(entry: binaryEntry)
    editor.updateValue("ZGVm")
    #expect(editor.value == "YWJj")
    #expect(editor.isEditable == false)
}

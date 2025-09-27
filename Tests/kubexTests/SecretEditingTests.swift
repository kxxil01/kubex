import Foundation
import Testing
@testable import kubex

@Test("secret diff identifies plaintext and binary modifications")
func secretDiffIdentifiesChanges() {
    let originalPlain = Data("hello".utf8).base64EncodedString()
    let originalBinary = Data([0xFF, 0x00, 0x01]).base64EncodedString()

    let originalEntries = [
        SecretDataEntry(key: "config", encodedValue: originalPlain),
        SecretDataEntry(key: "binary", encodedValue: originalBinary)
    ]

    var editors = originalEntries.map { SecretEntryEditor(entry: $0) }

    if let index = editors.firstIndex(where: { $0.key == "config" }) {
        editors[index].toggleVisibility()
        editors[index].decodedValue = "updated"
        editors[index].toggleVisibility()
    }

    if let index = editors.firstIndex(where: { $0.key == "binary" }) {
        editors[index].base64EditorValue = Data([0x01, 0x02]).base64EncodedString()
    }

    let diffs = SecretDiffSummary.compute(original: originalEntries, updated: editors)
    #expect(diffs.count == 2)

    guard let configDiff = diffs.first(where: { $0.key == "config" }) else {
        Issue.record("Missing config diff entry")
        return
    }
    #expect(configDiff.kind == .modified)
    #expect(configDiff.isBinary == false)
    #expect(configDiff.previousPlaintext == "hello")
    #expect(configDiff.currentPlaintext == "updated")

    guard let binaryDiff = diffs.first(where: { $0.key == "binary" }) else {
        Issue.record("Missing binary diff entry")
        return
    }
    #expect(binaryDiff.kind == .modified)
    #expect(binaryDiff.isBinary == true)
    #expect(binaryDiff.previousPlaintext == nil)
    #expect(binaryDiff.previousBase64 == originalBinary)
}

@Test("secret entry base64 editing preserves encoded state")
func secretEntryBinaryEditingPreservesBase64() {
    let original = SecretDataEntry(key: "token", encodedValue: Data("value".utf8).base64EncodedString())
    var editor = SecretEntryEditor(entry: original)
    #expect(editor.canDecode)
    #expect(editor.isDecodedVisible == false)

    editor.base64EditorValue = "@@@"
    #expect(editor.canDecode == false)
    #expect(editor.isDecodedVisible == false)

    editor.toggleVisibility()
    #expect(editor.isDecodedVisible == false)

    let restored = Data("restored".utf8).base64EncodedString()
    editor.base64EditorValue = restored
    #expect(editor.canDecode)
    editor.toggleVisibility()
    #expect(editor.isDecodedVisible)
    #expect(editor.encodedValueForSave() == restored)
}

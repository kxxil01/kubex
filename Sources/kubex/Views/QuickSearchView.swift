import SwiftUI
import AppKit

struct QuickSearchView: View {
    @EnvironmentObject private var model: AppModel
    @State private var highlightedIndex: Int = 0

    private var results: [AppModel.QuickSearchResult] { model.quickSearchResults }
    private var namespaces: [Namespace] { model.currentNamespaces ?? [] }

    var body: some View {
        VStack(spacing: 16) {
            header
            filterRow
            Divider()
            resultsSection
        }
        .padding(20)
        .frame(width: 640)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 24, x: 0, y: 16)
        .onChange(of: model.quickSearchResults) { _, newValue in
            guard !newValue.isEmpty else {
                highlightedIndex = 0
                return
            }
            highlightedIndex = min(highlightedIndex, newValue.count - 1)
        }
        .onAppear {
            highlightedIndex = 0
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)

            QuickSearchInputField(
                text: $model.quickSearchQuery,
                placeholder: "Search workloads, pods, services…",
                onCommit: submitSelection,
                onMoveSelection: moveSelection,
                onCancel: model.dismissQuickSearch
            )
            .frame(height: 30)

            Button(action: model.dismissQuickSearch) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
    }

    @ViewBuilder
    private var filterRow: some View {
        HStack(alignment: .center, spacing: 12) {
            if !namespaces.isEmpty {
                let selection = Binding<Namespace.ID>(
                    get: { model.quickSearchNamespaceFilter ?? AppModel.allNamespacesNamespaceID },
                    set: { model.quickSearchNamespaceFilter = $0 }
                )
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    Picker("Namespace", selection: selection) {
                        ForEach(namespaces) { namespace in
                            Text(namespace.name).tag(namespace.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }

            Spacer()

            let count = results.count
            Text(count == 0 ? "No results" : "\(count) result\(count == 1 ? "" : "s")")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if results.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: model.quickSearchQuery.isEmpty ? "keyboard" : "doc.text.magnifyingglass")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(model.quickSearchQuery.isEmpty ? "Start typing to search" : "No matches found")
                    .font(.headline)
                Text(model.quickSearchQuery.isEmpty ? "Search across workloads, pods, config, services, and more." : "Adjust your query or namespace filter to see more results.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        } else {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        Button(action: {
                            highlightedIndex = index
                            select(result)
                        }) {
                            QuickSearchRow(result: result, isHighlighted: highlightedIndex == index)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(maxHeight: 320)
        }
    }

    private func moveSelection(_ offset: Int) {
        guard !results.isEmpty else { return }
        let newIndex = (highlightedIndex + offset).clamped(to: 0...(results.count - 1))
        highlightedIndex = newIndex
    }

    private func submitSelection() {
        guard !results.isEmpty else {
            model.dismissQuickSearch()
            return
        }
        let index = highlightedIndex.clamped(to: 0...(results.count - 1))
        select(results[index])
    }

    private func select(_ result: AppModel.QuickSearchResult) {
        model.handleQuickSearchSelection(result)
    }
}

private struct QuickSearchRow: View {
    let result: AppModel.QuickSearchResult
    let isHighlighted: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: result.iconSystemName)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isHighlighted ? Color.accentColor.opacity(0.35) : Color.accentColor.opacity(0.18))
                )
                .foregroundStyle(isHighlighted ? .white : .accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.headline)
                    .foregroundStyle(isHighlighted ? Color.white : Color.primary)
                if let subtitle = result.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(isHighlighted ? Color.white.opacity(0.85) : Color.secondary)
                }
                if let detail = result.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(isHighlighted ? Color.white.opacity(0.7) : Color.secondary.opacity(0.75))
                }
            }
            Spacer()
            Text(result.category)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isHighlighted ? Color.white.opacity(0.25) : Color.secondary.opacity(0.16))
                )
                .foregroundStyle(isHighlighted ? .white : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHighlighted ? Color.accentColor.opacity(0.4) : Color.clear)
        )
    }
}

private struct QuickSearchInputField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onCommit: () -> Void
    var onMoveSelection: (Int) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> QuickSearchNSTextField {
        let textField = QuickSearchNSTextField(frame: .zero)
        textField.font = .systemFont(ofSize: 18, weight: .medium)
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.placeholderString = placeholder
        textField.stringValue = text
        textField.delegate = context.coordinator
        textField.target = context.coordinator
        textField.action = #selector(Coordinator.submit(_:))
        textField.onMove = { context.coordinator.handleMove(delta: $0) }
        textField.onCancel = { context.coordinator.handleCancel() }
        textField.onSubmit = { context.coordinator.handleSubmit() }
        DispatchQueue.main.async {
            textField.becomeFirstResponder()
        }
        return textField
    }

    func updateNSView(_ nsView: QuickSearchNSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.onMove = { context.coordinator.handleMove(delta: $0) }
        nsView.onCancel = { context.coordinator.handleCancel() }
        nsView.onSubmit = { context.coordinator.handleSubmit() }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        private let parent: QuickSearchInputField

        init(parent: QuickSearchInputField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        @objc func submit(_ sender: Any?) {
            parent.onCommit()
        }

        func handleMove(delta: Int) {
            parent.onMoveSelection(delta)
        }

        func handleCancel() {
            parent.onCancel()
        }

        func handleSubmit() {
            parent.onCommit()
        }
    }
}

private final class QuickSearchNSTextField: NSTextField {
    var onMove: ((Int) -> Void)?
    var onCancel: (() -> Void)?
    var onSubmit: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 125: // down arrow
            onMove?(1)
        case 126: // up arrow
            onMove?(-1)
        case 53: // escape
            onCancel?()
        case 36: // return
            onSubmit?()
        default:
            super.keyDown(with: event)
        }
    }
}

fileprivate extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

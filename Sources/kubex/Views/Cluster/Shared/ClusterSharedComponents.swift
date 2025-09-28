import SwiftUI

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var systemImage: String? = nil
    var tint: Color = .accentColor
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(.small)
                }
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? tint.opacity(0.2) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? tint.opacity(0.6) : Color.secondary.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? tint : Color.primary)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

@ViewBuilder
func centeredUnavailableView(
    _ title: String,
    systemImage: String,
    description: Text
) -> some View {
    ContentUnavailableView(title, systemImage: systemImage, description: description)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
}

struct EventTimelineView: View {
    let events: [EventSummary]

    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private var orderedEvents: [EventSummary] {
        events.sorted { eventDate($0) > eventDate($1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(orderedEvents.enumerated()), id: \.element.id) { index, event in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(color(for: event))
                            .frame(width: 8, height: 8)
                        if index < orderedEvents.count - 1 {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 2, height: 18)
                                .padding(.top, 2)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Label(event.type.rawValue.capitalized, systemImage: icon(for: event))
                                .labelStyle(.titleAndIcon)
                                .font(.caption.bold())
                                .foregroundStyle(color(for: event))
                            if event.count > 1 {
                                Text("×\(event.count)")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(relativeTime(for: event))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(event.message)
                            .font(.caption)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                    }
                }
            }
        }
    }

    private func eventDate(_ event: EventSummary) -> Date {
        if let timestamp = event.timestamp {
            return timestamp
        }
        let now = Date()
        switch event.age {
        case .minutes(let value):
            return now.addingTimeInterval(Double(-value * 60))
        case .hours(let value):
            return now.addingTimeInterval(Double(-value * 3600))
        case .days(let value):
            return now.addingTimeInterval(Double(-value * 86400))
        }
    }

    private func relativeTime(for event: EventSummary) -> String {
        EventTimelineView.formatter.localizedString(for: eventDate(event), relativeTo: Date())
    }

    private func color(for event: EventSummary) -> Color {
        switch event.type {
        case .error: return .red
        case .warning: return .orange
        case .normal: return .blue
        }
    }

    private func icon(for event: EventSummary) -> String {
        switch event.type {
        case .error: return "exclamationmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .normal: return "info.circle.fill"
        }
    }
}

extension View {
    @ViewBuilder
    func optionalHelp(_ message: String?) -> some View {
        if let message {
            self.help(message)
        } else {
            self
        }
    }
}

extension NumberFormatter {
    static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static let dataRateFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }()
}

enum PercentageFormatter {
    static func format(_ value: Double?) -> String {
        guard let value else { return "–" }
        return NumberFormatter.percentFormatter.string(from: NSNumber(value: value)) ?? "–"
    }
}

enum DataRateFormatter {
    static func format(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "–" }
        let units: [String] = ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"]
        var rate = value
        var index = 0
        while rate >= 1024, index < units.count - 1 {
            rate /= 1024
            index += 1
        }
        let formatted = NumberFormatter.dataRateFormatter.string(from: NSNumber(value: rate)) ?? String(format: "%.1f", rate)
        return "\(formatted) \(units[index])"
    }
}

struct SectionBox<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content
        }
    }
}

struct PlaceholderSection: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct FixedTableColumn<Row> {
    let title: String
    let width: CGFloat
    let alignment: Alignment
    private let renderer: (Row) -> AnyView

    init(_ title: String, width: CGFloat, alignment: Alignment = .leading, @ViewBuilder content: @escaping (Row) -> some View) {
        self.title = title
        self.width = width
        self.alignment = alignment
        self.renderer = { row in AnyView(content(row)) }
    }

    func view(for row: Row) -> AnyView {
        renderer(row)
    }
}

struct FixedColumnTable<Row: Identifiable>: View {
    let rows: [Row]
    let columns: [FixedTableColumn<Row>]
    var selection: Binding<Set<Row.ID>>? = nil
    var allowsMultipleSelection: Bool = true
    var highlightSelection: Bool = true
    var selectionColor: Color = Color.accentColor.opacity(0.08)
    var rowVerticalPadding: CGFloat = 6
    var rowHorizontalPadding: CGFloat = 12
    var minimumRowHeight: CGFloat = 34
    var headerBackground: Color = Color(nsColor: .underPageBackgroundColor)
    var tableBackground: Color = Color(nsColor: .textBackgroundColor)
    var showsRowDividers: Bool = true
    var focusID: Row.ID? = nil
    var onRowTap: ((Row) -> Void)? = nil
    var onRowDoubleTap: ((Row) -> Void)? = nil
    var rowBackground: ((Row, Bool) -> Color?)? = nil

    private var minimumHeight: CGFloat {
        let headerAndPadding: CGFloat = 48
        let contentHeight = CGFloat(max(rows.count, 1)) * minimumRowHeight
        let minRowsHeight = minimumRowHeight * 4
        let maxRowsHeight = minimumRowHeight * 14
        let clampedHeight = min(max(contentHeight, minRowsHeight), maxRowsHeight)
        return clampedHeight + headerAndPadding
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            rowView(for: row, index: index)
                                .id(row.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: minimumHeight, maxHeight: .infinity, alignment: .topLeading)
            }
            .background(tableBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onChange(of: focusID) { _, newValue in
                guard let newValue else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private func rowView(for row: Row, index: Int) -> some View {
        let isSelected = selection?.wrappedValue.contains(row.id) ?? false
        let singleTap = makeSingleTapHandler(for: row)

        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(Array(columns.enumerated()), id: \.offset) { columnPair in
                    columnPair.element.view(for: row)
                        .frame(width: columnPair.element.width, alignment: columnPair.element.alignment)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, rowVerticalPadding)
            .padding(.horizontal, rowHorizontalPadding)
            .background(backgroundColor(for: row, isSelected: isSelected))
            .contentShape(Rectangle())
            .onTapGesture(perform: singleTap)
            .onTapGesture(count: 2) { onRowDoubleTap?(row) }

            if showsRowDividers && index < rows.count - 1 {
                Divider()
            }
        }
    }

    private func makeSingleTapHandler(for row: Row) -> () -> Void {
        {
            if let binding = selection {
                var updated = binding.wrappedValue
                if allowsMultipleSelection {
                    if updated.contains(row.id) {
                        updated.remove(row.id)
                    } else {
                        updated.insert(row.id)
                    }
                } else {
                    updated = [row.id]
                }
                binding.wrappedValue = updated
            }
            onRowTap?(row)
        }
    }

    private func backgroundColor(for row: Row, isSelected: Bool) -> Color {
        if let rowBackground,
           let custom = rowBackground(row, isSelected) {
            return custom
        }
        if isSelected && highlightSelection {
            return selectionColor
        }
        return tableBackground
    }

    private var header: some View {
        HStack(spacing: 8) {
            ForEach(Array(columns.enumerated()), id: \.offset) { columnPair in
                Text(columnPair.element.title)
                    .frame(width: columnPair.element.width, alignment: columnPair.element.alignment)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(headerBackground)
    }
}

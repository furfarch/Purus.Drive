import SwiftUI

/// One collapsible line with a title and a short summary (same as FinAI's Fold).
struct Fold<Content: View>: View {
    let title: String
    let summary: String
    @ViewBuilder var content: () -> Content
    @State private var open: Bool

    init(title: String, summary: String, open: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.summary = summary
        self.content = content
        self._open = State(initialValue: open)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $open) {
            content()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if !summary.isEmpty { Text(summary).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
}

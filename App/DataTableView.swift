import SwiftUI
import SavantKit

/// Shows EVERY column the server returned. Tap a header to sort; search filters rows.
struct DataTableView: View {
    let table: DataTable
    @State private var sortColumn: String?
    @State private var ascending = false
    @State private var query = ""

    private var shown: DataTable {
        var t = table.filtered(matching: query)
        if let c = sortColumn { t = t.sorted(by: c, ascending: ascending) }
        return t
    }

    var body: some View {
        let t = shown
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(Array(t.rows.enumerated()), id: \.offset) { i, row in
                        HStack(spacing: 0) { ForEach(Array(row.enumerated()), id: \.offset) { _, v in cell(v) } }
                            .background(i % 2 == 0 ? Color.clear : Color.gray.opacity(0.08))
                    }
                } header: {
                    HStack(spacing: 0) {
                        ForEach(t.columns, id: \.self) { c in
                            Button { if sortColumn == c { ascending.toggle() } else { sortColumn = c; ascending = false } } label: {
                                HStack(spacing: 2) {
                                    Text(c).bold()
                                    if sortColumn == c { Image(systemName: ascending ? "arrow.up" : "arrow.down") }
                                }.frame(width: 110, alignment: .leading).padding(6)
                            }.foregroundStyle(.white)
                        }
                    }.background(Theme.navy)
                }
            }
        }
        .searchable(text: $query)
        .overlay(alignment: .bottomTrailing) {
            Text("\(t.rows.count) rows · \(t.columns.count) cols").font(.caption2)
                .padding(6).background(.thinMaterial, in: Capsule()).padding(8)
        }
    }
    private func cell(_ v: String) -> some View {
        Text(v).font(.callout.monospacedDigit()).lineLimit(1).frame(width: 110, alignment: .leading).padding(6)
    }
}

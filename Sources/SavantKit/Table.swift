import Foundation

/// A dynamically-typed table: whatever columns Savant returns are kept.
public struct DataTable: Equatable {
    public var columns: [String]
    public var rows: [[String]]

    public init(columns: [String], rows: [[String]]) {
        self.columns = columns
        self.rows = rows
    }

    public init(csv: String) {
        let parsed = CSV.parse(csv)
        guard let header = parsed.first else { self.init(columns: [], rows: []); return }
        let width = header.count
        let body = parsed.dropFirst().map { r -> [String] in
            r.count >= width ? Array(r.prefix(width)) : r + Array(repeating: "", count: width - r.count)
        }
        self.init(columns: header, rows: Array(body))
    }

    public func index(of column: String) -> Int? { columns.firstIndex(of: column) }

    public func value(_ row: Int, _ column: String) -> String? {
        guard let c = index(of: column), rows.indices.contains(row) else { return nil }
        return rows[row][c]
    }

    /// Sort by a column; numeric when both values parse, otherwise lexical.
    public func sorted(by column: String, ascending: Bool) -> DataTable {
        guard let c = index(of: column) else { return self }
        let sortedRows = rows.sorted { a, b in
            let (x, y) = (a[c], b[c])
            if let dx = Double(x), let dy = Double(y) { return ascending ? dx < dy : dx > dy }
            if x.isEmpty != y.isEmpty { return !x.isEmpty }   // blanks last
            return ascending ? x < y : x > y
        }
        return DataTable(columns: columns, rows: sortedRows)
    }

    public func filtered(matching query: String) -> DataTable {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return self }
        return DataTable(columns: columns, rows: rows.filter { $0.contains { $0.lowercased().contains(q) } })
    }

    public func csvString() -> String {
        func esc(_ s: String) -> String {
            s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s
        }
        return ([columns] + rows).map { $0.map(esc).joined(separator: ",") }.joined(separator: "\n")
    }
}

import XCTest
@testable import SavantKit

final class CSVTests: XCTestCase {
    func testQuotesAndNewlines() {
        let rows = CSV.parse("\u{FEFF}a,b\r\n\"x, y\",\"he said \"\"hi\"\"\"\r\n1,\"l1\nl2\"\r\n")
        XCTAssertEqual(rows, [["a","b"],["x, y","he said \"hi\""],["1","l1\nl2"]])
    }
    func testTablePadsAndSorts() {
        let t = DataTable(csv: "n,v\nA,2\nB,10\nC,\n").sorted(by: "v", ascending: false)
        XCTAssertEqual(t.rows.map { $0[0] }, ["B","A","C"])
    }
    func testStatcastSplitParams() {
        var q = StatcastQuery(); q.playerID = 660271; q.seasons = [2025]; q.pitcherThrows = "L"
        let d = Dictionary(q.queryItems.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
        XCTAssertEqual(d["pitcher_throws"], "L"); XCTAssertEqual(d["hfSea"], "2025|"); XCTAssertEqual(d["batters_lookup[]"], "660271")
    }
    func testCSVRoundTrip() {
        let t = DataTable(columns: ["a"], rows: [["x,\"y\""]])
        XCTAssertEqual(DataTable(csv: t.csvString()), t)
    }
}

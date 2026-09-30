import Foundation

public enum SavantError: Error, LocalizedError {
    case badResponse(Int)
    case notCSV(String)
    public var errorDescription: String? {
        switch self {
        case .badResponse(let c): return "Savant returned HTTP \(c)."
        case .notCSV(let s): return "Savant returned something other than CSV: \(s.prefix(80))"
        }
    }
}

public struct PlayerHit: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let pos: String?
    public let teamAbbr: String?
    enum CodingKeys: String, CodingKey { case id, name, pos, teamAbbr = "team" }
}

public final class SavantClient: @unchecked Sendable {
    public static let base = URL(string: "https://baseballsavant.mlb.com")!
    private let session: URLSession
    private var cache: [URL: (Date, DataTable)] = [:]
    private let lock = NSLock()

    public init(session: URLSession = .shared) { self.session = session }

    func url(_ path: String, _ items: [URLQueryItem]) -> URL {
        var c = URLComponents(url: Self.base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        c.queryItems = items
        return c.url!
    }

    func fetchTable(_ url: URL, ttl: TimeInterval = 300) async throws -> DataTable {
        lock.lock(); let hit = cache[url]; lock.unlock()
        if let (t, table) = hit, Date().timeIntervalSince(t) < ttl { return table }
        var req = URLRequest(url: url); req.timeoutInterval = 60
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { throw SavantError.badResponse(http.statusCode) }
        guard let text = String(data: data, encoding: .utf8) else { throw SavantError.notCSV("non-UTF8") }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") { throw SavantError.notCSV(text) }
        let table = DataTable(csv: text)
        lock.lock(); cache[url] = (Date(), table); lock.unlock()
        return table
    }

    public func leaderboard(_ lb: Leaderboard, year: Int, type: PlayerType = .batter) async throws -> DataTable {
        var items: [URLQueryItem] = [.init(name: lb.yearParam, value: String(year)), .init(name: "csv", value: "true")]
        if lb.yearParam == "startYear" { items.append(.init(name: "endYear", value: String(year))) }
        var params = lb.extra
        if lb.supportsType { params["type"] = type.rawValue; params["min"] = params["min"] ?? "q" }
        items += params.sorted { $0.key < $1.key }.map { .init(name: $0.key, value: $0.value) }
        return try await fetchTable(url("leaderboard/\(lb.path)", items))
    }

    /// Custom leaderboard with an arbitrary metric selection.
    public func custom(year: Int, type: PlayerType, metrics: [String], minimum: String = "q") async throws -> DataTable {
        try await fetchTable(url("leaderboard/custom", [
            .init(name: "year", value: String(year)), .init(name: "type", value: type.rawValue),
            .init(name: "filter", value: ""), .init(name: "min", value: minimum),
            .init(name: "selections", value: metrics.joined(separator: ",")),
            .init(name: "chart", value: "false"), .init(name: "csv", value: "true"),
        ]))
    }

    public func statcast(_ q: StatcastQuery) async throws -> DataTable {
        try await fetchTable(url("statcast_search/csv", q.queryItems))
    }

    public func searchPlayers(_ text: String) async throws -> [PlayerHit] {
        let u = url("player/search-all", [.init(name: "search", value: text)])
        let (data, _) = try await session.data(from: u)
        return try JSONDecoder().decode([PlayerHit].self, from: data)
    }

    /// Every split Savant's data supports for one player, fetched in parallel.
    public func splits(for playerID: Int, role: PlayerRole, season: Int) async throws -> [(label: String, table: DataTable)] {
        var specs: [(String, (inout StatcastQuery) -> Void)] = [("Overall", { _ in })]
        if role == .batter {
            specs += [("vs LHP", { $0.pitcherThrows = "L" }), ("vs RHP", { $0.pitcherThrows = "R" })]
        } else {
            specs += [("vs LHB", { $0.batterStands = "L" }), ("vs RHB", { $0.batterStands = "R" })]
        }
        specs += [("Home", { $0.homeAway = "Home" }), ("Road", { $0.homeAway = "Road" }),
                  ("RISP", { $0.runnersOn = ["RISP"] }), ("Bases Empty", { $0.runnersOn = ["Empty"] }),
                  ("Two Strikes", { $0.strikes = [2] }), ("Ahead in Count", { $0.balls = [2, 3]; $0.strikes = [0, 1] })]
        return try await withThrowingTaskGroup(of: (Int, String, DataTable).self) { group in
            for (i, spec) in specs.enumerated() {
                var q = StatcastQuery()
                q.role = role == .batter ? .batter : .pitcher
                q.playerID = playerID; q.seasons = [season]; q.groupBy = .name
                spec.1(&q)
                let label = spec.0
                group.addTask { (i, label, try await self.statcast(q)) }
            }
            var out: [(Int, String, DataTable)] = []
            for try await r in group { out.append(r) }
            return out.sorted { $0.0 < $1.0 }.map { ($0.1, $0.2) }
        }
    }

    public typealias PlayerRole = StatcastQuery.PlayerRole
}

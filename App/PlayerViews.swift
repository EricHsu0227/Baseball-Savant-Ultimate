import SwiftUI
import SavantKit

struct SearchView: View {
    @EnvironmentObject var model: AppModel
    @State private var text = ""
    @State private var hits: [PlayerHit] = []
    var body: some View {
        List(hits) { p in
            NavigationLink { PlayerView(player: p) } label: {
                VStack(alignment: .leading) { Text(p.name); Text([p.pos, p.teamAbbr].compactMap { $0 }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .searchable(text: $text, prompt: "Search any player")
        .navigationTitle("Players")
        .task(id: text) {
            guard text.count >= 2 else { hits = []; return }
            try? await Task.sleep(nanoseconds: 300_000_000)      // debounce
            if Task.isCancelled { return }
            hits = (try? await model.client.searchPlayers(text)) ?? []
        }
    }
}

/// One page, every split: overall, vs L/R, home/road, RISP, count, etc.
struct PlayerView: View {
    @EnvironmentObject var model: AppModel
    let player: PlayerHit
    @State private var role: SavantClient.PlayerRole = .batter
    @State private var splits: [(label: String, table: DataTable)] = []
    @State private var error: String?
    @State private var loading = false

    var body: some View {
        List {
            Picker("Role", selection: $role) { Text("Hitting").tag(SavantClient.PlayerRole.batter); Text("Pitching").tag(SavantClient.PlayerRole.pitcher) }
                .pickerStyle(.segmented)
            if loading { ProgressView() }
            if let error { Text(error).foregroundStyle(.red) }
            ForEach(splits, id: \.label) { s in
                Section(s.label) {
                    if let cols = Optional(s.table), let row = cols.rows.first {
                        ForEach(Array(cols.columns.enumerated()), id: \.offset) { i, c in
                            HStack { Text(c).foregroundStyle(.secondary); Spacer(); Text(row[i]).monospacedDigit() }.font(.callout)
                        }
                    } else { Text("No data").foregroundStyle(.secondary) }
                }
            }
        }
        .navigationTitle(player.name).navigationBarTitleDisplayMode(.inline)
        .toolbar { SeasonPicker() }
        .task(id: "\(role)-\(model.season)") {
            loading = true; error = nil
            do { splits = try await model.client.splits(for: player.id, role: role, season: model.season) }
            catch { self.error = error.localizedDescription; splits = [] }
            loading = false
        }
    }
}

/// Free-form Statcast Search: any filter combination, grouped any way.
struct StatcastSearchView: View {
    @EnvironmentObject var model: AppModel
    @State private var q = StatcastQuery()
    @State private var pitcherThrows = "Any"
    @State private var batterStands = "Any"
    @State private var pitchType = "Any"
    @StateObject private var loader = TableLoader()
    private let pitches = ["Any","FF","SI","FC","SL","ST","CU","CH","FS","KC","SV"]

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Picker("Role", selection: $q.role) { Text("Batters").tag(StatcastQuery.PlayerRole.batter); Text("Pitchers").tag(StatcastQuery.PlayerRole.pitcher) }
                Picker("Pitcher throws", selection: $pitcherThrows) { ForEach(["Any","L","R"], id: \.self) { Text($0) } }
                Picker("Batter stands", selection: $batterStands) { ForEach(["Any","L","R"], id: \.self) { Text($0) } }
                Picker("Pitch type", selection: $pitchType) { ForEach(pitches, id: \.self) { Text($0) } }
                Picker("Group by", selection: $q.groupBy) { ForEach(StatcastQuery.GroupBy.allCases, id: \.self) { Text($0.rawValue) } }
                Button("Run") { Task { await run() } }
            }.frame(maxHeight: 300)
            LoadableTable(loader: loader) { Task { await run() } }
        }.navigationTitle("Statcast Search")
    }
    private func run() async {
        var query = q
        query.seasons = [model.season]
        query.pitcherThrows = pitcherThrows == "Any" ? nil : pitcherThrows
        query.batterStands = batterStands == "Any" ? nil : batterStands
        query.pitchTypes = pitchType == "Any" ? [] : [pitchType]
        let c = model.client
        await loader.load { try await c.statcast(query) }
    }
}

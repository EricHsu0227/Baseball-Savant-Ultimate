import SwiftUI
import SavantKit

struct RootView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        TabView {
            NavigationStack { LeaderboardListView() }
                .tabItem { Label("Leaderboards", systemImage: "list.number") }
            NavigationStack { CustomLeaderboardView() }
                .tabItem { Label("Custom", systemImage: "slider.horizontal.3") }
            NavigationStack { SearchView() }
                .tabItem { Label("Players", systemImage: "magnifyingglass") }
            NavigationStack { StatcastSearchView() }
                .tabItem { Label("Statcast", systemImage: "scope") }
        }
        .tint(Theme.red)
    }
}

struct SeasonPicker: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        Picker("Season", selection: $model.season) {
            ForEach((2015...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { Text(String($0)).tag($0) }
        }
    }
}

struct LeaderboardListView: View {
    var body: some View {
        List {
            ForEach(Dictionary(grouping: Catalog.leaderboards, by: \.group).sorted { $0.key < $1.key }, id: \.key) { group, items in
                Section(group) {
                    ForEach(items) { lb in NavigationLink(lb.title) { LeaderboardView(board: lb) } }
                }
            }
        }
        .navigationTitle("Savant")
        .toolbar { ToolbarItem(placement: .primaryAction) { SeasonPicker() } }
    }
}

@MainActor
final class TableLoader: ObservableObject {
    enum State { case idle, loading, loaded(DataTable), failed(String) }
    @Published var state: State = .idle
    func load(_ work: @escaping () async throws -> DataTable) async {
        state = .loading
        do { state = .loaded(try await work()) } catch { state = .failed(error.localizedDescription) }
    }
}

struct LoadableTable: View {
    @ObservedObject var loader: TableLoader
    var retry: () -> Void
    var body: some View {
        switch loader.state {
        case .idle, .loading: ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let m):
            VStack(spacing: 12) { Text(m).multilineTextAlignment(.center); Button("Retry", action: retry) }.padding()
        case .loaded(let t): DataTableView(table: t)
        }
    }
}

struct LeaderboardView: View {
    @EnvironmentObject var model: AppModel
    let board: Leaderboard
    @State private var type: PlayerType = .batter
    @StateObject private var loader = TableLoader()

    var body: some View {
        VStack(spacing: 0) {
            if board.supportsType {
                Picker("Type", selection: $type) { ForEach(PlayerType.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
                    .pickerStyle(.segmented).padding(.horizontal)
            }
            LoadableTable(loader: loader) { Task { await reload() } }
        }
        .navigationTitle(board.title).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .primaryAction) { SeasonPicker() } }
        .task(id: "\(model.season)-\(type.rawValue)") { await reload() }
    }
    private func reload() async {
        let (c, y, t, b) = (model.client, model.season, type, board)
        await loader.load { try await c.leaderboard(b, year: y, type: t) }
    }
}

/// Custom leaderboard: pick ANY metric from the catalog.
struct CustomLeaderboardView: View {
    @EnvironmentObject var model: AppModel
    @State private var type: PlayerType = .batter
    @State private var selected: Set<String> = ["xwoba", "woba", "exit_velocity_avg", "barrel_batted_rate"]
    @State private var picking = false
    @StateObject private var loader = TableLoader()

    var body: some View {
        VStack(spacing: 0) {
            Picker("Type", selection: $type) { ForEach(PlayerType.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
                .pickerStyle(.segmented).padding(.horizontal)
            LoadableTable(loader: loader) { Task { await reload() } }
        }
        .navigationTitle("Custom Leaderboard")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { Button("Metrics (\(selected.count))") { picking = true } }
            ToolbarItem(placement: .primaryAction) { SeasonPicker() }
        }
        .sheet(isPresented: $picking, onDismiss: { Task { await reload() } }) { MetricPicker(selected: $selected) }
        .task(id: "\(model.season)-\(type.rawValue)") { await reload() }
    }
    private func reload() async {
        let (c, y, t, m) = (model.client, model.season, type, Catalog.customMetrics.filter(selected.contains))
        await loader.load { try await c.custom(year: y, type: t, metrics: m) }
    }
}

struct MetricPicker: View {
    @Binding var selected: Set<String>
    @Environment(\.dismiss) private var dismiss
    @State private var filter = ""
    var body: some View {
        NavigationStack {
            List(Catalog.customMetrics.filter { filter.isEmpty || $0.contains(filter.lowercased()) }, id: \.self) { m in
                Button { if !selected.insert(m).inserted { selected.remove(m) } } label: {
                    HStack { Text(m); Spacer(); if selected.contains(m) { Image(systemName: "checkmark") } }
                }.foregroundStyle(.primary)
            }
            .searchable(text: $filter)
            .navigationTitle("Metrics")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}

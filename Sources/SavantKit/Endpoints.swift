import Foundation

public enum PlayerType: String, CaseIterable, Sendable { case batter, pitcher }

/// One Savant leaderboard page that can be exported as CSV.
public struct Leaderboard: Identifiable, Hashable, Sendable {
    public var id: String { path }
    public let title: String
    public let path: String            // under /leaderboard/
    public let group: String
    public let supportsType: Bool      // batter/pitcher toggle
    public let extra: [String: String] // fixed params
    public let yearParam: String

    init(_ title: String, _ path: String, group: String, supportsType: Bool = false,
         yearParam: String = "year", extra: [String: String] = [:]) {
        self.title = title; self.path = path; self.group = group
        self.supportsType = supportsType; self.yearParam = yearParam; self.extra = extra
    }
}

public enum Catalog {
    /// Params below reflect Savant's public CSV exports as last known; the
    /// client shows whatever columns come back, so drift degrades gracefully.
    public static let leaderboards: [Leaderboard] = [
        .init("Expected Statistics", "expected_statistics", group: "Hitting & Pitching", supportsType: true),
        .init("Exit Velocity & Barrels", "statcast", group: "Hitting & Pitching", supportsType: true),
        .init("Percentile Rankings", "percentile-rankings", group: "Hitting & Pitching", supportsType: true),
        .init("Bat Tracking", "bat-tracking", group: "Hitting"),
        .init("Swing/Take", "swing-take", group: "Hitting"),
        .init("Home Runs", "home-runs", group: "Hitting"),
        .init("Pitch Arsenals", "pitch-arsenals", group: "Pitching", extra: ["type": "avg_speed"]),
        .init("Pitch Arsenal Stats", "pitch-arsenal-stats", group: "Pitching", supportsType: true),
        .init("Pitch Movement", "pitch-movement", group: "Pitching", extra: ["pitch_type": "FF"]),
        .init("Active Spin", "active-spin", group: "Pitching"),
        .init("Pitcher Running Game", "pitcher-running-game", group: "Pitching"),
        .init("Sprint Speed", "sprint_speed", group: "Running", extra: ["min": "10"]),
        .init("Baserunning", "baserunning", group: "Running"),
        .init("Outs Above Average", "outs_above_average", group: "Fielding",
              yearParam: "startYear", extra: ["type": "Fielder", "split": "no", "range": "year", "min": "q"]),
        .init("Catch Probability", "catch_probability", group: "Fielding"),
        .init("Arm Strength", "arm-strength", group: "Fielding"),
        .init("Catcher Framing", "catcher-framing", group: "Catching"),
        .init("Catcher Throwing", "catcher_throwing", group: "Catching"),
        .init("Catcher Blocking", "catcher-blocking", group: "Catching"),
        .init("Catcher Pop Time", "poptime", group: "Catching"),
    ]

    /// Metrics selectable on the Custom Leaderboard (`selections=`).
    public static let customMetrics: [String] = [
        "player_age","pa","ab","hit","single","double","triple","home_run","strikeout","walk","k_percent","bb_percent",
        "batting_avg","slg_percent","on_base_percent","on_base_plus_slg","isolated_power","babip","b_rbi","b_run",
        "xba","xslg","xwoba","xobp","xiso","exit_velocity_avg","launch_angle_avg","sweet_spot_percent",
        "barrel_batted_rate","solidcontact_percent","flareburner_percent","poorlyunder_percent","poorlytopped_percent",
        "poorlyweak_percent","hard_hit_percent","avg_best_speed","avg_hyper_speed","z_swing_percent","z_swing_miss_percent",
        "oz_swing_percent","oz_swing_miss_percent","oz_contact_percent","out_zone_swing_miss","out_zone_percent",
        "out_zone","meatball_swing_percent","meatball_percent","pitch_count_offspeed","pitch_count_fastball",
        "pitch_count_breaking","iz_contact_percent","in_zone_percent","edge_percent","whiff_percent","swing_percent",
        "pull_percent","straightaway_percent","opposite_percent","groundballs_percent","flyballs_percent",
        "linedrives_percent","popups_percent","woba","wobacon","xwobacon","bacon","xbacon","sprint_speed","n",
        "p_game","p_formatted_ip","p_win","p_loss","p_save","p_era","p_opp_batting_avg","p_strikeout","p_walk","p_k_percent",
        "p_bb_percent","whip","xera","p_total_pitches","pitch_hand","batter_run_value_per_100","p_run_value","fastball_avg_speed",
    ]
}

// MARK: - Statcast Search (pitch-by-pitch; source of all "splits")

/// Builds a `statcast_search/csv` query. Every filter Savant's search UI has
/// is a plain query param, so a split (vs LHP/RHP, by count, by zone, by month…)
/// is just a filter plus a `group_by`.
public struct StatcastQuery: Sendable {
    public enum PlayerRole: String, Sendable { case batter, pitcher }
    public enum GroupBy: String, CaseIterable, Sendable {
        case name, teamName = "team", pitchType = "pitch-type", month, year = "venue", count
        case name_event = "name-event", name_year = "name-year", name_team = "name-team", name_pitch = "name-pitch-type"
    }

    public var role: PlayerRole = .batter
    public var playerID: Int?
    public var seasons: [Int] = []
    public var pitcherThrows: String?     // "L" | "R"   -> batter vs LHP/RHP
    public var batterStands: String?      // "L" | "R"   -> pitcher vs LHB/RHB
    public var pitchTypes: [String] = []  // FF, SL, CU, CH, SI, FC, FS ...
    public var events: [String] = []      // single, home_run, strikeout ...
    public var balls: [Int] = []
    public var strikes: [Int] = []
    public var zones: [Int] = []
    public var innings: [Int] = []
    public var outs: [Int] = []
    public var homeAway: String?          // "Home" | "Road"
    public var opponent: String?          // team abbrev
    public var team: String?
    public var runnersOn: [String] = []   // "Empty","Men_On","RISP","Loaded"
    public var startDate: String?         // yyyy-MM-dd
    public var endDate: String?
    public var groupBy: GroupBy = .name
    public var minPitches: Int = 0
    public var minResults: Int = 0
    public var sortColumn: String = "pitches"

    public init() {}

    private func pipe(_ v: [String]) -> String { v.isEmpty ? "" : v.joined(separator: "|") + "|" }

    public var queryItems: [URLQueryItem] {
        var q: [URLQueryItem] = [
            .init(name: "all", value: "true"),
            .init(name: "hfSea", value: pipe(seasons.map(String.init))),
            .init(name: "hfPT", value: pipe(pitchTypes)),
            .init(name: "hfAB", value: pipe(events)),
            .init(name: "hfBBT", value: ""),
            .init(name: "hfZ", value: pipe(zones.map(String.init))),
            .init(name: "hfInn", value: pipe(innings.map(String.init))),
            .init(name: "hfOuts", value: pipe(outs.map(String.init))),
            .init(name: "hfBBL", value: ""),
            .init(name: "hfC", value: ""),
            .init(name: "hfStrikes", value: pipe(strikes.map(String.init))),
            .init(name: "hfBalls", value: pipe(balls.map(String.init))),
            .init(name: "hfRO", value: pipe(runnersOn)),
            .init(name: "player_type", value: role.rawValue),
            .init(name: "stadium", value: ""),
            .init(name: "game_date_gt", value: startDate ?? ""),
            .init(name: "game_date_lt", value: endDate ?? ""),
            .init(name: "hfTeam", value: team.map { $0 + "|" } ?? ""),
            .init(name: "hfOpponent", value: opponent.map { $0 + "|" } ?? ""),
            .init(name: "home_road", value: homeAway ?? ""),
            .init(name: "pitcher_throws", value: pitcherThrows ?? ""),
            .init(name: "batter_stands", value: batterStands ?? ""),
            .init(name: "group_by", value: groupBy.rawValue),
            .init(name: "sort_col", value: sortColumn),
            .init(name: "sort_order", value: "desc"),
            .init(name: "min_pitches", value: String(minPitches)),
            .init(name: "min_results", value: String(minResults)),
            .init(name: "type", value: "details"),
        ]
        if let id = playerID {
            q.append(.init(name: role == .batter ? "batters_lookup[]" : "pitchers_lookup[]", value: String(id)))
        }
        return q
    }
}

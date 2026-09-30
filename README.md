# Savant Ultimate (iOS)

A SwiftUI client for Baseball Savant's public CSV exports that surfaces **every column
the server returns**, including splits the site never displays (e.g. wOBA vs LHP/RHP).

## Layout
- `Sources/SavantKit` – CSV parser, dynamic `DataTable`, endpoint catalog, `StatcastQuery`
  builder, `SavantClient` (caching, parallel splits). Pure Swift, unit-tested.
- `App/` – SwiftUI app (leaderboards, custom leaderboard with any metric, player search,
  per-player split page, free-form Statcast search).
- `project.yml` – XcodeGen spec. On a Mac: `brew install xcodegen && xcodegen && open SavantUltimate.xcodeproj`.

## Why "everything" works
Nothing is hard-coded per stat. Tables render whatever columns arrive, so new Savant
columns appear automatically. Splits come from `statcast_search/csv` filters
(`pitcher_throws`, `batter_stands`, `home_road`, `hfRO`, `hfBalls`/`hfStrikes`, `hfZ`, dates…).

## Status / honest caveats
- **Not compiled or run.** Authored in a Linux sandbox with no Swift toolchain, and
  `baseballsavant.mlb.com` was blocked, so endpoint params and CSV headers are from memory and
  unverified. Expect to fix some parameter names on first run; the error banner shows the HTTP status.
- Savant has no official API; endpoints can change and usage is subject to their terms. Cache TTL is
  5 min to stay polite. Not affiliated with MLB; no MLB marks or logos are used.
- Not yet built: player headshots, spray/zone charts, game feeds (`/gf`), video, rolling charts,
  offline persistence. The `Catalog` is a starting list, not the full set of Savant pages.

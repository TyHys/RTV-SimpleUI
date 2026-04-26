All downloads are for the latest versions only. Previous version can be built using the git history of the linked GitHub repository if needed.

# Changelog

All notable changes to `SimpleHUD` are documented in this file.

## [1.0.6] - 2026-04-25

### Added (Show All Vitals hotkey)
- Added a **Show All Vitals** hold-key (rebindable) that bypasses all threshold and transparency logic to show every vital at full opacity while held.
- Does not affect the ailment/status tray — binary icons have no meaningful inactive state to bypass.
- Matches the existing Toggle HUD implementation pattern: same keybind persistence, same binding-UI injection, same `InputMap` action registration.

### Added (MCM release variant)
- Added `SimpleUI-MCM.vmz` as an optional release alongside the standard `SimpleUI.vmz`.
- MCM variant requires **Mod Configuration Menu** by Doink Oink (modworkshop.net/mod/53713) installed alongside it.
- MCM variant exposes Vitals, Ailments, Keybinds, and Misc settings directly inside the MCM menu — no in-game main-menu button is injected.
- Settings are stored in `user://MCM/simple-hud/config.ini` and synced back to `user://simplehud_preferences.json` for cross-format compatibility.
- The standard `SimpleUI.vmz` is unchanged and does not require MCM.

### Changed (internal performance)
- Per-frame `get_node_or_null` calls for vanilla HUD child nodes replaced with nodes cached at bind time.
- `_preferences_cache` read path now uses `FileAccess.get_modified_time()` — file is re-deserialized only when the mtime changes, reducing OS file I/O.
- `Preferences.tres` mtime check is further rate-limited to once per 30 frames (~0.5 s at 60 fps).
- Keybinding-UI DFS scan cached after first successful find — subsequent 90-frame probes hit the cached node directly.
- `_resource_is_game_data()` rewritten to O(1) — two direct property probes instead of full property-list iteration.
- `StatusTray._icon_paths()` array allocation converted to a `static var` cache (built once, reused every refresh).
- `HudOverlay._widget_defs()` array allocation converted to a `static var` cache.
- Fill-empty vitals layout changes now debounced at 200 ms (`Time.get_ticks_usec()`) to prevent relayout thrashing when vitals fluctuate across thresholds mid-combat.
- `_layout_vitals()` internal grouping now uses four pre-allocated arrays instead of a Dictionary to avoid per-frame allocation.
- Show All Vitals keypress immediately bypasses the fill-empty debounce (via `mark_layout_dirty()`) for instant repositioning when held/released.

### Changed (keybind defaults + release diagnostics)
- Default `Toggle HUD` and `Show All Vitals` keybinds are now unassigned (`KEY_NONE`) in both standard and MCM configs.
- FPS/Map deep-diagnostic console logging is disabled by default for release (`SIMPLEHUD_FPSMAP_DIAG_LOG=false`).

### Fixed (config correctness)
- `StatusTray.setup()` now always resets the config fast-hash at entry — previously, icon color changes during a no-rebuild path could leave stale cache and skip the color update.

## [1.0.5] - 2026-04-25

### Added (notable gameplay HUD features)
- Added a configurable `Compass` feature to the SimpleHUD runtime overlay (main-menu toggle + style controls).
- Added a configurable `Dynamic Crosshair` feature to the SimpleHUD runtime overlay (main-menu toggle + style controls).
- These are both beta features, and are available in a preset called "Beta" currently. I have tested them for hours each to try to make them as performant as possible via caching and other strategies, but if you notice performance impacts with these features (or this mod in general) it would be worth disabling them.

### Added (main-menu customization controls)
- Added a selectable `Fill empty space` option in the SimpleHUD menu for vitals strip layout behavior.
- Added FPS text customization toggle to hide/show the `FPS` label prefix in the HUD readout.
- Added map label customization modes (`default`, `map_only`, `region_only`) for FPS/map info display behavior.

### Added (runtime usability)
- Added a `Toggle HUD` hotkey/action to quickly show or hide the HUD layer during gameplay.

### Changed (runtime performance)
- Optimized dynamic crosshair rendering by caching draw-style values and reducing draw-call overhead.
- Reduced per-frame crosshair work by consolidating line rendering paths and avoiding repeated style parsing.

### Fixed (performance safety)
- Ensured compass/crosshair per-frame work is fully gated by feature toggles so disabled beta features do not run tick-time placement or update logic.
- Added layout-level guards to keep disabled compass/crosshair widgets hidden without running their expensive visibility/measurement paths.

### Fixed (vitals layout / alignment)
- Fixed vitals left/right column alignment so `Centered on edge` and trailing edge placement are computed from the active strip height reliably across resolutions.
- Fixed edge-case relayout caching where changes in active vitals participation could leave stale placement (including top-left fallback-like behavior).
- Improved vitals layout diagnostics (throttled, `godot.log` only) to include viewport/alignment/placement context for center and trailing paths.

## [1.0.4] - 2026-04-23

### Changed (runtime performance)
- Cached `user://Preferences.tres` reads with frame-based refresh to avoid per-frame resource reloads.
- Optimized status tray rendering to reuse icon nodes and cached textures instead of rebuilding/queue-freeing per refresh.
- Reduced per-frame UI churn by applying FPS label styling once per HUD bind and caching stat-widget scale/layout updates.
- Throttled background menu-install and GameData discovery probe cadence.

### Changed (logging behavior)
- Main diagnostic console logging is now disabled by default (`SIMPLEHUD_DIAG_LOG=false`, `SIMPLEHUD_MENU_PANEL_DIAG=false`).
- Warning-level messages for real error paths (invalid JSON, missing scripts, failed writes/loads) remain intact.

### Changed (main-menu vitals controls)
- Simplified `Transparency` selector to two options only: `Dynamic` and `Static`.
- Opacity percent input now appears only for `Static` mode.
- Legacy saved `opaque` mode is mapped to `Static` with `100%` opacity in the UI.

### Fixed
- Fixed stamina/fatigue threshold mismatch with unified vitals threshold expectations:
  - updated default/preset stamina+fatigue thresholds from `50` to `79` to match non-health vitals baseline
  - updated common-threshold UI sync to surface strictest value when mixed legacy thresholds exist

## [1.0.3] - 2026-04-23

### Changed (distribution model)
- Switched from multi-VMZ preset builds to a single package output: `mod/SimpleUI.vmz`.
- Build default preset is now baked from `presets/RadialPlainNoHide/Config.gd` into staged `SimpleHUD/Config.gd`.
- Runtime preset scripts are still shipped under `SimpleHUD/preset_configs/*.gd` for in-game preset switching.

### Changed (main-menu configuration UX)
- Main-menu SimpleHUD panel now supports end-to-end customization for vitals and ailments.
- Added collapsible UI sections: `Customize`, `Vitals`, and `Ailments` (all collapsed by default on open).
- Added `Current Preset` status row with fixed green label tint.
- Added live preset-state matching:
  - shows known preset label when config exactly matches
  - shows `User Customized` when config diverges
- Standardized vitals/ailments terminology and ordering (edge/order/padding/spacing/scale flow).

### Changed (vitals controls)
- Removed per-stat picker flow from UI; vitals apply in a unified panel flow.
- Added transparency mode selector:
  - `Dynamic`
  - `Static`
  - `Fixed opacity`
- Added fixed opacity percent control for static-opacity mode.
- Moved `Minimum display threshold` to top of vitals section and fixed sync behavior to show common threshold state across vitals.
- Added custom gradient threshold controls inline with RGB rows (High/Mid/Low now each include `Threshold`).

### Changed (ailments / NoHide defaults)
- Normalized NoHide preset status behavior to always-visible mode with explicit active/inactive styling:
  - active RGB `(150,0,0)` @ full opacity
  - inactive RGB `(255,255,255)` @ `25%` alpha
- Added support for status inactive color/alpha parse keys in config loading (`inactive_r/g/b`, `inactive_alpha`).

### Fixed
- Fixed panel background/card width mismatch by introducing viewport/content-aware relayout.
- Replaced unsupported `call_deferred(Callable)` usage with method-name deferred calls for compatibility with target GDScript runtime.
- Fixed startup preset-identification mismatch by initializing startup config from full preset defaults (`apply_full_preset_defaults()` in `load_all()`).

### Docs / repo maintenance
- Added exhaustive migration notes in `Docs/Dev-Notes.md`.
- Updated README and workshop description to reflect single-download + in-game customization model.
- Removed references to deprecated user-facing example JSON workflow.

## [1.0.2] - 2026-04-22

### Removed
- File logging: the mod no longer writes `SimpleHUD.log` or any dedicated log file on disk.
- `SimpleHudLog` and all diagnostics that existed only to populate that log (startup/HUD lifecycle messages, preferences and GameData snapshots, stamina/vitals trace output).

### Changed
- Dropped the `[general] log` config toggle and related settings load/defaults (logging is fully removed, not disabled).
- Optional user INI resolution now uses only `user://simplehud.ini`; removed `%APPDATA%` / `OS.get_environment` usage so the mod does not depend on Windows environment variables for paths.

## [1.0.1] - 2026-04-22

### Fixed
- Fixed stamina/fatigue UI spikes near exhaustion caused by mixed scale interpretation around `1.0`.
- Removed threshold-based runtime scale switching for stamina/fatigue that could produce jumps such as `1 -> 100`.

### Changed
- Hard-locked stamina/fatigue value handling to `percent_0_to_100` in `SimpleHUD` rendering logic.
- Updated stamina/fatigue tracing to deterministic domain reporting instead of inferred per-frame scale labels.

### Added
- Added configurable near-zero clamp for stamina/fatigue display in main config:
  - `[general] stamina_fatigue_near_zero_cutoff=1.0`
- Added policy-oriented stamina trace diagnostics:
  - deterministic domain field
  - near-zero state flag
  - active policy summary with cutoff value

### Notes
- This update addresses HUD presentation and diagnostics only; it does not change base game stamina simulation rules.


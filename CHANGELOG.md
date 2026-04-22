All downloads are for the latest versions only. Previous version can be built using the git history of the linked GitHub repository if needed.

# Changelog

All notable changes to `SimpleHUD` are documented in this file.

## [1.0.3] - 2026-04-23

### Changed (repository layout)
- Moved preset sources from `SimpleHUD/widgets/ConfigPresets/` to **`presets/<PresetName>/`** at the SimpleHUD project root so preset `Config.gd` files stay in a standalone tree next to the runtime package.

### Changed (VMZ packaging)
- Preset **VMZs no longer contain** the `Docs/` folder; workshop/developer markdown stays repo-only.
- VMZs **no longer duplicate** preset library folders inside the archive. The build still stages the shared `SimpleHUD/` runtime once per preset and **only copies** the chosen `presets/<Name>/Config.gd` into `SimpleHUD/Config.gd` before zipping.

### Fixed
- Avoided `class_name`-based type hints that could fail to parse when `HudOverlay.gd` compiled before dependent scripts in mod load order; overlay/widgets/radial wiring now relies on **preload-based types** for reliable autoload compilation.

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


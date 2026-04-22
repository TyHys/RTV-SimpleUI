# Changelog

All notable changes to `SimpleHUD` are documented in this file.

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


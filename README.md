# SimpleHUD (Developer README)

SimpleHUD is a configurable HUD framework mod for Road to Vostok.

This README is for maintainers/contributors.

## Current Product Model

SimpleHUD ships as **two VMZ variants**:

- `SimpleUI.vmz` — standard build; in-game main-menu button for all settings
- `SimpleUI-MCM.vmz` — MCM build; requires **Mod Configuration Menu** by Doink Oink; no main-menu button (MCM is the config surface)

Both use the same preset/config system and share `user://simplehud_preferences.json`.

The old multi-VMZ-per-preset distribution model is deprecated.

## 1.1.0 Release Notes

- Added **Show on Change**: when a vital drops by at least a configurable threshold %, it is forced fully visible for a configurable duration. Configurable in both main-menu panel and MCM.
- Added **Permadeath Icon**: configurable position (8 screen positions + Always Hide), scale %, and transparency %. Suppresses the vanilla HUD permadeath node when a position is chosen. Available in both main-menu panel and MCM.
- Show on Change activation immediately bypasses the fill-empty layout debounce, preventing brief overlap when adjacent vitals reposition.

## 1.0.6 Release Notes

- Added **Show All Vitals** hold-key: bypasses thresholds and transparency to show all vitals at full opacity while held.
- Added MCM integration variant (`SimpleUI-MCM.vmz`) with `SimpleHUD/MCM/SimpleHUDMCMConfig.gd` autoload.
- Internal performance pass: node caches, mtime-gated preference reads, fill-empty debounce, static array caches.
- Fixed `StatusTray` config fast-hash stale-cache bug on icon color changes without layout rebuild.
- Changed default `Toggle HUD` and `Show All Vitals` keybinds to **unassigned** (bind in Controls/MCM as preferred).

## Project Layout

- `mod.txt`  
  Mod metadata and autoload registration (`SimpleHUDMain`). Version matches current release.
- `mod_mcm.txt`  
  MCM build variant — registers `SimpleHUDMCM` before `SimpleHUDMain`; used by MCM VMZ build.
- `SimpleHUD/MCM/SimpleHUDMCMConfig.gd`  
  MCM autoload: signals MCM variant active, registers config sections with MCM, applies config changes.
- `SimpleHUD/Main.gd`  
  Runtime entrypoint; installs main-menu panel, applies/syncs settings, handles preset matching and persistence.
- `SimpleHUD/HudOverlay.gd`  
  Builds and updates vitals + status tray rendering.
- `SimpleHUD/SimpleHUDConfigCore.gd`  
  Core config model, defaults, parsing, and color/transparency logic.
- `SimpleHUD/UserPreferences.gd`  
  JSON merge + persistence for `user://simplehud_preferences.json`.
- `SimpleHUD/SimpleHUDSettingsPanel.gd`  
  Main-menu settings UI builder + event wiring.
- `SimpleHUD/PresetsRegistry.gd`  
  Runtime preset list and labels.
- `SimpleHUD/widgets/*`  
  UI widgets (`StatWidget`, `RadialStat`, `StatusTray`).
- `presets/<PresetName>/Config.gd`  
  Canonical preset source scripts (subclass `SimpleHUDConfigCore.gd`).
- `SimpleHUD/preset_configs/*.gd`  
  Build-generated runtime preset scripts (`res://SimpleHUD/preset_configs/...`) used by preset dropdown loading.
- `SimpleHUD.default.ini`  
  Packaged default INI (kept for fallback/layer support).
- `build_simplehud_vmz.sh`  
  Builds both `mod/SimpleUI.vmz` and `mod/SimpleUI-MCM.vmz` (default baked preset: `RadialPlainNoHide`).

## Build + Packaging

From `SimpleHUD/`:

```bash
./build_simplehud_vmz.sh
```

Build output:

- `mod/SimpleUI.vmz` — standard build (no MCM dependency, `SimpleHUD/MCM/` excluded)
- `mod/SimpleUI-MCM.vmz` — MCM build (`SimpleHUD/MCM/` included, `mod_mcm.txt` used as `mod.txt`)

CI output:

- GitHub Actions workflow `.github/workflows/simplehud-vmz.yml` builds the same outputs using the shell script.
- Every push/PR affecting `SimpleHUD/` uploads both VMZ artifacts.
- Tag builds (`v*` or `simplehud-v*`) attach both VMZ files to the GitHub Release.

Archive includes (both builds):

- `mod.txt` (standard: from `mod.txt`; MCM: from `mod_mcm.txt` renamed)
- `SimpleHUD.default.ini`
- `SimpleHUD/` runtime tree (standard excludes `SimpleHUD/MCM/`; MCM includes it)

Build behavior:

- copies each `presets/<Name>/Config.gd` into `SimpleHUD/preset_configs/<Name>.gd`
- copies default preset config into staged `SimpleHUD/Config.gd`
- produces both VMZs in a single run

`Docs/` is repository-only and is not included in VMZ.

## Runtime Configuration Flow

Startup:

- `SimpleHUDConfigCore.load_all()` uses `apply_full_preset_defaults()` first (ensures startup baseline matches preset signature logic).

Optional additional layers:

1. `res://SimpleHUD.default.ini` (if `LOAD_DEFAULT_INI`)
2. `user://simplehud.ini` (if `LOAD_USER_INI`)
3. `user://simplehud_preferences.json` (merged via `UserPreferences.gd`)

UI edits:

- in-game panel calls `Main.gd` apply methods
- every apply persists to `user://simplehud_preferences.json`
- HUD relayout/refresh happens immediately

## Presets and Current Preset Detection

Preset apply:

- load preset script from `PresetsRegistry.gd`
- call `apply_full_preset_defaults()`
- assign config and persist

Current preset display:

- panel shows either matching preset label or `User Customized`
- matching uses config signatures compared against each known preset script
- updates live after edits

## UI Structure (main menu)

Panel includes:

- Preset picker
- Current Preset row
- Expandables:
  - `Customize` (collapsed by default on open)
  - `Vitals` (collapsed by default on open)
  - `Ailments` (collapsed by default on open)

Ordering parity:

- vitals and ailments follow the same core control order (edge/order/padding/spacing/scale, then domain-specific controls)

## Feature Notes

- Vitals display modes: numeric or radial
- Vitals transparency modes: dynamic or static (static exposes an opacity percent control)
- Custom gradient supports high/mid/low RGB thresholds
- Status tray supports hidden/inflicted/always with active + inactive tint/alpha
- NoHide presets standardized to always-visible status behavior and explicit inactive styling
- Stamina/fatigue now use the same 79% visibility-threshold baseline as other non-health vitals (unless user-overridden)

## Runtime Notes

- Preferences reads are cached (no per-frame `Preferences.tres` reloads)
- Status tray icons are pooled and texture-cached instead of rebuilt each refresh
- FPS text styling is applied once per HUD bind instead of every update
- Debug print diagnostics default to off in release builds; warnings remain for real failure paths

## Reference Docs

- `Docs/Dev-Notes.md` - exhaustive migration details and implementation notes
- `Docs/Changelog.md` - release history
- `Docs/HUD-Map.md` - vanilla HUD mapping and data-source notes
- `Docs/Workshop-Description.md` - workshop listing copy

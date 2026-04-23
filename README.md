# SimpleHUD (Developer README)

SimpleHUD is a configurable HUD framework mod for Road to Vostok.

This README is for maintainers/contributors.

## Current Product Model

SimpleHUD now ships as a **single VMZ** with:

- runtime preset switching in the in-game main-menu SimpleHUD panel
- full user customization for vitals + ailments
- persistent user overrides saved to `user://simplehud_preferences.json`

The old multi-VMZ-per-preset distribution model is deprecated.

## Project Layout

- `mod.txt`  
  Mod metadata and autoload registration (`SimpleHUDMain`).
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
  Builds `mod/SimpleUI.vmz` (default baked preset: `RadialPlainNoHide`).

## Build + Packaging

From `SimpleHUD/`:

```bash
./build_simplehud_vmz.sh
```

Build output:

- `mod/SimpleUI.vmz`

Archive includes:

- `mod.txt`
- `SimpleHUD.default.ini`
- `SimpleHUD/` runtime tree

Build behavior:

- copies each `presets/<Name>/Config.gd` into `SimpleHUD/preset_configs/<Name>.gd`
- copies default preset config into staged `SimpleHUD/Config.gd`
- zips staged runtime as one VMZ

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
- Vitals transparency modes: dynamic / static (full) / fixed opacity
- Custom gradient supports high/mid/low RGB thresholds
- Status tray supports hidden/inflicted/always with active + inactive tint/alpha
- NoHide presets standardized to always-visible status behavior and explicit inactive styling

## Reference Docs

- `Docs/Dev-Notes.md` - exhaustive migration details and implementation notes
- `Docs/Changelog.md` - release history
- `Docs/HUD-Map.md` - vanilla HUD mapping and data-source notes
- `Docs/Workshop-Description.md` - workshop listing copy

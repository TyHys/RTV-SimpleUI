# SimpleHUD (Developer README)

SimpleHUD is a configurable HUD framework mod for Road to Vostok.

This README is for maintainers/contributors, not end users.

## Project Layout

- `mod.txt`  
  Mod metadata and autoload registration (`SimpleHUDMain`).
- `SimpleHUD/Main.gd`  
  Runtime entrypoint (autoload); binds to vanilla HUD, reads preferences, drives overlay; installs the **SimpleHUD** panel on the main menu (`Menu.tscn`).
- `SimpleHUD/HudOverlay.gd`  
  Builds and updates vitals/status UI, layout/positioning, alpha behavior.
- `SimpleHUD/SimpleHUDConfigCore.gd`  
  Configuration implementation (INI parsing, defaults, helpers, JSON merge hooks).
- `SimpleHUD/Config.gd`  
  Stable entrypoint loaded by `Main.gd`; repo default subclasses the core. VMZ builds replace only this file with a preset stub.
- `SimpleHUD/widgets/*`  
  UI widgets (`StatWidget`, `RadialStat`, `StatusTray`).
- `presets/<PresetName>/Config.gd`  
  Thin preset classes (subclass `SimpleHUDConfigCore.gd`). Build copies all into `SimpleHUD/preset_configs/` for the in-game preset list and injects the default preset as `SimpleHUD/Config.gd`.
- `SimpleHUD.default.ini`  
  Packaged default INI (included in VMZ build).
- `build_simplehud_vmz.sh`  
  Builds `mod/SimpleUI.vmz` (default preset: `RadialPlainNoHide`).

## Preset Model

Presets override `apply_defaults()` and/or `_embedded_defaults_ini()` (fallback INI string) via small scripts that extend `SimpleHUDConfigCore.gd`. Named variants include `TextNumericPlain`, `TextNumericColor`, `RadialPlain`, `RadialColor`, and `*NoHide` builds.

Players tune HUD layout and colors with optional `user://simplehud_preferences.json` (see `simplehud_preferences.example.json`; exhaustive merge keys live in `UserPreferences.gd`).

## Critical Config Behavior

`SimpleHUDConfigCore.gd` supports load layers after `apply_defaults()`:

1. `res://SimpleHUD.default.ini` (optional)
2. `user://simplehud.ini` (optional)
3. `user://simplehud_preferences.json` (optional; merged in `Main.gd` via `UserPreferences.gd`)

For strict preset behavior, this repo currently uses:

- `LOAD_DEFAULT_INI := false`
- `LOAD_USER_INI := false`

in active/preset configs, so pasted preset configs are authoritative and not overwritten by INI merges.

If you re-enable either flag, external INI values can override preset defaults.

## HUD Behavior Notes

- Vitals can render as text or radial donut charts per config.
- Visibility uses per-stat thresholds.
- Alpha scales by urgency (`1 - percent/100`) with optional floor (`min_stat_alpha_floor`).
- Status tray supports hidden/inflicted/always behavior and reads condition flags from `GameData`.

## Icon Loading (Important)

Radial icons are decoded via `Image` buffer loaders in `StatWidget.gd` (PNG/JPG/WebP/SVG), not plain `load("res://...")`.

Reason: in modded runtime, `ResourceLoader` may fail for some image paths/extensions in VMZ mounts. Byte-based decode is more reliable.

## Build + Package

From `SimpleHUD/`:

```bash
./build_simplehud_vmz.sh
```

Build output (`mod/`):

- `SimpleUI.vmz`

Each archive bundles only:

- `mod.txt`
- `SimpleHUD.default.ini`
- `SimpleHUD/` (runtime tree without preset sources)

Documentation under `Docs/` stays in the repo only—it is **not** copied into VMZs.

The default `presets/<DefaultPreset>/Config.gd` is copied onto `SimpleHUD/Config.gd`; every preset script is copied into `SimpleHUD/preset_configs/` (the `presets/` folders themselves are **not** included).

## Development Workflow

1. Choose target mode (text/radial + plain/color).
2. Edit active `SimpleHUD/Config.gd` or copy from `presets/<Name>/Config.gd`.
3. Verify in-game behavior (thresholds, alpha, placement, icon rendering).
4. Rebuild VMZs (`./build_simplehud_vmz.sh`).
5. Keep `SimpleHUD.default.ini` aligned with intended shipped default behavior.

## Reference Docs

- `Docs/HUD-Map.md` - vanilla HUD node mapping and data-source notes.
- `Docs/Workshop-Description.md` - workshop copy and screenshot links.

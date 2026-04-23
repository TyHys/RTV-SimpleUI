# SimpleHUD Dev Notes (Migration to UI + Stored Config)

This document captures the full migration from multi-build preset VMZ outputs to a single-build framework with in-game customization and persisted user settings.

## Scope of this migration

The project moved from:

- multiple downloadable VMZ files where each preset was effectively a separate shipped artifact
- preset selection mostly at build/distribution time

To:

- one shipped VMZ (`SimpleUI.vmz`)
- in-game preset switching from the main menu
- full runtime customization of vitals + ailments from the SimpleHUD panel
- persisted user changes in `user://simplehud_preferences.json`
- "Current Preset" detection that can distinguish known presets vs user-customized state

## Packaging changes

### Single output artifact

- `build_simplehud_vmz.sh` now builds one archive: `mod/SimpleUI.vmz`.
- Default baked preset for build is `RadialPlainNoHide` (`presets/RadialPlainNoHide/Config.gd` copied to staged `SimpleHUD/Config.gd`).

### Preset scripts still shipped for runtime switching

- Build still copies all preset source configs from `presets/<Name>/Config.gd` into `SimpleHUD/preset_configs/<Name>.gd`.
- `PresetsRegistry.gd` references those `res://SimpleHUD/preset_configs/*.gd` scripts for the dropdown.
- Result: one VMZ can still load any built-in preset at runtime.

## Runtime configuration model

### Canonical layers

`SimpleHUDConfigCore.gd` now initializes with full preset defaults at startup via:

- `load_all()` -> `apply_full_preset_defaults()`

Then optional merge layers (if enabled) are applied as before.

This startup behavior was critical for consistent preset matching (fresh install should identify as default preset, not "User Customized").

### Persisted user overrides

All UI edits persist into:

- `user://simplehud_preferences.json`

Persistence path is centralized via:

- `UserPreferences.persist_preferences_json(cfg)`

Key write/apply entrypoints in `Main.gd`:

- `apply_status_tray_settings_from_ui`
- `apply_vitals_strip_settings_from_ui`
- `apply_vitals_transparency_from_ui`
- `apply_stat_settings_to_all_from_ui`

## Main-menu panel architecture

### Panel host

`Main.gd` installs a SimpleHUD button and panel into `Menu.tscn` and builds UI through `SimpleHUDSettingsPanel.gd`.

### Layout and sizing

The card/background size is now dynamic:

- viewport-based width/height clamps
- relayout on panel open + viewport resize
- deferred relayout after controls are built so card width reflects actual content minimum width

This fixed the earlier issue where content was wider than the dark panel background.

### Expandable sections

The panel now has a hierarchy:

- `Customize` (collapsed by default on each open)
  - `Vitals` (collapsed by default on each open)
  - `Ailments` (collapsed by default on each open)

Section visibility is managed by tracked child index ranges in the settings panel builder.

## Preset UX and detection

### Preset selection

Preset dropdown still applies a preset by loading its script and calling:

- `apply_full_preset_defaults()`

Then persists that state.

### "Current Preset" status row

Panel now shows:

- `Current Preset: <Preset Label>` when config exactly matches a known preset
- `Current Preset: User Customized` otherwise

Color of preset name label is fixed to:

- `RGB(10,80,0)`

### Matching implementation

`Main.gd` computes a normalized signature of current config and each preset config (`_cfg_signature` + stable JSON string) and compares them.

Compared domains include:

- general transparency/numeric settings
- vitals layout and per-stat vitals settings
- status/ailments settings
- gradient/override settings

Panel refreshes current preset label:

- on sync/open
- after all apply handlers (vitals/status/transparency/stat edits)

## Vitals UI consolidation and terminology changes

### Consolidated behavior

- Vitals config applies to all stats together (no per-stat picker UI).
- Vitals spacing is controlled from one place (`Spacing between vitals`), matching the ailments UX style.

### Terminology cleanup

Updated labels include:

- `Order on edge`
- `Edge Padding (px)`
- `Minimum display threshold`
- `Transparency` -> `Dynamic`, `Static`, `Fixed opacity`

("Solid" wording was removed in favor of "Static".)

### Ordering parity with ailments

Vitals and ailments both follow the same conceptual order:

- Edge
- Order on edge
- Edge padding
- Spacing
- Scale
- then specialized controls

## Transparency model changes

Vitals transparency is now mutually exclusive mode-driven:

- `dynamic`: urgency-based alpha
- `opaque` (shown as "Static" in UI): fully opaque while visible
- `static`: fixed alpha from `vitals_static_opacity`

Fields introduced in `SimpleHUDConfigCore.gd`:

- `vitals_transparency_mode`
- `vitals_static_opacity`

Legacy fallback remains compatible through `min_stat_alpha_floor` interpretation.

## Gradient editor enhancements

Custom gradient editor now supports threshold controls inline with RGB rows:

- High RGB + Threshold
- Mid RGB + Threshold
- Low RGB + Threshold

Added support for low threshold in pipeline:

- UI build/sync + payload in `SimpleHUDSettingsPanel.gd`
- merge parsing in `UserPreferences.gd` (`low_threshold_pct`)
- color evaluation in `SimpleHUDConfigCore.gd`

Default for low threshold when absent:

- `0`

## Ailments / NoHide preset behavior changes

NoHide presets were normalized to explicit "always show" visuals:

- status mode `always`
- active RGB `(150,0,0)` at full opacity
- inactive RGB `(255,255,255)` at `0.25` alpha
- right-edge trailing alignment with vertical bottom-to-top order behavior via existing anchor/alignment mapping

Also added INI parse support for:

- `inactive_r`, `inactive_g`, `inactive_b`, `inactive_alpha` in `status_icons`

## Documentation and content cleanup during migration

- Deprecated/example helper JSON docs were removed from user-facing flow.
- References shifted to the in-game menu as the primary customization path.
- README/workshop/changelog updated for single-download + framework customization model.

## Compatibility notes

- This game/mod environment rejects `call_deferred(Callable)` in some builds; only `call_deferred(StringName, ...)` is safe.
- Any deferred panel relayout logic now uses named deferred methods.

## Known intent going forward

Single VMZ + runtime presets + persistent overrides is now the official direction.  
Preset scripts remain useful as:

- baseline style definitions
- deterministic build defaults
- runtime comparators for current-preset detection

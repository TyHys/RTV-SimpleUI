# SimpleHUD - Customizable HUD Framework


## 1.1.0 Update

- **Show on Change** — when a vital drops by at least a configurable percentage in a single tick, it is forced fully visible for a configurable duration. Toggle on/off; minimum drop % and duration are adjustable. Available in the main-menu panel and MCM.
- **Permadeath Icon** — configurable screen position for the permadeath skull icon (8 positions or Always Hide), with separate scale (%) and transparency (%) controls. When a position is set, the vanilla HUD permadeath node is suppressed and SimpleHUD draws the icon instead. Available in the main-menu panel and MCM.
- When Show on Change triggers, the fill-empty layout repositions immediately rather than waiting for the 200 ms debounce, avoiding a brief overlap with adjacent vitals.


## What This Mod Controls

- **Visibility logic:** show vitals and status icons only when they change or exceed a threshold, or keep them always visible.
- **Stat presentation:** numeric text or radial donut charts.
- **Threshold behavior:** configure the point at which each vital becomes visible.
- **Color logic:** preset colors, white-only, or a custom gradient with configurable high/mid/low thresholds and RGB values.
- **Transparency behavior:** dynamic urgency fading or static opacity with an adjustable percentage.
- **Show on Change:** force a vital visible for a set duration when it drops by a qualifying amount.
- **Layout:** edge placement, ordering, padding, spacing, scale, and fill-empty-space behavior for both vitals and ailments strips.
- **Ailment strip:** hidden/inflicted/always display modes with separate active and inactive tint and opacity controls.
- **Permadeath Icon:** screen position, scale, and transparency for the Vostok permadeath skull indicator.
- **Misc:** compass, dynamic crosshair, FPS label prefix toggle, map label display mode (`default`, `map_only`, `region_only`).
- **Runtime keys:** `Toggle HUD` and `Show All Vitals` bindable in Controls or MCM.


## Configuration

### Standard build (`SimpleUI.vmz`)

Open the main menu and click **SimpleHUD**:

- Pick a preset from the dropdown
- See **Current Preset** status (preset name or `User Customized`)
- Expand **Customize** to adjust:
  - **Vitals:** edge, alignment, spacing, fill-empty-space, thresholds, transparency mode, gradient, Show on Change
  - **Ailments:** edge, alignment, spacing, scale, auto-hide, fill-empty-space, active and inactive tint/opacity
  - **Misc:** permadeath icon position/scale/transparency, compass, dynamic crosshair, FPS label, map label mode

Changes apply live and persist across sessions.

### MCM build (`SimpleUI-MCM.vmz`)

Install this variant if **Mod Configuration Menu** by Doink Oink is installed. The main-menu button is suppressed; all settings are configured through the MCM panel instead. Both builds use the same settings file (`user://simplehud_preferences.json`) and are otherwise identical.


## Presets

All presets ship in the single package. Select via the in-game dropdown.

- **Radial, Color** [Screenshot](https://i.imgur.com/2DQ5A08.jpeg)
- **Radial, Plain** [Screenshot](https://i.imgur.com/y15br14.jpeg)
- **Text/Numeric, Color** [Screenshot](https://i.imgur.com/dcnM95H.jpeg)
- **Text/Numeric, Plain** [Screenshot](https://i.imgur.com/XMHXqOr.jpeg)
- **RadialColor, No Hide** [Screenshot](https://i.imgur.com/bspvrl14.jpeg)
- **RadialPlain, No Hide** [Screenshot](https://i.imgur.com/y8UcRwB.jpeg)
- **Text/Numeric, Color, No Hide** [Screenshot](https://i.imgur.com/A2Qutb0.jpeg)
- **Text/Numeric, Plain, No Hide** [Screenshot](https://i.imgur.com/oYguSZw.jpeg)

`NoHide` presets keep vitals always visible. `Color` presets use threshold-driven color transitions.


## Installation

### Standard build
1. Install **Metro Mod Loader** per its documentation.
2. Place `SimpleUI.vmz` in your mods directory.
3. Launch the game and confirm Metro Mod Loader reports `Simple HUD` as loaded.
4. Open the main menu and click **SimpleHUD** to select a preset or adjust settings.

### MCM build
1. Install **Metro Mod Loader** and **Mod Configuration Menu** by Doink Oink.
2. Place `SimpleUI-MCM.vmz` (not `SimpleUI.vmz`) in your mods directory.
3. Launch the game and configure SimpleHUD from the MCM menu.


## Version History (summary)

- **1.1.0:** Show on Change; Permadeath Icon with position/scale/transparency controls; immediate layout repositioning on SoC trigger.
- **1.0.6:** Show All Vitals hold-key; MCM integration variant; performance pass (node caches, mtime-gated file reads, debounced fill-empty layout).
- **1.0.5:** Compass and dynamic crosshair (beta); Fill Empty Space option; Toggle HUD keybind; FPS/map label controls.
- **1.0.4:** Preferences read caching; status tray icon pooling; simplified transparency selector; performance improvements.
- **1.0.3:** Single-VMZ distribution model; full in-game customization panel; ailments active/inactive styling.


## Saved Settings

`user://simplehud_preferences.json`

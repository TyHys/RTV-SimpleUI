# SimpleHUD - Customizable HUD Framework

SimpleHUD gives you a configurable HUD for Road to Vostok, using presets that can be further customized to the user.


## 1.0.6 Update Highlights

- **Show All Vitals** hold-key (default `-`): hold to force all vitals visible at full opacity, regardless of thresholds or transparency settings — useful when you need a quick status check without changing your config.
- **MCM release variant** (`SimpleUI-MCM.vmz`): optional build that integrates with **Mod Configuration Menu** by Doink Oink. Exposes Vitals, Ailments, Keybinds, and Misc settings directly inside the MCM menu. Requires MCM installed alongside it — standard `SimpleUI.vmz` is unchanged.
- **Internal performance pass**: per-frame node lookups, file reads, and array allocations are cached or rate-limited. Most notably: HUD child nodes cached at bind time, preferences file read only when mtime changes, fill-empty layout changes debounced at 200 ms.


## What This Framework Lets You Control

- **Visibility logic:** show vitals/status only when they matter, or keep them always visible.
- **Stat presentation:** numeric text or radial donuts.
- **Threshold behavior:** control when each vital becomes visible.
- **Color logic:** use preset colors, white-only styles, or configurable gradient behavior.
- **Transparency behavior:** dynamic urgency fading or static opacity with adjustable percentage.
- **Layout behavior:** tune edge placement, ordering, padding, spacing, scale, and `Fill empty space` behavior for both vitals and ailments.
- **Ailment behavior:** choose hidden/inflicted/always modes plus active and inactive tint/opacity styling.
- **Misc HUD behavior:** configure compass/crosshair options, FPS label visibility, and map-label mode (`default`, `map_only`, `region_only`).
- **Runtime control:** toggle HUD visibility with `Toggle HUD` (default `=`), or hold `Show All Vitals` (default `-`) to temporarily reveal all vitals at full opacity.

## In-Game Configuration (Main Menu — standard build)

Open the game main menu and click **SimpleHUD**:

- Pick any built-in preset from the preset dropdown
- See **Current Preset** status (`Preset Name` or `User Customized`)
- Expand **Customize** and tune:
  - **Vitals**: edge, order, spacing, `Fill empty space`, thresholds, transparency mode (dynamic/static + static opacity), gradient colors/thresholds
  - **Ailments**: edge/order, spacing/scale, active+inactive tint, inactive opacity, auto-hide, `Fill empty space`
  - **Misc**: compass, dynamic crosshair, FPS label prefix toggle, map label display mode

All changes apply live and save across sessions.

## MCM Variant (SimpleUI-MCM.vmz)

Install `SimpleUI-MCM.vmz` instead of `SimpleUI.vmz` if you also have **Mod Configuration Menu** by Doink Oink installed. The MCM variant exposes Vitals, Ailments, Keybinds, and Misc settings directly inside the MCM settings panel. The in-game main-menu button is suppressed in this variant — MCM is the single configuration surface.

Both variants use the same settings file (`user://simplehud_preferences.json`) and are otherwise identical.

## Preset Preview Screenshots

- **Radial, Color** [View screenshot](https://i.imgur.com/2DQ5A08.jpeg)
- **Radial, Plain** [View screenshot](https://i.imgur.com/y15br14.jpeg)
- **Text/Numeric, Color** [View screenshot](https://i.imgur.com/dcnM95H.jpeg)
- **Text/Numeric, Plain** [View screenshot](https://i.imgur.com/XMHXqOr.jpeg)
- **RadialColor, No Hide** [View screenshot](https://i.imgur.com/bspvrl14.jpeg)
- **RadialPlain, No Hide** [View screenshot](https://i.imgur.com/y8UcRwB.jpeg)
- **Text/Numeric, Color, No Hide** [View screenshot](https://i.imgur.com/A2Qutb0.jpeg)
- **Text/Numeric, Plain, No Hide** [View screenshot](https://i.imgur.com/oYguSZw.jpeg)

> **Note:** These screenshots show style baselines included in the single package.  
> `NoHide` styles prioritize always-on readability. `Color` styles use configurable threshold-driven color transitions.

## How To Install

### Standard build
1. Install **Metro Mod Loader** (follow its official installation steps and requirements).
2. Place `SimpleUI.vmz` in your Road to Vostok mods directory used by Metro Mod Loader.
3. Launch the game and verify Metro Mod Loader reports `Simple HUD` as loaded.
4. Open the main menu and click **SimpleHUD** to choose a preset or customize.

### MCM build
1. Install **Metro Mod Loader** and **Mod Configuration Menu** by Doink Oink.
2. Place `SimpleUI-MCM.vmz` (not `SimpleUI.vmz`) in your mods directory.
3. Launch the game. Configure SimpleHUD from the MCM menu.

For loader setup details, troubleshooting, and path specifics, refer to Metro Mod Loader documentation.

## Recent Improvements

- **1.0.6:** Show All Vitals hold-key bypasses thresholds/transparency to reveal all vitals instantly while held.
- **1.0.6:** MCM integration variant (`SimpleUI-MCM.vmz`) lets MCM users configure SimpleHUD without a separate main-menu panel.
- **1.0.6:** Internal performance pass — node caches, mtime-gated file reads, debounced fill-empty layout, and static array caches across HudOverlay and StatusTray.
- **1.0.5:** Dynamic crosshair rendering further optimized; disabled beta features fully skip per-frame update paths.
- **1.0.5:** Vitals edge alignment and relayout behavior hardened to prevent stale corner placement in edge cases.
- Runtime overhead reduced with cached preferences reads and pooled status icon rendering.
- Stamina/fatigue now share the same default threshold behavior as other non-health vitals.
- Debug diagnostics are quieter by default while preserving warning/error visibility.

If you like evolving your HUD over time, this framework is designed to grow with your setup instead of forcing one static UI. If there is a behavior you want that is not possible yet, reach out and I can expand the framework.

## Saved Settings

SimpleHUD stores user changes in:

- `user://simplehud_preferences.json`

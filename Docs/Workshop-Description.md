# SimpleHUD - Customizable HUD Framework

SimpleHUD gives you a configurable HUD for Road to Vostok, using presets that can be futher customized to the user.

This workshop release ships as **one download** (`SimpleUI.vmz`) with:

- built-in presets
- live in-game configuration
- persistent per-player customization

## 1.0.5 Update Highlights

- Dynamic Crosshair has additional rendering/per-frame optimization to further reduce overhead.
- Compass and Dynamic Crosshair are now clearly marked as beta in the settings panel (italic yellow `*Beta`).
- If Compass and/or Dynamic Crosshair are disabled, their update paths are skipped to reduce risk of impacting core HUD performance.

## What This Framework Lets You Control

- **Visibility logic:** show vitals/status only when they matter, or keep them always visible.
- **Stat presentation:** numeric text or radial donuts.
- **Threshold behavior:** control when each vital becomes visible.
- **Color logic:** use preset colors, white-only styles, or configurable gradient behavior.
- **Transparency behavior:** dynamic urgency fading or static opacity with adjustable percentage.
- **Layout behavior:** tune edge placement, ordering, padding, spacing, and scale for both vitals and ailments.
- **Ailment behavior:** choose hidden/inflicted/always modes plus active and inactive tint/opacity styling.

## In-Game Configuration (Main Menu)

Open the game main menu and click **SimpleHUD**:

- Pick any built-in preset from the preset dropdown
- See **Current Preset** status (`Preset Name` or `User Customized`)
- Expand **Customize** and tune:
  - **Vitals**: edge, order, spacing, thresholds, transparency mode (dynamic/static + static opacity), gradient colors/thresholds
  - **Ailments**: edge/order, spacing/scale, active+inactive tint, inactive opacity

All changes apply live and save across sessions.

## Preset Preview Screenshots

- **Radial, Color** [View screenshot](https://i.imgur.com/2DQ5A08.jpeg)
- **Radial, Plain** [View screenshot](https://i.imgur.com/y15br14.jpeg)
- **Text/Numeric, Color** [View screenshot](https://i.imgur.com/dcnM95H.jpeg)
- **Text/Numeric, Plain** [View screenshot](https://i.imgur.com/XMHXqOr.jpeg)
- **RadialColor, No Hide** [View screenshot](https://i.imgur.com/bspvrl4.jpeg)
- **RadialPlain, No Hide** [View screenshot](https://i.imgur.com/y8UcRwB.jpeg)
- **Text/Numeric, Color, No Hide** [View screenshot](https://i.imgur.com/A2Qutb0.jpeg)
- **Text/Numeric, Plain, No Hide** [View screenshot](https://i.imgur.com/oYguSZw.jpeg)

> **Note:** These screenshots show style baselines included in the single package.  
> `NoHide` styles prioritize always-on readability. `Color` styles use configurable threshold-driven color transitions.

## How To Install

1. Install **Metro Mod Loader** (follow its official installation steps and requirements).
2. Place `SimpleUI.vmz` in your Road to Vostok mods directory used by Metro Mod Loader.
3. Launch the game and verify Metro Mod Loader reports `Simple HUD` as loaded.
4. Open the main menu and click **SimpleHUD** to choose a preset or customize.

For loader setup details, troubleshooting, and path specifics, refer to Metro Mod Loader documentation.

## Recent Improvements

- **1.0.5:** Dynamic crosshair rendering is further optimized to lower draw/update overhead.
- **1.0.5:** Compass and dynamic crosshair are clearly marked as beta in the settings panel (`*Beta`).
- **1.0.5:** When compass/crosshair are disabled, their runtime update paths are skipped to minimize performance impact.
- Runtime overhead reduced with cached preferences reads and pooled status icon rendering.
- Stamina/fatigue now share the same default threshold behavior as other non-health vitals.
- Debug diagnostics are quieter by default while preserving warning/error visibility.

If you like evolving your HUD over time, this framework is designed to grow with your setup instead of forcing one static UI. If there is a behavior you want that is not possible yet, reach out and I can expand the framework.

## Saved Settings

SimpleHUD stores user changes in:

- `user://simplehud_preferences.json`
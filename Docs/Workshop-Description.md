# SimpleHUD - Modular HUD Framework

SimpleHUD is a **HUD framework** for Road to Vostok designed for players who want to customize the core HUD elements using a core set of common tools and configurations.

This workshop release now ships as **one download** (`SimpleUI.vmz`) with built-in presets and an in-game configuration menu.

## How The UI Works

SimpleHUD focuses on readable, context-driven information:

- **Unneeded clutter is hidden:** stats and status elements can stay out of view until they matter (based on configured thresholds and status conditions).
- **Affliction/status icons are context-aware:** by default, only active/afflicted conditions are shown in the status tray.
- **Transparency options are flexible:** use dynamic urgency-based fading, static full visibility, or fixed-opacity vitals.
- **Two stat display styles:** choose either numeric text values or icon-centered radial donut charts (think stamina bars from Breath of the Wild).
- **NoHide-style behavior available:** presets and UI settings support always-visible, high-readability variants.

## In-Game Configuration (Main Menu)

Open the game main menu and click **SimpleHUD**:

- Pick any built-in preset from the preset dropdown
- See **Current Preset** status (`Preset Name` or `User Customized`)
- Expand **Customize** and tune:
  - **Vitals**: edge, order, spacing, thresholds, transparency mode, gradient colors/thresholds
  - **Ailments**: edge/order, spacing/scale, active+inactive tint, inactive opacity

All changes apply live and are saved per-player.

## Saved Settings

SimpleHUD stores user changes in:

- `user://simplehud_preferences.json`

This is in the game's user-data/appdata location (not in the Steam install directory).

## Preset Preview Screenshots

- **RadialColor** [View screenshot](https://i.imgur.com/JiJhTxs.jpeg)
- **RadialPlain** [View screenshot](https://i.imgur.com/vIVukmX.jpeg)
- **TextNumericColor** [View screenshot](https://i.imgur.com/zOtEZyy.jpeg)
- **TextNumericPlain** [View screenshot](https://i.imgur.com/KS9XR07.jpeg)
- **RadialColorNoHide** [View screenshot](https://i.imgur.com/3BJlOwj.jpeg)
- **RadialPlainNoHide** [View screenshot](https://i.imgur.com/EVE1cFA.jpeg)
- **TextNumericColorNoHide** [View screenshot](https://i.imgur.com/rUnAw5S.jpeg)
- **TextNumericPlainNoHide** [View screenshot](https://i.imgur.com/q0LktUb.jpeg)

> **Note:** These screenshots show style baselines included in the single package.  
> `NoHide` styles prioritize always-on readability. `Color` styles use configurable threshold-driven color transitions.

## How To Choose

Start from the preset that looks closest to what you want, then fine-tune inside the SimpleHUD menu.

## Framework-First Design

SimpleHUD is built to be a configurable foundation:

- per-stat visibility thresholds
- radial vs numeric presentation
- text/radial color behavior
- transparency behavior
- HUD placement and spacing controls
- status icon and info layout controls

If you like to tune your HUD over time, this framework is meant to grow with your setup rather than lock you into one static style. If you have a vision for a HUD you feel is not possible with the current framework, please feel free to reach out to me. I would be willing to expand this featureset given the right vision.


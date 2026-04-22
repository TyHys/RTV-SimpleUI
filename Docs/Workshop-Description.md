# SimpleHUD - Modular HUD Framework

SimpleHUD is a **HUD framework** for Road to Vostok designed for players who want to customize the core HUD elements using a core set of common tools and configurations.

To demonstrate, this workshop release includes **8 preset variants** (each uploaded as a separate download), built on the same framework core. I have included screenshots which will detail the name of the preset, so that you can review and select a preset.

## How The UI Works

SimpleHUD focuses on readable, context-driven information:

- **Unneeded clutter is hidden:** stats and status elements can stay out of view until they matter (based on configured thresholds and status conditions).
- **Affliction/status icons are context-aware:** by default, only active/afflicted conditions are shown in the status tray.
- **Transparency scales with urgency:** elements become more visible as values get worse, helping critical info stand out naturally.
- **Two stat display styles:** choose either numeric text values or icon-centered radial donut charts (think stamina bars from Breath of the Wild).
- **NoHide variants available:** these presets keep Health/Energy/Hydration/Mental/Temp/Stamina/Fatigue always visible and disable dynamic stat fading (full visibility at all times).

## Preset Preview Screenshots

- **RadialColor** [View screenshot](https://i.imgur.com/JiJhTxs.jpeg)
- **RadialPlain** [View screenshot](https://i.imgur.com/vIVukmX.jpeg)
- **TextNumericColor** [View screenshot](https://i.imgur.com/zOtEZyy.jpeg)
- **TextNumericPlain** [View screenshot](https://i.imgur.com/KS9XR07.jpeg)
- **RadialColorNoHide** [View screenshot](https://i.imgur.com/3BJlOwj.jpeg)
- **RadialPlainNoHide** [View screenshot](https://i.imgur.com/EVE1cFA.jpeg)
- **TextNumericColorNoHide** [View screenshot](https://i.imgur.com/rUnAw5S.jpeg)
- **TextNumericPlainNoHide** [View screenshot](https://i.imgur.com/q0LktUb.jpeg)

> **Note:** These are separate downloads for convenience, but functionally the main difference between presets is the values defined in `SimpleHUD/Config.gd`.
> `NoHide` presets are tuned for always-on, full-opacity stat readability. `Color` presets will gradually change colors to alert the user as the value approaches configurable threshold values.

## How To Choose

Please review the **current screenshots** on this workshop page and pick the preset that best fits your readability preference and visual style.

## Framework-First Design

SimpleHUD is built to be a configurable foundation:

- per-stat visibility thresholds
- radial vs numeric presentation
- text/radial color behavior
- transparency behavior
- HUD placement and spacing controls
- status icon and info layout controls

If you like to tune your HUD over time, this framework is meant to grow with your setup rather than lock you into one static style. If you have a vision for a HUD you feel is not possible with the current framework, please feel free to reach out to me. I would be willing to expand this featureset given the right vision.


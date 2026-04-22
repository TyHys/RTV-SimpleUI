# Vanilla HUD discovery (Road to Vostok)

References from `Auxillary/References/Game/Road to Vostok/` — paths may shift with game updates.

**Resolve the gameplay HUD Control** (same as vanilla): from `get_tree().current_scene`, try **`/root/Map/Core/UI/HUD`** (see `WeaponRig.gd`, `Loader.gd`), then **`Core/UI/HUD`** when the scene root is the `Map` node (e.g. `Scenes/Tent.tscn`). Also try relative `Map/Core/UI/HUD` from `get_tree().root`, then a small recursive search for a Control named `HUD` with `Stats` + `Info` (avoids picking unrelated `HUD` nodes under Settings).

## Anchors

| Purpose | Relative from tree root | Script |
|---------|-------------------------|--------|
| UI root | `Map/Core/UI` | `UIManager.gd` |
| HUD | `Map/Core/UI/HUD` | `HUD.gd` |
| Interface panel | `Map/Core/UI/Interface` | `Interface.gd` |

## HUD nodes used by Simple HUD

- **FPS + map / location:** `HUD/Info` (`GridContainer`). Children: `Map` (`Label`), `FPS` (`Label`) with child `Frames` (`Label`).
- **Vitals strip:** `HUD/Stats/Vitals` — hidden by mod; stats come from `GameData` (`health`, `energy`, `hydration`, `mental`, `temperature`, `bodyStamina`, `armStamina`).
- **Vital behaviour:** `Scripts/Vital.gd` — enums `Health`, `Energy`, `Hydration`, `Mental`, `Temperature`, `BodyStamina`, `ArmStamina`, etc.
- **Medical row:** `HUD/Stats/Medical/Elements/*` (`TextureRect` + `Condition.gd`) — hidden by mod; flags read from `GameData` (`overweight`, `starvation`, … `headshot`).
- **Oxygen:** `HUD/Stats/Oxygen` — left visible (swimming UI).

## Data source

Shared `preload("res://Resources/GameData.tres")` / `GameData` resource properties match `Scripts/GameData.gd`.

## Escape menu / Settings HUD toggles

Saved in **`user://Preferences.tres`** (`Scripts/Preferences.gd`). **Settings** (`Scripts/Settings.gd`) wires the HUD row toggles to:

- `HUD.ShowMap(preferences.map)` → `HUD/Info/Map`
- `HUD.ShowFPS(preferences.FPS)` → `HUD/Info/FPS` (and child `Frames`)
- `HUD.ShowVitals(preferences.vitals)` → `HUD/Stats/Vitals`
- `HUD.ShowMedical(preferences.medical)` → `HUD/Stats/Medical`

Simple HUD reads the same preferences file each frame: when **vitals** / **medical** are on, it hides the vanilla strip and draws its replacement; when off, it leaves vanilla visibility alone and hides its own widgets. **`[fps_map]`** scales / moves / modulates **`HUD/Info`**; Map/FPS visibility still follows the escape-menu toggles (vanilla `ShowMap` / `ShowFPS`).

extends "res://SimpleHUD/SimpleHUDConfigCore.gd"

## Public script that `Main.gd` instantiates (`SimpleHUDConfigScript.new()`).
##
## Implementation lives in `SimpleHUDConfigCore.gd`. This file exists so:
## - The path `res://SimpleHUD/Config.gd` stays stable for tools and docs.
## - `./build_simplehud_vmz.sh` can overwrite **this file only** with `presets/<Preset>/Config.gd`,
##   injecting a visual preset (subclass of the core) without touching the core implementation.
##
## Players should not edit GDScript; use the in-game SimpleHUD main-menu panel for customization.

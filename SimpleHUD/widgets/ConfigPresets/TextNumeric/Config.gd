extends RefCounted

## Snapshot preset config for TextNumeric.
## Stored here as a copy reference; live config is loaded from res://SimpleHUD/Config.gd.

const DEFAULT_RES := "res://SimpleHUD.default.ini"

## Godot ConfigFile does not allow `#` comments; keep file and this string in sync (used if res load fails).
const EMBEDDED_DEFAULTS_INI := """[general]
enabled=true
min_stat_alpha_floor=0
log=true
numeric_only=true
[health]
visible_threshold=101.0
radial=false
[energy]
visible_threshold=79.0
radial=false
[hydration]
visible_threshold=79.0
radial=false
[mental]
visible_threshold=79.0
radial=false
[body_temp]
visible_threshold=79.0
radial=false
[stamina]
visible_threshold=50.0
radial=false
[fatigue]
visible_threshold=50.0
radial=false
[status_icons]
mode=\"inflicted_only\"
corner=\"bottom_right\"
spacing_px=2
icon_scale=0.12
icon_size_px=32
stack_direction=\"vertical_up\"
margin_right=5
margin_bottom=5
color_r=120
color_g=0
color_b=0
[fps_map]
alpha=0.5
scale=0.81
anchor=\"top_left\"
offset_x=4
offset_y=4
[vitals_layout]
margin_left=8
margin_bottom=5
strip_width_px=960
row_height_px=36
[stat_text_colors]
mode=\"gradient\"
high_start_pct=75
mid_pct=50
high_r=255
high_g=255
high_b=255
mid_r=120
mid_g=110
mid_b=0
low_r=120
low_g=0
low_b=0
"""

const STAT_HEALTH := &"health"
const STAT_ENERGY := &"energy"
const STAT_HYDRATION := &"hydration"
const STAT_MENTAL := &"mental"
const STAT_BODY_TEMP := &"body_temp"
const STAT_STAMINA := &"stamina"
const STAT_FATIGUE := &"fatigue"

const STAT_IDS: Array[StringName] = [
	STAT_HEALTH,
	STAT_ENERGY,
	STAT_HYDRATION,
	STAT_MENTAL,
	STAT_BODY_TEMP,
	STAT_STAMINA,
	STAT_FATIGUE,
]

var enabled: bool = true

var radial: Dictionary = {} # stat_id -> bool
var visible_threshold: Dictionary = {} # stat_id -> float

var status_mode: String = "inflicted_only"
var status_corner: String = "bottom_right"
var status_spacing_px: float = 2.0
var status_icon_scale: float = 0.12
var status_icon_size_px: float = 32.0
var status_stack_direction: String = "vertical_up"
var status_margin_right: float = 5.0
var status_margin_bottom: float = 5.0
var status_color_r: int = 120
var status_color_g: int = 0
var status_color_b: int = 0

var fps_map_alpha: float = 0.5
var fps_map_scale: float = 0.81
var fps_map_anchor: String = "top_left"
var fps_map_offset_x: float = 4.0
var fps_map_offset_y: float = 4.0

var vitals_margin_left: float = 8.0
var vitals_margin_bottom: float = 5.0
var vitals_strip_width_px: float = 960.0
var vitals_row_height_px: float = 36.0
var stat_text_color_mode: String = "gradient" # gradient | white_only
var stat_text_high_start_pct: float = 75.0
var stat_text_mid_pct: float = 50.0
var stat_text_high_r: int = 255
var stat_text_high_g: int = 255
var stat_text_high_b: int = 255
var stat_text_mid_r: int = 120
var stat_text_mid_g: int = 110
var stat_text_mid_b: int = 0
var stat_text_low_r: int = 120
var stat_text_low_g: int = 0
var stat_text_low_b: int = 0

var min_stat_alpha_floor: float = 0.0
var log_enabled: bool = true
var numeric_only: bool = true


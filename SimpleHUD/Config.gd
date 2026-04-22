extends RefCounted

## Full preset config (drop-in replacement for res://SimpleHUD/Config.gd).

const DEFAULT_RES := "res://SimpleHUD.default.ini"
const LOAD_DEFAULT_INI := false
const LOAD_USER_INI := false

## Godot ConfigFile does not allow `#` comments; keep file and this string in sync (used if res load fails).
const EMBEDDED_DEFAULTS_INI := """[general]
enabled=true
min_stat_alpha_floor=0
log=true
numeric_only=false
stamina_fatigue_near_zero_cutoff=1.0
[health]
visible_threshold=101.0
radial=true
[energy]
visible_threshold=79.0
radial=true
[hydration]
visible_threshold=79.0
radial=true
[mental]
visible_threshold=79.0
radial=true
[body_temp]
visible_threshold=79.0
radial=true
[stamina]
visible_threshold=50.0
radial=true
[fatigue]
visible_threshold=50.0
radial=true
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
mid_r=190
mid_g=190
mid_b=15
low_r=200
low_g=25
low_b=15
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
var stat_text_mid_r: int = 190
var stat_text_mid_g: int = 190
var stat_text_mid_b: int = 15
var stat_text_low_r: int = 200
var stat_text_low_g: int = 25
var stat_text_low_b: int = 15

## When non-health stats are visible, floor modulate.a so bars near ~70% are still readable (pure 1-p/100 is often ~0.3 alpha).
var min_stat_alpha_floor: float = 0.0

var log_enabled: bool = true

## When true, vitals always use text labels (ignores per-stat radial in INI).
var numeric_only: bool = false
## Clamp stamina/fatigue display to 0 when value is below this percent value.
var stamina_fatigue_near_zero_cutoff: float = 1.0

var _loaded_user_path: String = ""

func load_all() -> void:
	apply_defaults()
	if LOAD_DEFAULT_INI:
		_load_file(DEFAULT_RES, false)
	var user_path := _resolve_user_ini_path()
	if LOAD_USER_INI && user_path != "" && FileAccess.file_exists(user_path):
		_loaded_user_path = user_path
		_load_file(user_path, true)
	else:
		_loaded_user_path = ""

func _resolve_user_ini_path() -> String:
	if OS.has_feature("windows"):
		var appdata := OS.get_environment("APPDATA")
		if appdata != "":
			var p := appdata.path_join("Road to Vostok").path_join("simplehud.ini")
			return p
	return "user://simplehud.ini"

func _load_file(path: String, merge: bool) -> void:
	var cf := ConfigFile.new()
	var err := cf.load(path)
	if err != OK:
		if !merge && path == DEFAULT_RES:
			err = cf.parse(EMBEDDED_DEFAULTS_INI)
			if err == OK:
				push_warning("SimpleHUD: loaded embedded defaults (could not parse %s)" % DEFAULT_RES)
				_apply_config_file(cf, false)
				return
		if !merge:
			push_warning("SimpleHUD: could not load defaults at %s (err %s)" % [path, err])
		return

	_apply_config_file(cf, merge)


func _apply_config_file(cf: ConfigFile, _merge: bool) -> void:
	if cf.has_section_key("general", "enabled"):
		enabled = bool(cf.get_value("general", "enabled"))
	if cf.has_section_key("general", "min_stat_alpha_floor"):
		min_stat_alpha_floor = clampf(float(cf.get_value("general", "min_stat_alpha_floor")), 0.0, 1.0)
	if cf.has_section_key("general", "log"):
		log_enabled = bool(cf.get_value("general", "log"))
	if cf.has_section_key("general", "numeric_only"):
		numeric_only = bool(cf.get_value("general", "numeric_only"))
	if cf.has_section_key("general", "stamina_fatigue_near_zero_cutoff"):
		stamina_fatigue_near_zero_cutoff = clampf(float(cf.get_value("general", "stamina_fatigue_near_zero_cutoff")), 0.0, 5.0)

	for stat_id in STAT_IDS:
		var sec := stat_id
		if cf.has_section(sec):
			if cf.has_section_key(sec, "visible_threshold"):
				visible_threshold[stat_id] = float(cf.get_value(sec, "visible_threshold"))
			if cf.has_section_key(sec, "radial"):
				radial[stat_id] = bool(cf.get_value(sec, "radial"))

	if cf.has_section("status_icons"):
		if cf.has_section_key("status_icons", "mode"):
			status_mode = str(cf.get_value("status_icons", "mode"))
		if cf.has_section_key("status_icons", "corner"):
			status_corner = str(cf.get_value("status_icons", "corner"))
		if cf.has_section_key("status_icons", "spacing_px"):
			status_spacing_px = clampf(float(cf.get_value("status_icons", "spacing_px")), 0.0, 64.0)
		if cf.has_section_key("status_icons", "icon_scale"):
			status_icon_scale = clampf(float(cf.get_value("status_icons", "icon_scale")), 0.05, 4.0)
		if cf.has_section_key("status_icons", "icon_size_px"):
			status_icon_size_px = clampf(float(cf.get_value("status_icons", "icon_size_px")), 8.0, 128.0)
		if cf.has_section_key("status_icons", "stack_direction"):
			status_stack_direction = str(cf.get_value("status_icons", "stack_direction"))
		if cf.has_section_key("status_icons", "margin_right"):
			status_margin_right = clampf(float(cf.get_value("status_icons", "margin_right")), 0.0, 256.0)
		if cf.has_section_key("status_icons", "margin_bottom"):
			status_margin_bottom = clampf(float(cf.get_value("status_icons", "margin_bottom")), 0.0, 256.0)
		if cf.has_section_key("status_icons", "color_r"):
			status_color_r = clampi(int(cf.get_value("status_icons", "color_r")), 0, 255)
		if cf.has_section_key("status_icons", "color_g"):
			status_color_g = clampi(int(cf.get_value("status_icons", "color_g")), 0, 255)
		if cf.has_section_key("status_icons", "color_b"):
			status_color_b = clampi(int(cf.get_value("status_icons", "color_b")), 0, 255)

	if cf.has_section("fps_map"):
		if cf.has_section_key("fps_map", "alpha"):
			fps_map_alpha = clampf(float(cf.get_value("fps_map", "alpha")), 0.0, 1.0)
		if cf.has_section_key("fps_map", "scale"):
			fps_map_scale = clampf(float(cf.get_value("fps_map", "scale")), 0.1, 3.0)
		if cf.has_section_key("fps_map", "anchor"):
			fps_map_anchor = str(cf.get_value("fps_map", "anchor"))
		if cf.has_section_key("fps_map", "offset_x"):
			fps_map_offset_x = clampf(float(cf.get_value("fps_map", "offset_x")), 0.0, 256.0)
		if cf.has_section_key("fps_map", "offset_y"):
			fps_map_offset_y = clampf(float(cf.get_value("fps_map", "offset_y")), 0.0, 256.0)

	if cf.has_section("vitals_layout"):
		if cf.has_section_key("vitals_layout", "margin_left"):
			vitals_margin_left = clampf(float(cf.get_value("vitals_layout", "margin_left")), 0.0, 256.0)
		if cf.has_section_key("vitals_layout", "margin_bottom"):
			vitals_margin_bottom = clampf(float(cf.get_value("vitals_layout", "margin_bottom")), 0.0, 256.0)
		if cf.has_section_key("vitals_layout", "strip_width_px"):
			vitals_strip_width_px = clampf(float(cf.get_value("vitals_layout", "strip_width_px")), 120.0, 4096.0)
		if cf.has_section_key("vitals_layout", "row_height_px"):
			vitals_row_height_px = clampf(float(cf.get_value("vitals_layout", "row_height_px")), 16.0, 256.0)

	if cf.has_section("stat_text_colors"):
		if cf.has_section_key("stat_text_colors", "mode"):
			stat_text_color_mode = str(cf.get_value("stat_text_colors", "mode"))
		if cf.has_section_key("stat_text_colors", "high_start_pct"):
			stat_text_high_start_pct = clampf(float(cf.get_value("stat_text_colors", "high_start_pct")), 0.0, 100.0)
		if cf.has_section_key("stat_text_colors", "mid_pct"):
			stat_text_mid_pct = clampf(float(cf.get_value("stat_text_colors", "mid_pct")), 0.0, 100.0)
		if cf.has_section_key("stat_text_colors", "high_r"):
			stat_text_high_r = clampi(int(cf.get_value("stat_text_colors", "high_r")), 0, 255)
		if cf.has_section_key("stat_text_colors", "high_g"):
			stat_text_high_g = clampi(int(cf.get_value("stat_text_colors", "high_g")), 0, 255)
		if cf.has_section_key("stat_text_colors", "high_b"):
			stat_text_high_b = clampi(int(cf.get_value("stat_text_colors", "high_b")), 0, 255)
		if cf.has_section_key("stat_text_colors", "mid_r"):
			stat_text_mid_r = clampi(int(cf.get_value("stat_text_colors", "mid_r")), 0, 255)
		if cf.has_section_key("stat_text_colors", "mid_g"):
			stat_text_mid_g = clampi(int(cf.get_value("stat_text_colors", "mid_g")), 0, 255)
		if cf.has_section_key("stat_text_colors", "mid_b"):
			stat_text_mid_b = clampi(int(cf.get_value("stat_text_colors", "mid_b")), 0, 255)
		if cf.has_section_key("stat_text_colors", "low_r"):
			stat_text_low_r = clampi(int(cf.get_value("stat_text_colors", "low_r")), 0, 255)
		if cf.has_section_key("stat_text_colors", "low_g"):
			stat_text_low_g = clampi(int(cf.get_value("stat_text_colors", "low_g")), 0, 255)
		if cf.has_section_key("stat_text_colors", "low_b"):
			stat_text_low_b = clampi(int(cf.get_value("stat_text_colors", "low_b")), 0, 255)

func apply_defaults() -> void:
	enabled = true
	radial.clear()
	visible_threshold.clear()
	for id in STAT_IDS:
		match id:
			STAT_HEALTH:
				visible_threshold[id] = 101.0
			STAT_STAMINA, STAT_FATIGUE:
				visible_threshold[id] = 50.0
			_:
				visible_threshold[id] = 79.0
		radial[id] = true
	status_mode = "inflicted_only"
	status_corner = "bottom_right"
	status_spacing_px = 2.0
	status_icon_scale = 0.12
	status_icon_size_px = 32.0
	status_stack_direction = "vertical_up"
	status_margin_right = 5.0
	status_margin_bottom = 5.0
	status_color_r = 120
	status_color_g = 0
	status_color_b = 0
	fps_map_alpha = 0.5
	fps_map_scale = 0.81
	fps_map_anchor = "top_left"
	fps_map_offset_x = 4.0
	fps_map_offset_y = 4.0
	min_stat_alpha_floor = 0.0
	log_enabled = true
	numeric_only = false
	stamina_fatigue_near_zero_cutoff = 1.0
	vitals_margin_left = 8.0
	vitals_margin_bottom = 5.0
	vitals_strip_width_px = 960.0
	vitals_row_height_px = 36.0
	stat_text_color_mode = "gradient"
	stat_text_high_start_pct = 75.0
	stat_text_mid_pct = 50.0
	stat_text_high_r = 255
	stat_text_high_g = 255
	stat_text_high_b = 255
	stat_text_mid_r = 190
	stat_text_mid_g = 190
	stat_text_mid_b = 15
	stat_text_low_r = 200
	stat_text_low_g = 25
	stat_text_low_b = 15

func get_status_icon_color() -> Color:
	return Color8(status_color_r, status_color_g, status_color_b, 255)

func get_stat_text_color(percent: float) -> Color:
	var hi := Color8(stat_text_high_r, stat_text_high_g, stat_text_high_b, 255)
	if stat_text_color_mode == "white_only":
		return hi

	var mid := Color8(stat_text_mid_r, stat_text_mid_g, stat_text_mid_b, 255)
	var low := Color8(stat_text_low_r, stat_text_low_g, stat_text_low_b, 255)
	var p := clampf(percent, 0.0, 100.0)
	var hi_start := clampf(stat_text_high_start_pct, 0.0, 100.0)
	var mid_at := clampf(stat_text_mid_pct, 0.0, hi_start)

	if p >= hi_start:
		return hi
	if p >= mid_at:
		var den_hi := maxf(0.001, hi_start - mid_at)
		var t_hi := (hi_start - p) / den_hi
		return hi.lerp(mid, clampf(t_hi, 0.0, 1.0))

	var den_low := maxf(0.001, mid_at)
	var t_low := (mid_at - p) / den_low
	return mid.lerp(low, clampf(t_low, 0.0, 1.0))

func get_loaded_user_ini_path() -> String:
	return _loaded_user_path

func get_radial(stat_id: StringName) -> bool:
	if numeric_only:
		return false
	return bool(radial.get(stat_id, false))

func get_threshold(stat_id: StringName) -> float:
	return float(visible_threshold.get(stat_id, 79.0))

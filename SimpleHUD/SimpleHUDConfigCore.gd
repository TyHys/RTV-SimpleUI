extends RefCounted

## All settings, INI/JSON merge, and defaults. `Config.gd` is the public entrypoint; VMZ builds
## replace `Config.gd` with a small preset class that subclasses this file.

const DEFAULT_RES := "res://SimpleHUD.default.ini"
const LOAD_DEFAULT_INI := false
const LOAD_USER_INI := false

## Godot ConfigFile does not allow `#` comments; keep file and this string in sync (used if res load fails).
## Presets override `_embedded_defaults_ini()` — do not redeclare `EMBEDDED_DEFAULTS_INI` on subclasses (GDScript forbids shadowing).
const _CORE_EMBEDDED_DEFAULTS_INI := """[general]
enabled=true
min_stat_alpha_floor=0
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
visible_threshold=79.0
radial=true
[fatigue]
visible_threshold=79.0
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


func _embedded_defaults_ini() -> String:
	return _CORE_EMBEDDED_DEFAULTS_INI


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
## Primary offset from the chosen screen edge(s) for the status icon stack (merged JSON `status.padding_px`).
var status_padding_px: float = 5.0
## Uniform scale for status icons relative to status_icon_size_px (100 = default).
var status_scale_pct: float = 100.0
## When true + inflicted_only mode: hide tray if nothing is actively inflicted.
var status_auto_hide_when_none: bool = false
## "top"|"bottom"|"left"|"right" — where the ailment cluster hugs the viewport.
var status_anchor: String = "right"
var status_color_r: int = 120
var status_color_g: int = 0
var status_color_b: int = 0
## Separate tint for inactive ailment icons (\"always\" mode). Defaults match active until changed.
var status_inactive_r: int = 120
var status_inactive_g: int = 0
var status_inactive_b: int = 0
## When status_mode is \"always\", inactive ailments use this alpha on top of `status_inactive_*` RGB.
var status_inactive_alpha: float = 0.25
## Along the ailment strip: leading | center | trailing (HBox: LTR/centered/RTL; VBox: top/center/bottom packing).
var status_strip_alignment: String = "trailing"
## When true, hidden ailment icons are removed from strip flow so visible ones stay packed to the selected edge.
var status_fill_empty_space: bool = false
## Misc: minimalist compass strip.
var compass_enabled: bool = false
var compass_anchor: String = "top"
var compass_color_r: int = 220
var compass_color_g: int = 220
var compass_color_b: int = 220
var compass_color_a: float = 0.95
var crosshair_enabled: bool = false
var crosshair_color_r: int = 220
var crosshair_color_g: int = 220
var crosshair_color_b: int = 220
var crosshair_color_a: float = 0.95
## "crosshair" | "dot"
var crosshair_shape: String = "crosshair"
var crosshair_scale_pct: float = 100.0
var crosshair_bloom_enabled: bool = true
var crosshair_hide_during_aiming: bool = false
var crosshair_hide_while_stowed: bool = false
var fps_hide_label_prefix: bool = true
## "default" | "map_only" | "region_only"
var map_label_mode: String = "default"

var fps_map_alpha: float = 0.5
var fps_map_scale: float = 0.81
var fps_map_anchor: String = "top_left"
var fps_map_offset_x: float = 4.0
var fps_map_offset_y: float = 4.0

var vitals_margin_left: float = 8.0
var vitals_margin_right: float = 8.0
var vitals_margin_top: float = 8.0
var vitals_margin_bottom: float = 5.0
## Horizontal gap between consecutive vitals that share an edge (pixels).
var vitals_spacing_default_px: float = 12.0
## How vitals that share an edge are distributed along that edge: leading | center | trailing (LTR / centered block / RTL for horizontal strips; top→down / centered / bottom→up for vertical).
var vitals_strip_alignment: String = "leading"
## When true, hidden vitals are removed from layout flow so visible ones collapse toward the selected edge.
var vitals_fill_empty_space: bool = false
var vitals_strip_width_px: float = 960.0
var vitals_row_height_px: float = 36.0

## Optional per-stat overrides merged from user://simplehud_preferences.json (see UserPreferences.gd).
var vitals_anchor: Dictionary = {} # stat_id -> "top"|"bottom"|"left"|"right"
var vitals_padding_px: Dictionary = {} # stat_id -> float
var vitals_scale_pct: Dictionary = {} # stat_id -> float (100 = default size)
## Gap after this stat toward the next widget on the same edge (falls back to vitals_spacing_default_px).
var vitals_spacing_px: Dictionary = {} # stat_id -> float
## Per-stat gradient overrides: stat_id -> Dictionary with optional keys mode, high/mid/low_threshold_pct, high_rgb, mid_rgb, low_rgb (arrays of 3 ints).
var stat_gradient_overrides: Dictionary = {}
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

## "dynamic" | "opaque" | "static". Mutually exclusive styles; legacy saves infer from `min_stat_alpha_floor` when unset.
var vitals_transparency_mode: String = "dynamic"
## When mode is static: uniform modulate.a for visible vitals (0..1). Ignored otherwise.
var vitals_static_opacity: float = 0.75

## When true, vitals always use text labels (ignores per-stat radial in INI).
var numeric_only: bool = false
## Clamp stamina/fatigue display to 0 when value is below this percent value.
var stamina_fatigue_near_zero_cutoff: float = 1.0

var _loaded_user_path: String = ""

func load_all() -> void:
	## Use full preset defaults on startup so baked Config.gd preset matches runtime preset application.
	apply_full_preset_defaults()
	if LOAD_DEFAULT_INI:
		_load_file(DEFAULT_RES, false)
	var user_path := _resolve_user_ini_path()
	if LOAD_USER_INI && user_path != "" && FileAccess.file_exists(user_path):
		_loaded_user_path = user_path
		_load_file(user_path, true)
	else:
		_loaded_user_path = ""


## Apply subclass `apply_defaults()` then merge this class's `_embedded_defaults_ini()` (preset VMZs ship multiple preset scripts under `preset_configs/`).
func apply_full_preset_defaults() -> void:
	apply_defaults()
	var cf := ConfigFile.new()
	var err := cf.parse(_embedded_defaults_ini())
	if err == OK:
		_apply_config_file(cf, false)


func _resolve_user_ini_path() -> String:
	return "user://simplehud.ini"

func _load_file(path: String, merge: bool) -> void:
	var cf := ConfigFile.new()
	var err := cf.load(path)
	if err != OK:
		if !merge && path == DEFAULT_RES:
			err = cf.parse(_embedded_defaults_ini())
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
	if cf.has_section_key("general", "vitals_transparency_mode"):
		vitals_transparency_mode = str(cf.get_value("general", "vitals_transparency_mode"))
	if cf.has_section_key("general", "vitals_static_opacity"):
		vitals_static_opacity = clampf(float(cf.get_value("general", "vitals_static_opacity")), 0.0, 1.0)
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
		if cf.has_section_key("status_icons", "inactive_r"):
			status_inactive_r = clampi(int(cf.get_value("status_icons", "inactive_r")), 0, 255)
		if cf.has_section_key("status_icons", "inactive_g"):
			status_inactive_g = clampi(int(cf.get_value("status_icons", "inactive_g")), 0, 255)
		if cf.has_section_key("status_icons", "inactive_b"):
			status_inactive_b = clampi(int(cf.get_value("status_icons", "inactive_b")), 0, 255)
		if cf.has_section_key("status_icons", "inactive_alpha"):
			status_inactive_alpha = clampf(float(cf.get_value("status_icons", "inactive_alpha")), 0.0, 1.0)
		if cf.has_section_key("status_icons", "fill_empty_space"):
			status_fill_empty_space = bool(cf.get_value("status_icons", "fill_empty_space"))

	if cf.has_section("misc"):
		if cf.has_section_key("misc", "compass_enabled"):
			compass_enabled = bool(cf.get_value("misc", "compass_enabled"))
		if cf.has_section_key("misc", "compass_anchor"):
			var ax := str(cf.get_value("misc", "compass_anchor")).strip_edges().to_lower()
			compass_anchor = "bottom" if ax == "bottom" else "top"
		if cf.has_section_key("misc", "compass_color_r"):
			compass_color_r = clampi(int(cf.get_value("misc", "compass_color_r")), 0, 255)
		if cf.has_section_key("misc", "compass_color_g"):
			compass_color_g = clampi(int(cf.get_value("misc", "compass_color_g")), 0, 255)
		if cf.has_section_key("misc", "compass_color_b"):
			compass_color_b = clampi(int(cf.get_value("misc", "compass_color_b")), 0, 255)
		if cf.has_section_key("misc", "compass_color_a"):
			compass_color_a = clampf(float(cf.get_value("misc", "compass_color_a")), 0.0, 1.0)
		if cf.has_section_key("misc", "crosshair_enabled"):
			crosshair_enabled = bool(cf.get_value("misc", "crosshair_enabled"))
		if cf.has_section_key("misc", "crosshair_color_r"):
			crosshair_color_r = clampi(int(cf.get_value("misc", "crosshair_color_r")), 0, 255)
		if cf.has_section_key("misc", "crosshair_color_g"):
			crosshair_color_g = clampi(int(cf.get_value("misc", "crosshair_color_g")), 0, 255)
		if cf.has_section_key("misc", "crosshair_color_b"):
			crosshair_color_b = clampi(int(cf.get_value("misc", "crosshair_color_b")), 0, 255)
		if cf.has_section_key("misc", "crosshair_color_a"):
			crosshair_color_a = clampf(float(cf.get_value("misc", "crosshair_color_a")), 0.0, 1.0)
		if cf.has_section_key("misc", "crosshair_shape"):
			var sh := str(cf.get_value("misc", "crosshair_shape")).strip_edges().to_lower()
			crosshair_shape = "dot" if sh == "dot" else "crosshair"
		if cf.has_section_key("misc", "crosshair_scale_pct"):
			crosshair_scale_pct = clampf(float(cf.get_value("misc", "crosshair_scale_pct")), 25.0, 300.0)
		if cf.has_section_key("misc", "crosshair_bloom_enabled"):
			crosshair_bloom_enabled = bool(cf.get_value("misc", "crosshair_bloom_enabled"))
		if cf.has_section_key("misc", "crosshair_hide_during_aiming"):
			crosshair_hide_during_aiming = bool(cf.get_value("misc", "crosshair_hide_during_aiming"))
		if cf.has_section_key("misc", "crosshair_hide_while_stowed"):
			crosshair_hide_while_stowed = bool(cf.get_value("misc", "crosshair_hide_while_stowed"))
		if cf.has_section_key("misc", "fps_hide_label_prefix"):
			fps_hide_label_prefix = bool(cf.get_value("misc", "fps_hide_label_prefix"))
		if cf.has_section_key("misc", "map_label_mode"):
			var mm := str(cf.get_value("misc", "map_label_mode")).strip_edges().to_lower()
			match mm:
				"map_only", "region_only":
					map_label_mode = mm
				_:
					map_label_mode = "default"

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
		if cf.has_section_key("vitals_layout", "margin_right"):
			vitals_margin_right = clampf(float(cf.get_value("vitals_layout", "margin_right")), 0.0, 512.0)
		if cf.has_section_key("vitals_layout", "margin_top"):
			vitals_margin_top = clampf(float(cf.get_value("vitals_layout", "margin_top")), 0.0, 512.0)
		if cf.has_section_key("vitals_layout", "margin_bottom"):
			vitals_margin_bottom = clampf(float(cf.get_value("vitals_layout", "margin_bottom")), 0.0, 256.0)
		if cf.has_section_key("vitals_layout", "strip_width_px"):
			vitals_strip_width_px = clampf(float(cf.get_value("vitals_layout", "strip_width_px")), 120.0, 4096.0)
		if cf.has_section_key("vitals_layout", "row_height_px"):
			vitals_row_height_px = clampf(float(cf.get_value("vitals_layout", "row_height_px")), 16.0, 256.0)
		if cf.has_section_key("vitals_layout", "fill_empty_space"):
			vitals_fill_empty_space = bool(cf.get_value("vitals_layout", "fill_empty_space"))

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
	status_inactive_alpha = 0.25
	fps_map_alpha = 0.5
	fps_map_scale = 0.81
	fps_map_anchor = "top_left"
	fps_map_offset_x = 4.0
	fps_map_offset_y = 4.0
	min_stat_alpha_floor = 0.0
	vitals_transparency_mode = "dynamic"
	vitals_static_opacity = 0.75
	numeric_only = false
	stamina_fatigue_near_zero_cutoff = 1.0
	vitals_anchor.clear()
	vitals_padding_px.clear()
	vitals_scale_pct.clear()
	vitals_spacing_px.clear()
	stat_gradient_overrides.clear()
	vitals_margin_left = 8.0
	vitals_margin_right = 8.0
	vitals_margin_top = 8.0
	vitals_margin_bottom = 5.0
	vitals_spacing_default_px = 12.0
	vitals_strip_alignment = "leading"
	vitals_fill_empty_space = false
	vitals_strip_width_px = 960.0
	vitals_row_height_px = 36.0
	status_padding_px = 5.0
	status_scale_pct = 100.0
	status_auto_hide_when_none = false
	status_anchor = "right"
	status_strip_alignment = "trailing"
	status_fill_empty_space = false
	compass_enabled = false
	compass_anchor = "top"
	compass_color_r = 220
	compass_color_g = 220
	compass_color_b = 220
	compass_color_a = 0.95
	crosshair_enabled = false
	crosshair_color_r = 220
	crosshair_color_g = 220
	crosshair_color_b = 220
	crosshair_color_a = 0.95
	crosshair_shape = "crosshair"
	crosshair_scale_pct = 100.0
	crosshair_bloom_enabled = true
	crosshair_hide_during_aiming = false
	crosshair_hide_while_stowed = false
	fps_hide_label_prefix = true
	map_label_mode = "default"
	status_inactive_r = status_color_r
	status_inactive_g = status_color_g
	status_inactive_b = status_color_b
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


func get_status_inactive_icon_color() -> Color:
	return Color8(status_inactive_r, status_inactive_g, status_inactive_b, 255)


func get_compass_color() -> Color:
	return Color(
		clampf(float(compass_color_r) / 255.0, 0.0, 1.0),
		clampf(float(compass_color_g) / 255.0, 0.0, 1.0),
		clampf(float(compass_color_b) / 255.0, 0.0, 1.0),
		clampf(float(compass_color_a), 0.0, 1.0)
	)


func get_crosshair_color() -> Color:
	return Color(
		clampf(float(crosshair_color_r) / 255.0, 0.0, 1.0),
		clampf(float(crosshair_color_g) / 255.0, 0.0, 1.0),
		clampf(float(crosshair_color_b) / 255.0, 0.0, 1.0),
		clampf(float(crosshair_color_a), 0.0, 1.0)
	)


func get_vitals_transparency_mode() -> String:
	var m := str(vitals_transparency_mode).strip_edges().to_lower()
	if m == "opaque" || m == "solid":
		return "opaque"
	if m == "static":
		return "static"
	if m == "dynamic":
		## Presets often set only `min_stat_alpha_floor` in INI (legacy).
		if min_stat_alpha_floor >= 0.999:
			return "opaque"
		return "dynamic"
	if min_stat_alpha_floor >= 0.999:
		return "opaque"
	return "dynamic"


func get_vitals_strip_alignment() -> String:
	match str(vitals_strip_alignment).strip_edges().to_lower():
		"c", "center", "centre", "middle":
			return "center"
		"t", "trail", "trailing", "end":
			return "trailing"
		_:
			return "leading"


func get_status_strip_alignment() -> String:
	match str(status_strip_alignment).strip_edges().to_lower():
		"c", "center", "centre", "middle":
			return "center"
		"l", "lead", "leading", "begin", "start":
			return "leading"
		"t", "trail", "trailing", "end":
			return "trailing"
		_:
			return "trailing"

func get_stat_text_color(percent: float) -> Color:
	return _stat_color_from_params(
		percent,
		stat_text_color_mode,
		stat_text_high_start_pct,
		stat_text_mid_pct,
		0.0,
		Color8(stat_text_high_r, stat_text_high_g, stat_text_high_b, 255),
		Color8(stat_text_mid_r, stat_text_mid_g, stat_text_mid_b, 255),
		Color8(stat_text_low_r, stat_text_low_g, stat_text_low_b, 255),
	)


func get_stat_text_color_for(stat_id: StringName, percent: float) -> Color:
	var o: Variant = stat_gradient_overrides.get(stat_id, null)
	if o == null || !o is Dictionary:
		return get_stat_text_color(percent)

	var gd: Dictionary = o as Dictionary
	var mode := str(gd.get("mode", stat_text_color_mode)).to_lower()
	var hi_start := float(gd.get("high_threshold_pct", stat_text_high_start_pct))
	var mid_at := float(gd.get("mid_threshold_pct", stat_text_mid_pct))
	var low_at := float(gd.get("low_threshold_pct", 0.0))

	var hi_c := Color8(stat_text_high_r, stat_text_high_g, stat_text_high_b, 255)
	var mid_c := Color8(stat_text_mid_r, stat_text_mid_g, stat_text_mid_b, 255)
	var low_c := Color8(stat_text_low_r, stat_text_low_g, stat_text_low_b, 255)

	if gd.has("high_rgb"):
		hi_c = _color_from_rgb_array(gd["high_rgb"], hi_c)
	if gd.has("mid_rgb"):
		mid_c = _color_from_rgb_array(gd["mid_rgb"], mid_c)
	if gd.has("low_rgb"):
		low_c = _color_from_rgb_array(gd["low_rgb"], low_c)

	return _stat_color_from_params(percent, mode, hi_start, mid_at, low_at, hi_c, mid_c, low_c)


func _color_from_rgb_array(v: Variant, fallback: Color) -> Color:
	if v is Array && (v as Array).size() >= 3:
		var a := v as Array
		return Color8(clampi(int(a[0]), 0, 255), clampi(int(a[1]), 0, 255), clampi(int(a[2]), 0, 255), 255)
	return fallback


func _stat_color_from_params(
	percent: float,
	mode: String,
	hi_start_pct: float,
	mid_pct: float,
	low_pct: float,
	hi: Color,
	mid: Color,
	low: Color,
) -> Color:
	if mode == "white_only" || mode == "white":
		return hi

	var p := clampf(percent, 0.0, 100.0)
	var hi_start := clampf(hi_start_pct, 0.0, 100.0)
	var mid_at := clampf(mid_pct, 0.0, hi_start)
	var low_at := clampf(low_pct, 0.0, mid_at)

	if p >= hi_start:
		return hi
	if p >= mid_at:
		var den_hi := maxf(0.001, hi_start - mid_at)
		var t_hi := (hi_start - p) / den_hi
		return hi.lerp(mid, clampf(t_hi, 0.0, 1.0))

	if p <= low_at:
		return low
	var den_low := maxf(0.001, mid_at - low_at)
	var t_low := (mid_at - p) / den_low
	return mid.lerp(low, clampf(t_low, 0.0, 1.0))


func get_vitals_anchor(stat_id: StringName) -> String:
	var v: Variant = vitals_anchor.get(stat_id, null)
	if v != null:
		return str(v).to_lower()
	return "bottom"


func get_vitals_padding_px(stat_id: StringName) -> float:
	if vitals_padding_px.has(stat_id):
		return clampf(float(vitals_padding_px[stat_id]), 0.0, 512.0)
	match get_vitals_anchor(stat_id):
		"bottom":
			return vitals_margin_bottom
		"top":
			return vitals_margin_top
		"left":
			return vitals_margin_left
		"right":
			return vitals_margin_right
		_:
			return vitals_margin_bottom


func get_vitals_scale_pct(stat_id: StringName) -> float:
	if vitals_scale_pct.has(stat_id):
		return clampf(float(vitals_scale_pct[stat_id]), 25.0, 400.0)
	return 100.0


func get_spacing_after_stat(stat_id: StringName) -> float:
	if vitals_spacing_px.has(stat_id):
		return clampf(float(vitals_spacing_px[stat_id]), 0.0, 256.0)
	return vitals_spacing_default_px

func get_loaded_user_ini_path() -> String:
	return _loaded_user_path

func get_radial(stat_id: StringName) -> bool:
	if numeric_only:
		return false
	return bool(radial.get(stat_id, false))

func get_threshold(stat_id: StringName) -> float:
	return float(visible_threshold.get(stat_id, 79.0))

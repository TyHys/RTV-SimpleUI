extends RefCounted

## Loaded via preload from Main/HudOverlay — do not rely on global class_name (mod autoload order).

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
spacing_px=6
icon_scale=1.0
stack_direction=\"vertical_up\"
[fps_map]
alpha=0.5
scale=0.81
anchor=\"top_left\"
offset_x=4
offset_y=4
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
var status_spacing_px: float = 6.0
var status_icon_scale: float = 1.0
var status_stack_direction: String = "vertical_up"

var fps_map_alpha: float = 0.5
var fps_map_scale: float = 0.81
var fps_map_anchor: String = "top_left"
var fps_map_offset_x: float = 4.0
var fps_map_offset_y: float = 4.0

## When non-health stats are visible, floor modulate.a so bars near ~70% are still readable (pure 1-p/100 is often ~0.3 alpha).
var min_stat_alpha_floor: float = 0.0

var log_enabled: bool = true

## When true, vitals always use text labels (ignores per-stat radial in INI).
var numeric_only: bool = true

var _loaded_user_path: String = ""

func load_all() -> void:
	apply_defaults()
	_load_file(DEFAULT_RES, false)
	var user_path := _resolve_user_ini_path()
	if user_path != "" && FileAccess.file_exists(user_path):
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
			status_icon_scale = clampf(float(cf.get_value("status_icons", "icon_scale")), 0.25, 4.0)
		if cf.has_section_key("status_icons", "stack_direction"):
			status_stack_direction = str(cf.get_value("status_icons", "stack_direction"))

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
		radial[id] = false
	status_mode = "inflicted_only"
	status_corner = "bottom_right"
	status_spacing_px = 6.0
	status_icon_scale = 1.0
	status_stack_direction = "vertical_up"
	fps_map_alpha = 0.5
	fps_map_scale = 0.81
	fps_map_anchor = "top_left"
	fps_map_offset_x = 4.0
	fps_map_offset_y = 4.0
	min_stat_alpha_floor = 0.0
	log_enabled = true
	numeric_only = true

func get_loaded_user_ini_path() -> String:
	return _loaded_user_path

func get_radial(stat_id: StringName) -> bool:
	if numeric_only:
		return false
	return bool(radial.get(stat_id, false))

func get_threshold(stat_id: StringName) -> float:
	return float(visible_threshold.get(stat_id, 79.0))

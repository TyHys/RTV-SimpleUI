extends Control

const SimpleHUDConfigScript := preload("res://SimpleHUD/Config.gd")
const STAT_WIDGET_SCRIPT := preload("res://SimpleHUD/widgets/StatWidget.gd")
const STATUS_TRAY_SCRIPT := preload("res://SimpleHUD/widgets/StatusTray.gd")

var _game_data: Resource
var _cfg: RefCounted

var _stats_root: Control
var _vitals_box: HBoxContainer
var _widgets: Dictionary = {}

var _tray: STATUS_TRAY_SCRIPT

## Mirrors escape-menu → Settings HUD toggles (Preferences.vitals / Preferences.medical).
var _prefs_vitals: bool = true
var _prefs_medical: bool = true

func setup(game_data: Resource, cfg: RefCounted) -> void:
	_game_data = game_data
	_cfg = cfg

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_stats_root = Control.new()
	_stats_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_root.z_index = 32
	add_child(_stats_root)

	_vitals_box = HBoxContainer.new()
	_vitals_box.add_theme_constant_override("separation", 12)
	_vitals_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_stats_root.add_child(_vitals_box)

	var defs: Array = [
		[SimpleHUDConfigScript.STAT_HEALTH, "HP"],
		[SimpleHUDConfigScript.STAT_ENERGY, "EN"],
		[SimpleHUDConfigScript.STAT_HYDRATION, "HY"],
		[SimpleHUDConfigScript.STAT_MENTAL, "MN"],
		[SimpleHUDConfigScript.STAT_BODY_TEMP, "TP"],
		[SimpleHUDConfigScript.STAT_STAMINA, "ST"],
		[SimpleHUDConfigScript.STAT_FATIGUE, "FT"],
	]

	for d in defs:
		var sid: StringName = d[0]
		var ttl: String = d[1]
		var sw: STAT_WIDGET_SCRIPT = STAT_WIDGET_SCRIPT.new()
		sw.setup(sid, ttl, game_data, cfg.get_radial(sid), cfg)
		_widgets[sid] = sw
		_vitals_box.add_child(sw)

	_tray = STATUS_TRAY_SCRIPT.new()
	_tray.setup(game_data, cfg)
	add_child(_tray)
	_tray.refresh()


func configure_hud_prefs(vitals_on: bool, medical_on: bool) -> void:
	_prefs_vitals = vitals_on
	_prefs_medical = medical_on


func set_live_game_data(r: Resource) -> void:
	if r != null && is_instance_valid(r):
		_game_data = r
		if _tray != null:
			_tray.set_game_data(r)


func layout_for_viewport(vp_size: Vector2, stats_visible: bool) -> void:
	if !is_instance_valid(_stats_root):
		return

	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	if vp_size.x > 1.0 && vp_size.y > 1.0:
		size = vp_size
		position = Vector2.ZERO

	_stats_root.visible = stats_visible && _cfg.enabled && _prefs_vitals

	var corner_m := float(_cfg.vitals_margin_left)
	var corner_mb := float(_cfg.vitals_margin_bottom)
	if _uses_radial_mode():
		corner_mb = maxf(corner_mb, 32.0)
	var strip_w := float(_cfg.vitals_strip_width_px)
	var row_h := float(_cfg.vitals_row_height_px)

	_stats_root.anchor_left = 0.0
	_stats_root.anchor_top = 1.0
	_stats_root.anchor_right = 0.0
	_stats_root.anchor_bottom = 1.0
	_stats_root.offset_left = corner_m
	_stats_root.offset_top = -(corner_mb + row_h)
	_stats_root.offset_right = corner_m + strip_w
	_stats_root.offset_bottom = -corner_mb

	if _tray:
		_tray.visible = _prefs_medical
		_tray.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_tray.refresh()
		var tray_size: Vector2 = _tray.get_combined_minimum_size()
		tray_size.x = maxf(tray_size.x, 28.0)
		tray_size.y = maxf(tray_size.y, 28.0)
		var tray_right: float = float(_cfg.status_margin_right)
		var tray_bottom: float = float(_cfg.status_margin_bottom)
		var tray_x: float = maxf(0.0, vp_size.x - tray_right - tray_size.x)
		var tray_y: float = maxf(0.0, vp_size.y - tray_bottom - tray_size.y)
		_tray.position = Vector2(tray_x, tray_y)
		_tray.size = tray_size


func tick(delta_sec: float = -1.0) -> void:
	if !_cfg.enabled || !is_instance_valid(_game_data):
		return
	if !_prefs_vitals:
		return

	for sid in SimpleHUDConfigScript.STAT_IDS:
		var raw: float = _percent_for(sid)
		var p: float = _normalized_percent(sid, raw)
		var th: float = float(_cfg.get_threshold(sid))
		var show_stat: bool = p <= th
		var use_radial: bool = bool(_cfg.get_radial(sid))
		var computed: float = 1.0 - clampf(p, 0.0, 100.0) / 100.0
		var alpha: float = computed
		if show_stat:
			var fl: float = float(_cfg.min_stat_alpha_floor)
			alpha = maxf(computed, fl)

		var w := _widgets.get(sid) as STAT_WIDGET_SCRIPT
		if w != null:
			w.update_display(p, show_stat, use_radial, alpha)


func _uses_radial_mode() -> bool:
	if _cfg == null:
		return false
	for sid in SimpleHUDConfigScript.STAT_IDS:
		if bool(_cfg.get_radial(sid)):
			return true
	return false


func _normalized_percent(sid: StringName, raw: float) -> float:
	var x: float = float(raw)
	if sid == SimpleHUDConfigScript.STAT_BODY_TEMP:
		return x
	x = clampf(x, 0.0, 100.0)
	if sid == SimpleHUDConfigScript.STAT_STAMINA || sid == SimpleHUDConfigScript.STAT_FATIGUE:
		var near_zero_cutoff: float = 1.0
		if _cfg != null:
			near_zero_cutoff = float(_cfg.stamina_fatigue_near_zero_cutoff)
		if x < near_zero_cutoff:
			return 0.0
	return x


func _percent_for(sid: StringName) -> float:
	match sid:
		SimpleHUDConfigScript.STAT_HEALTH:
			return _game_data.health
		SimpleHUDConfigScript.STAT_ENERGY:
			return _game_data.energy
		SimpleHUDConfigScript.STAT_HYDRATION:
			return _game_data.hydration
		SimpleHUDConfigScript.STAT_MENTAL:
			return _game_data.mental
		SimpleHUDConfigScript.STAT_BODY_TEMP:
			return _game_data.temperature
		SimpleHUDConfigScript.STAT_STAMINA:
			return _game_data.bodyStamina
		SimpleHUDConfigScript.STAT_FATIGUE:
			return _game_data.armStamina
	return 0.0

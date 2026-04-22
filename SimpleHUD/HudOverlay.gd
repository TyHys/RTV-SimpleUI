extends Control

const SimpleHUDConfigScript := preload("res://SimpleHUD/Config.gd")
const SimpleHudLog := preload("res://SimpleHUD/SimpleHudLog.gd")
const STAT_WIDGET_SCRIPT := preload("res://SimpleHUD/widgets/StatWidget.gd")
const STATUS_TRAY_SCRIPT := preload("res://SimpleHUD/widgets/StatusTray.gd")

var _game_data: Resource
var _cfg: RefCounted

var _stats_root: Control
var _vitals_box: HBoxContainer
var _widgets: Dictionary = {}

var _tray: Control
var _diag_prev: Dictionary = {} # stat_id -> {raw, percent, show, alpha}
var _stamina_trace_prev: Dictionary = {} # keys: body, arm
var _trace_tick: int = 0

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
		var sw: Control = STAT_WIDGET_SCRIPT.new() as Control
		sw.setup(sid, ttl, game_data, cfg.get_radial(sid), cfg)
		_widgets[sid] = sw
		_vitals_box.add_child(sw)

	_tray = STATUS_TRAY_SCRIPT.new() as Control
	_tray.setup(game_data, cfg)
	add_child(_tray)
	if _tray.has_method("refresh"):
		_tray.call("refresh")


func configure_hud_prefs(vitals_on: bool, medical_on: bool) -> void:
	_prefs_vitals = vitals_on
	_prefs_medical = medical_on


func set_live_game_data(r: Resource) -> void:
	if r != null && is_instance_valid(r):
		_game_data = r
		if _tray && _tray.has_method("set_game_data"):
			_tray.call("set_game_data", r)


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
		if _tray.has_method("refresh"):
			_tray.call("refresh")
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

	_trace_tick += 1
	_log_stamina_trace(delta_sec)

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

		var w: Control = _widgets.get(sid)
		if w && w.has_method("update_display"):
			w.call("update_display", p, show_stat, use_radial, alpha)

		_log_vitals_diag(sid, raw, p, th, show_stat, use_radial, alpha)


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


func _log_vitals_diag(
	sid: StringName,
	raw: float,
	percent: float,
	threshold: float,
	show_stat: bool,
	use_radial: bool,
	alpha: float
) -> void:
	if !SimpleHudLog.is_enabled():
		return
	if sid != SimpleHUDConfigScript.STAT_STAMINA && sid != SimpleHUDConfigScript.STAT_FATIGUE:
		return
	if !use_radial:
		return

	var frame := Engine.get_process_frames()
	var prev: Dictionary = _diag_prev.get(sid, {})
	var prev_raw: float = float(prev.get("raw", raw))
	var prev_percent: float = float(prev.get("percent", percent))
	var prev_show: bool = bool(prev.get("show", show_stat))
	var prev_alpha: float = float(prev.get("alpha", alpha))
	var display_value: int = int(round(percent))
	var prev_display: int = int(prev.get("display", display_value))

	var changed := (
		absf(raw - prev_raw) > 0.01
		|| absf(percent - prev_percent) > 0.01
		|| show_stat != prev_show
		|| absf(alpha - prev_alpha) > 0.01
		|| display_value != prev_display
	)

	# Keep noise manageable: always log on state changes, otherwise sample periodically.
	if changed || frame % 10 == 0:
		SimpleHudLog.info(
			"VitalsDiag stat=%s frame=%s raw=%.4f pct=%.4f display=%d th=%.2f show=%s radial=%s alpha=%.4f"
			% [str(sid), str(frame), raw, percent, display_value, threshold, str(show_stat), str(use_radial), alpha]
		)

	_diag_prev[sid] = {
		"raw": raw,
		"percent": percent,
		"display": display_value,
		"show": show_stat,
		"alpha": alpha,
	}


func _log_stamina_trace(delta_sec: float) -> void:
	if !SimpleHudLog.is_enabled():
		return

	var body_raw: float = float(_game_data.get("bodyStamina"))
	var arm_raw: float = float(_game_data.get("armStamina"))
	var body_pct: float = _normalized_percent(SimpleHUDConfigScript.STAT_STAMINA, body_raw)
	var arm_pct: float = _normalized_percent(SimpleHUDConfigScript.STAT_FATIGUE, arm_raw)
	var body_display: int = int(round(body_pct))
	var arm_display: int = int(round(arm_pct))
	var body_domain := "percent_0_to_100"
	var arm_domain := "percent_0_to_100"
	var near_zero_cutoff: float = 1.0
	if _cfg != null:
		near_zero_cutoff = float(_cfg.stamina_fatigue_near_zero_cutoff)
	var body_near_zero: bool = body_raw < near_zero_cutoff
	var arm_near_zero: bool = arm_raw < near_zero_cutoff

	var prev_body: float = float(_stamina_trace_prev.get("body", body_raw))
	var prev_arm: float = float(_stamina_trace_prev.get("arm", arm_raw))
	var d_body: float = body_raw - prev_body
	var d_arm: float = arm_raw - prev_arm

	var body_rate: float = 0.0
	var arm_rate: float = 0.0
	if delta_sec > 0.0001:
		body_rate = d_body / delta_sec
		arm_rate = d_arm / delta_sec

	var body_mode := _stamina_mode_text(d_body)
	var arm_mode := _stamina_mode_text(d_arm)
	var body_trigger := _infer_body_stamina_trigger()
	var arm_trigger := _infer_arm_stamina_trigger()
	var ctx := _stamina_context_flags()

	var should_log := (
		absf(d_body) > 0.001
		|| absf(d_arm) > 0.001
		|| _trace_tick % 10 == 0
		|| body_raw <= (near_zero_cutoff + 0.5)
		|| arm_raw <= (near_zero_cutoff + 0.5)
	)

	if should_log:
		SimpleHudLog.info(
			(
				"StaminaTrace frame=%s dt=%.4f "
				+ "body(raw=%.4f pct=%.4f display=%d d=%.4f rate=%.4f/s mode=%s trigger=%s domain=%s near_zero=%s) "
				+ "arm(raw=%.4f pct=%.4f display=%d d=%.4f rate=%.4f/s mode=%s trigger=%s domain=%s near_zero=%s) "
				+ "policy={near_zero_cutoff=%.3f, stamina_domain=percent_0_to_100, fatigue_domain=percent_0_to_100} "
				+ "ctx={%s}"
			)
			% [
				str(Engine.get_process_frames()),
				maxf(delta_sec, -1.0),
				body_raw, body_pct, body_display, d_body, body_rate, body_mode, body_trigger, body_domain, str(body_near_zero),
				arm_raw, arm_pct, arm_display, d_arm, arm_rate, arm_mode, arm_trigger, arm_domain, str(arm_near_zero),
				near_zero_cutoff,
				ctx,
			]
		)

	_stamina_trace_prev["body"] = body_raw
	_stamina_trace_prev["arm"] = arm_raw


func _stamina_mode_text(delta_value: float) -> String:
	if delta_value < -0.001:
		return "loss"
	if delta_value > 0.001:
		return "gain"
	return "steady"


func _infer_body_stamina_trigger() -> String:
	var is_running := _gd_bool("isRunning")
	var is_swimming := _gd_bool("isSwimming")
	var is_moving := _gd_bool("isMoving")
	var overweight := _gd_bool("overweight")
	var starvation := _gd_bool("starvation")
	var dehydration := _gd_bool("dehydration")
	var body_raw: float = float(_game_data.get("bodyStamina"))

	var drain := body_raw > 0.0 && (is_running || overweight || (is_swimming && is_moving))
	if drain:
		if overweight || starvation || dehydration:
			return "drain_fast(overweight/starvation/dehydration)"
		return "drain_normal(running/swim_move)"
	if body_raw < 100.0:
		if starvation || dehydration:
			return "regen_slow(starvation/dehydration)"
		return "regen_fast(normal)"
	return "at_cap_or_idle"


func _infer_arm_stamina_trigger() -> String:
	var primary := _gd_bool("primary")
	var secondary := _gd_bool("secondary")
	var weapon_position := int(_game_data.get("weaponPosition"))
	var is_aiming := _gd_bool("isAiming")
	var is_canted := _gd_bool("isCanted")
	var is_inspecting := _gd_bool("isInspecting")
	var overweight := _gd_bool("overweight")
	var starvation := _gd_bool("starvation")
	var dehydration := _gd_bool("dehydration")
	var is_swimming := _gd_bool("isSwimming")
	var is_moving := _gd_bool("isMoving")
	var arm_raw: float = float(_game_data.get("armStamina"))

	var weapon_active := (primary || secondary) && (weapon_position == 2 || is_aiming || is_canted || is_inspecting || overweight)
	var drain := arm_raw > 0.0 && (weapon_active || (is_swimming && is_moving))
	if drain:
		if overweight || starvation || dehydration:
			return "drain_fast(overweight/starvation/dehydration)"
		return "drain_normal(weapon_active/swim_move)"
	if arm_raw < 100.0:
		if starvation || dehydration:
			return "regen_normal(starvation/dehydration)"
		return "regen_fast(normal)"
	return "at_cap_or_idle"


func _stamina_context_flags() -> String:
	var keys: Array[String] = [
		"isRunning",
		"isMoving",
		"isSwimming",
		"isAiming",
		"isCanted",
		"isInspecting",
		"overweight",
		"starvation",
		"dehydration",
		"primary",
		"secondary",
	]
	var parts: PackedStringArray = []
	for k in keys:
		parts.append("%s=%s" % [k, str(_gd_bool(k))])
	parts.append("weaponPosition=%s" % str(int(_game_data.get("weaponPosition"))))
	return ", ".join(parts)


func _gd_bool(key: String) -> bool:
	return bool(_game_data.get(key))

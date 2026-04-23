extends Control

const SimpleHUDConfigScript := preload("res://SimpleHUD/Config.gd")
const STAT_WIDGET_SCRIPT := preload("res://SimpleHUD/widgets/StatWidget.gd")
const STATUS_TRAY_SCRIPT := preload("res://SimpleHUD/widgets/StatusTray.gd")

var _game_data: Resource
var _cfg: RefCounted

var _stats_root: Control
var _widgets: Dictionary = {}

var _tray: STATUS_TRAY_SCRIPT

## Mirrors escape-menu → Settings HUD toggles (Preferences.vitals / Preferences.medical).
var _prefs_vitals: bool = true
var _prefs_medical: bool = true


func _widget_defs() -> Array:
	return [
		[SimpleHUDConfigScript.STAT_HEALTH, "HP"],
		[SimpleHUDConfigScript.STAT_ENERGY, "EN"],
		[SimpleHUDConfigScript.STAT_HYDRATION, "HY"],
		[SimpleHUDConfigScript.STAT_MENTAL, "MN"],
		[SimpleHUDConfigScript.STAT_BODY_TEMP, "TP"],
		[SimpleHUDConfigScript.STAT_STAMINA, "ST"],
		[SimpleHUDConfigScript.STAT_FATIGUE, "FT"],
	]


func setup(game_data: Resource, cfg: RefCounted) -> void:
	_game_data = game_data
	_cfg = cfg

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_stats_root = Control.new()
	_stats_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_root.z_index = 32
	add_child(_stats_root)

	var defs: Array = _widget_defs()

	for d in defs:
		var sid: StringName = d[0]
		var ttl: String = d[1]
		var sw: STAT_WIDGET_SCRIPT = STAT_WIDGET_SCRIPT.new()
		sw.setup(sid, ttl, game_data, cfg.get_radial(sid), cfg)
		_widgets[sid] = sw
		_stats_root.add_child(sw)

	_tray = STATUS_TRAY_SCRIPT.new()
	_tray.setup(game_data, cfg)
	add_child(_tray)
	_tray.refresh()


## After swapping the Config instance on Main (e.g. main-menu preset load), rebind widgets and tray to the new object.
func apply_live_config(cfg: RefCounted) -> void:
	_cfg = cfg
	if !is_instance_valid(_stats_root):
		return
	var defs: Array = _widget_defs()
	for d in defs:
		var sid: StringName = d[0]
		var ttl: String = d[1]
		var w: STAT_WIDGET_SCRIPT = _widgets.get(sid) as STAT_WIDGET_SCRIPT
		if w != null:
			w.setup(sid, ttl, _game_data, cfg.get_radial(sid), cfg)
	if _tray != null:
		_tray.setup(_game_data, cfg)
		_tray.rebuild_from_cfg()


func configure_hud_prefs(vitals_on: bool, medical_on: bool) -> void:
	_prefs_vitals = vitals_on
	_prefs_medical = medical_on


func notify_config_changed() -> void:
	if _tray != null:
		_tray.rebuild_from_cfg()


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

	_stats_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stats_root.offset_left = 0.0
	_stats_root.offset_top = 0.0
	_stats_root.offset_right = 0.0
	_stats_root.offset_bottom = 0.0

	# Reflow even when the strip is hidden (inventory/menu) so anchor/padding/spacing edits apply as soon as gameplay HUD shows again.
	if _cfg.enabled:
		_layout_vitals(vp_size)

	if _tray:
		_layout_status_tray(vp_size)


func _layout_vitals(vp: Vector2) -> void:
	var groups: Dictionary = {
		"bottom": [],
		"top": [],
		"left": [],
		"right": [],
	}

	for sid in SimpleHUDConfigScript.STAT_IDS:
		var w: Control = _widgets.get(sid) as Control
		if w == null:
			continue
		var ax := str(_cfg.get_vitals_anchor(sid)).to_lower()
		if !groups.has(ax):
			ax = "bottom"
		(groups[ax] as Array).append(sid)

	var order := ["bottom", "top", "left", "right"]
	for ax in order:
		var ids: Array = groups[ax]
		if ids.is_empty():
			continue
		var pad_edge := _group_edge_padding(ids, ax)
		match ax:
			"bottom":
				_place_row_bottom(vp, ids, pad_edge)
			"top":
				_place_row_top(vp, ids, pad_edge)
			"left":
				_place_col_left(vp, ids, pad_edge)
			"right":
				_place_col_right(vp, ids, pad_edge)


func _group_edge_padding(ids: Array, anchor: String) -> float:
	var m := 0.0
	for sid in ids:
		m = maxf(m, float(_cfg.get_vitals_padding_px(sid)))

	var any_radial := false
	for sid in ids:
		if bool(_cfg.get_radial(sid)):
			any_radial = true
			break

	if any_radial:
		m = maxf(m, 32.0)
	return m


func _place_row_bottom(vp: Vector2, ids: Array, pad_from_bottom: float) -> void:
	var align: String = str(_cfg.get_vitals_strip_alignment())
	var ml := float(_cfg.vitals_margin_left)
	var mr := float(_cfg.vitals_margin_right)
	var sizes: Array = []
	var total_w := 0.0
	for sid in ids:
		var w: Control = _widgets.get(sid) as Control
		if w == null:
			continue
		var sz := _widget_place_size(w)
		sizes.append(sz)
		total_w += sz.x
	for i in range(ids.size() - 1):
		total_w += float(_cfg.get_spacing_after_stat(ids[i]))
	var x := ml
	match align:
		"center":
			x = (vp.x - total_w) * 0.5
		"trailing":
			x = vp.x - mr - total_w
		_:
			x = ml
	var max_x0 := maxf(ml, vp.x - mr - total_w)
	x = clampf(x, ml, max_x0)
	var idx := 0
	for sid in ids:
		var w: Control = _widgets.get(sid) as Control
		if w == null:
			continue
		if idx >= sizes.size():
			break
		var sz: Vector2 = sizes[idx]
		idx += 1
		w.position = Vector2(x, vp.y - pad_from_bottom - sz.y)
		w.size = sz
		x += sz.x + float(_cfg.get_spacing_after_stat(sid))


func _place_row_top(vp: Vector2, ids: Array, pad_from_top: float) -> void:
	var align: String = str(_cfg.get_vitals_strip_alignment())
	var ml := float(_cfg.vitals_margin_left)
	var mr := float(_cfg.vitals_margin_right)
	var sizes: Array = []
	var total_w := 0.0
	for sid in ids:
		var w: Control = _widgets.get(sid) as Control
		if w == null:
			continue
		var sz := _widget_place_size(w)
		sizes.append(sz)
		total_w += sz.x
	for i in range(ids.size() - 1):
		total_w += float(_cfg.get_spacing_after_stat(ids[i]))
	var x := ml
	match align:
		"center":
			x = (vp.x - total_w) * 0.5
		"trailing":
			x = vp.x - mr - total_w
		_:
			x = ml
	var max_x0 := maxf(ml, vp.x - mr - total_w)
	x = clampf(x, ml, max_x0)
	var idx := 0
	for sid in ids:
		var w: Control = _widgets.get(sid) as Control
		if w == null:
			continue
		if idx >= sizes.size():
			break
		var sz: Vector2 = sizes[idx]
		idx += 1
		w.position = Vector2(x, pad_from_top)
		w.size = sz
		x += sz.x + float(_cfg.get_spacing_after_stat(sid))


func _place_col_left(vp: Vector2, ids: Array, pad_from_left: float) -> void:
	var align: String = str(_cfg.get_vitals_strip_alignment())
	var mt := float(_cfg.vitals_margin_top)
	var mb := float(_cfg.vitals_margin_bottom)
	var sizes: Array = []
	var total_h := 0.0
	for sid in ids:
		var w: Control = _widgets.get(sid) as Control
		if w == null:
			continue
		var sz := _widget_place_size(w)
		sizes.append(sz)
		total_h += sz.y
	for i in range(ids.size() - 1):
		total_h += float(_cfg.get_spacing_after_stat(ids[i]))
	var y := mt
	match align:
		"center":
			y = (vp.y - total_h) * 0.5
		"trailing":
			y = vp.y - mb - total_h
		_:
			y = mt
	var max_y0 := maxf(mt, vp.y - mb - total_h)
	y = clampf(y, mt, max_y0)
	var idx := 0
	for sid in ids:
		var w: Control = _widgets.get(sid) as Control
		if w == null:
			continue
		if idx >= sizes.size():
			break
		var sz: Vector2 = sizes[idx]
		idx += 1
		w.position = Vector2(pad_from_left, y)
		w.size = sz
		y += sz.y + float(_cfg.get_spacing_after_stat(sid))


func _place_col_right(vp: Vector2, ids: Array, pad_from_right: float) -> void:
	var align: String = str(_cfg.get_vitals_strip_alignment())
	var mt := float(_cfg.vitals_margin_top)
	var mb := float(_cfg.vitals_margin_bottom)
	var sizes: Array = []
	var total_h := 0.0
	for sid in ids:
		var w: Control = _widgets.get(sid) as Control
		if w == null:
			continue
		var sz := _widget_place_size(w)
		sizes.append(sz)
		total_h += sz.y
	for i in range(ids.size() - 1):
		total_h += float(_cfg.get_spacing_after_stat(ids[i]))
	var y := mt
	match align:
		"center":
			y = (vp.y - total_h) * 0.5
		"trailing":
			y = vp.y - mb - total_h
		_:
			y = mt
	var max_y0 := maxf(mt, vp.y - mb - total_h)
	y = clampf(y, mt, max_y0)
	var idx := 0
	for sid in ids:
		var w: Control = _widgets.get(sid) as Control
		if w == null:
			continue
		if idx >= sizes.size():
			break
		var sz: Vector2 = sizes[idx]
		idx += 1
		w.position = Vector2(vp.x - pad_from_right - sz.x, y)
		w.size = sz
		y += sz.y + float(_cfg.get_spacing_after_stat(sid))


func _widget_place_size(w: Control) -> Vector2:
	var sz := w.size
	if sz.x <= 1.0 || sz.y <= 1.0:
		sz = w.custom_minimum_size
	return sz


func _layout_status_tray(vp: Vector2) -> void:
	_tray.refresh()

	var allow := _prefs_medical
	if allow && bool(_cfg.status_auto_hide_when_none) && str(_cfg.status_mode) == "inflicted_only":
		allow = allow && _tray.get_icon_count() > 0

	_tray.visible = allow
	if !allow:
		return

	var tray_size: Vector2 = _tray.get_combined_minimum_size()
	tray_size.x = maxf(tray_size.x, 28.0)
	tray_size.y = maxf(tray_size.y, 28.0)

	var pad := float(_cfg.status_padding_px)
	var ax := str(_cfg.status_anchor).to_lower()
	var tw := tray_size.x
	var th := tray_size.y

	var pos := Vector2(maxf(0.0, vp.x - pad - tw), maxf(0.0, vp.y - pad - th))
	match ax:
		"top":
			pos = Vector2(maxf(0.0, vp.x - pad - tw), pad)
		"left":
			pos = Vector2(pad, maxf(0.0, vp.y - pad - th))
		"bottom", "right":
			pos = Vector2(maxf(0.0, vp.x - pad - tw), maxf(0.0, vp.y - pad - th))
		_:
			pos = Vector2(maxf(0.0, vp.x - pad - tw), maxf(0.0, vp.y - pad - th))

	_tray.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tray.position = pos
	_tray.size = tray_size


## `skip_prefs_guard`: when true, refresh widgets even if escape-menu HUD has vitals disabled — used after inventory panel edits so the overlay matches saved cfg.
func tick(delta_sec: float = -1.0, skip_prefs_guard: bool = false) -> void:
	if !_cfg.enabled || !is_instance_valid(_game_data):
		return
	if !skip_prefs_guard && !_prefs_vitals:
		return

	for sid in SimpleHUDConfigScript.STAT_IDS:
		var raw: float = _percent_for(sid)
		var p: float = _normalized_percent(sid, raw)
		var th: float = float(_cfg.get_threshold(sid))
		var show_stat: bool
		if th <= 0.0:
			show_stat = true
		else:
			show_stat = p <= th
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

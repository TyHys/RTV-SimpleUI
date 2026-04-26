extends Control

const SimpleHUDConfigScript := preload("res://SimpleHUD/Config.gd")
const STAT_WIDGET_SCRIPT := preload("res://SimpleHUD/widgets/StatWidget.gd")
const STATUS_TRAY_SCRIPT := preload("res://SimpleHUD/widgets/StatusTray.gd")
const COMPASS_STRIP_SCRIPT := preload("res://SimpleHUD/widgets/CompassStrip.gd")
const CROSSHAIR_WIDGET_SCRIPT := preload("res://SimpleHUD/widgets/CrosshairWidget.gd")
const PERMADEATH_ICON_SCRIPT := preload("res://SimpleHUD/widgets/PermadeathIcon.gd")

## Set true to print compass visibility reasons to the console (throttled).
const SIMPLEHUD_COMPASS_DIAG := false
## Set true to print vitals column layout diagnostics to godot.log (throttled).
const SIMPLEHUD_VITALS_LAYOUT_DIAG := false

var _game_data: Resource
var _cfg: RefCounted

var _stats_root: Control
var _widgets: Dictionary = {}

var _tray: STATUS_TRAY_SCRIPT
var _compass: Control
var _crosshair: Control
var _crosshair_bloom_px: float = 0.0
var _permadeath_icon: PERMADEATH_ICON_SCRIPT

var _compass_diag_last_frame: int = -999999
var _vitals_layout_diag_last_frame: int = -999999

## Avoid rewriting compass rect every frame when viewport/anchor unchanged.
var _compass_layout_vp: Vector2 = Vector2(-1.0, -1.0)
var _compass_layout_bottom: bool = false
var _compass_layout_size: Vector2 = Vector2.ZERO

## Mirrors escape-menu → Settings HUD toggles (Preferences.vitals / Preferences.medical).
var _prefs_vitals: bool = true
var _prefs_medical: bool = true

## Full layout (vitals positions, compass/crosshair rects) only when this bumps or viewport/prefs change.
var _layout_revision: int = 0
var _applied_layout_revision: int = -1
var _lc_vp: Vector2 = Vector2.ZERO
var _lc_stats_visible: bool = false
var _lc_pv: bool = true
var _lc_pm: bool = true
var _lc_en: bool = true
var _lc_compass_en: bool = false
var _lc_crosshair_en: bool = false
var _lc_compass_anchor: String = ""

## Refined on full layout; tick uses these for cheap compass/crosshair placement between full layouts.
var _compass_place_size: Vector2 = Vector2(520.0, 44.0)
var _crosshair_place_size: Vector2 = Vector2(96.0, 96.0)

## Skip redundant tray positioning when tick/layout run every frame but tray rect unchanged.
var _tray_cached_vp: Vector2 = Vector2(-1.0, -1.0)
var _tray_cached_pos: Vector2 = Vector2.ZERO
var _tray_cached_size: Vector2 = Vector2.ZERO
var _tray_cached_allow: bool = false

## Skip vitals `update_display` when nothing display-relevant changed (big win when stats are steady).
var _last_vitals_tick_hash: int = -1
## Separate from `_last_vitals_tick_hash`: bumps layout when which vitals participate changes (prevents stale top-left placement).
var _last_vitals_layout_hash: int = -1
var _vit_scratch_p: PackedFloat32Array = PackedFloat32Array()
var _vit_scratch_alpha: PackedFloat32Array = PackedFloat32Array()
var _vit_show: PackedByteArray = PackedByteArray()
var _vit_radial: PackedByteArray = PackedByteArray()

## Cache which GameData key held a valid spread value last frame (avoid scanning 7 keys every tick).
var _spread_key_hint_idx: int = -1

## Skip atan2/normalize when `playerVector` unchanged (common when idle).
var _bearing_have_cache: bool = false
var _bearing_cache_pv: Vector3 = Vector3.ZERO
var _bearing_cache_deg: float = 0.0

var _GAME_DATA_SPREAD_KEYS: PackedStringArray = PackedStringArray([
	"weaponSpread",
	"spread",
	"bulletSpread",
	"hipSpread",
	"crosshairSpread",
	"currentSpread",
])

## Pre-allocated to avoid a new Dictionary + four Array allocations on every layout pass.
var _lv_group_bottom: Array = []
var _lv_group_top: Array = []
var _lv_group_left: Array = []
var _lv_group_right: Array = []

## Debounce for fill-empty-space layout changes: stats crossing thresholds during sprinting/combat
## would otherwise trigger a full layout pass every frame. 200 ms (1/5 s) max delay.
var _fill_layout_debounce_usec: int = -1
const _FILL_LAYOUT_DEBOUNCE_USEC: int = 200000

## When true (Show All Vitals key held), all stats render at full alpha regardless of threshold/transparency mode.
## Status tray is intentionally NOT affected — binary ailment icons are meaningless when inactive.
var _force_show_all: bool = false

## Show on Change: per-stat last-known percent and expiry timestamps (ms from Time.get_ticks_msec()).
## -1 expiry = not currently active.
var _soc_last_pct: PackedFloat32Array = PackedFloat32Array()
var _soc_expiry_ms: PackedInt64Array = PackedInt64Array()


static var _cached_widget_defs: Array = []
var _cached_stat_ids: Array[StringName] = []
var _interface_node: Node = null
var _next_interface_probe_frame: int = 0
const _INTERFACE_PROBE_INTERVAL_FRAMES := 30
var _helmet_percent_cached: float = 0.0
var _plate_percent_cached: float = 0.0
var _helmet_available_cached: bool = false
var _plate_available_cached: bool = false

func _widget_defs() -> Array:
	if _cached_widget_defs.is_empty():
		_cached_widget_defs = [
			[SimpleHUDConfigScript.STAT_HEALTH, "HP"],
			[SimpleHUDConfigScript.STAT_ENERGY, "EN"],
			[SimpleHUDConfigScript.STAT_HYDRATION, "HY"],
			[SimpleHUDConfigScript.STAT_MENTAL, "MN"],
			[SimpleHUDConfigScript.STAT_BODY_TEMP, "TP"],
			[SimpleHUDConfigScript.STAT_STAMINA, "ST"],
			[SimpleHUDConfigScript.STAT_FATIGUE, "FT"],
			[&"helmet", "HM"],
			[&"cat", "CT"],
			[&"plate", "PL"],
		]
	return _cached_widget_defs


func _stat_ids() -> Array[StringName]:
	if _cached_stat_ids.is_empty():
		for d in _widget_defs():
			_cached_stat_ids.append(d[0] as StringName)
	return _cached_stat_ids


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

	var n_stats: int = _stat_ids().size()
	_vit_scratch_p.resize(n_stats)
	_vit_scratch_alpha.resize(n_stats)
	_vit_show.resize(n_stats)
	_vit_radial.resize(n_stats)
	_soc_last_pct.resize(n_stats)
	_soc_expiry_ms.resize(n_stats)
	_soc_last_pct.fill(-1.0)
	_soc_expiry_ms.fill(-1)

	_tray = STATUS_TRAY_SCRIPT.new()
	_tray.setup(game_data, cfg)
	add_child(_tray)
	_tray.refresh()

	_compass = COMPASS_STRIP_SCRIPT.new()
	_compass.setup(cfg)
	_compass.z_index = 40
	add_child(_compass)

	_crosshair = CROSSHAIR_WIDGET_SCRIPT.new()
	_crosshair.setup(cfg)
	_crosshair.z_index = 41
	add_child(_crosshair)

	_permadeath_icon = PERMADEATH_ICON_SCRIPT.new()
	_permadeath_icon.setup(cfg)
	add_child(_permadeath_icon)

	mark_layout_dirty()


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
	if _compass != null && (_compass as Object).has_method(&"setup"):
		(_compass as Node).call(&"setup", cfg)
	if _crosshair != null && (_crosshair as Object).has_method(&"setup"):
		(_crosshair as Node).call(&"setup", cfg)
	if _permadeath_icon != null:
		_permadeath_icon.setup(cfg)

	_soc_last_pct.fill(-1.0)
	_soc_expiry_ms.fill(-1)
	mark_layout_dirty()


func configure_hud_prefs(vitals_on: bool, medical_on: bool) -> void:
	if vitals_on == _prefs_vitals && medical_on == _prefs_medical:
		return
	_prefs_vitals = vitals_on
	_prefs_medical = medical_on
	_last_vitals_tick_hash = -1


func mark_layout_dirty() -> void:
	_layout_revision += 1
	_tray_cached_vp = Vector2(-1.0, -1.0)
	_last_vitals_tick_hash = -1
	_last_vitals_layout_hash = -1
	_fill_layout_debounce_usec = -1


func set_force_show_all(v: bool) -> void:
	if v == _force_show_all:
		return
	_force_show_all = v
	_last_vitals_tick_hash = -1
	## Also force an immediate layout pass so fill-empty-space repositions correctly without debounce.
	mark_layout_dirty()


func notify_config_changed() -> void:
	mark_layout_dirty()
	if _tray != null:
		_tray.rebuild_from_cfg()


func set_live_game_data(r: Resource) -> void:
	if r == null || !is_instance_valid(r):
		return
	if r == _game_data:
		return
	_game_data = r
	_last_vitals_tick_hash = -1
	_bearing_have_cache = false
	if _tray != null:
		_tray.set_game_data(r)


func _layout_params_match(vp_size: Vector2, stats_visible: bool) -> bool:
	if _applied_layout_revision != _layout_revision:
		return false
	var vpi := Vector2i(int(round(vp_size.x)), int(round(vp_size.y)))
	var lci := Vector2i(int(round(_lc_vp.x)), int(round(_lc_vp.y)))
	if vpi != lci:
		return false
	if stats_visible != _lc_stats_visible:
		return false
	if _prefs_vitals != _lc_pv:
		return false
	if _prefs_medical != _lc_pm:
		return false
	if bool(_cfg.enabled) != _lc_en:
		return false
	if bool(_cfg.compass_enabled) != _lc_compass_en:
		return false
	if bool(_cfg.crosshair_enabled) != _lc_crosshair_en:
		return false
	if str(_cfg.compass_anchor) != _lc_compass_anchor:
		return false
	return true


func _store_layout_cache(vp_size: Vector2, stats_visible: bool) -> void:
	_applied_layout_revision = _layout_revision
	_lc_vp = vp_size
	_lc_stats_visible = stats_visible
	_lc_pv = _prefs_vitals
	_lc_pm = _prefs_medical
	_lc_en = bool(_cfg.enabled)
	_lc_compass_en = bool(_cfg.compass_enabled)
	_lc_crosshair_en = bool(_cfg.crosshair_enabled)
	_lc_compass_anchor = str(_cfg.compass_anchor)


func layout_for_viewport(vp_size: Vector2, stats_visible: bool) -> void:
	if !is_instance_valid(_stats_root):
		return
	if !stats_visible:
		if _compass != null:
			_compass.visible = false
		if _crosshair != null:
			_crosshair.visible = false

	if _layout_params_match(vp_size, stats_visible):
		_layout_status_tray(vp_size)
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
	if _compass != null:
		if bool(_cfg.compass_enabled):
			_layout_compass(vp_size, stats_visible)
		else:
			_compass.visible = false
			_compass_layout_vp = Vector2(-1.0, -1.0)
	if _crosshair != null:
		if bool(_cfg.crosshair_enabled):
			_layout_crosshair(vp_size, stats_visible)
		else:
			_crosshair.visible = false

	if _permadeath_icon != null:
		_permadeath_icon.place(vp_size)

	_store_layout_cache(vp_size, stats_visible)


func _layout_vitals(vp: Vector2) -> void:
	_lv_group_bottom.clear()
	_lv_group_top.clear()
	_lv_group_left.clear()
	_lv_group_right.clear()

	for sid in _stat_ids():
		## Optional vitals (helmet/cat/plate) are removed from layout flow entirely when not applicable.
		if !_is_stat_enabled(sid):
			continue
		var w: Control = _widgets.get(sid) as Control
		if w == null:
			continue
		## `fill_empty_space=true` collapses hidden/transparent slots so visible vitals fill the strip without gaps.
		if bool(_cfg.vitals_fill_empty_space) && !_vital_should_participate_in_layout(sid, w):
			continue
		var ax := str(_cfg.get_vitals_anchor(sid)).to_lower()
		match ax:
			"top":
				_lv_group_top.append(sid)
			"left":
				_lv_group_left.append(sid)
			"right":
				_lv_group_right.append(sid)
			_:
				_lv_group_bottom.append(sid)

	if !_lv_group_bottom.is_empty():
		_place_row_bottom(vp, _lv_group_bottom, _group_edge_padding(_lv_group_bottom, "bottom"))
	if !_lv_group_top.is_empty():
		_place_row_top(vp, _lv_group_top, _group_edge_padding(_lv_group_top, "top"))
	if !_lv_group_left.is_empty():
		_place_col_left(vp, _lv_group_left, _group_edge_padding(_lv_group_left, "left"))
	if !_lv_group_right.is_empty():
		_place_col_right(vp, _lv_group_right, _group_edge_padding(_lv_group_right, "right"))


func _widget_counts_for_layout(w: Control) -> bool:
	if w == null:
		return false
	if !w.visible:
		return false
	return w.modulate.a > 0.001


func _vital_counts_for_layout(sid: StringName, w: Control) -> bool:
	var idx := SimpleHUDConfigScript.STAT_IDS.find(sid)
	if idx >= 0 && idx < _vit_show.size() && idx < _vit_scratch_alpha.size():
		return _vit_show[idx] != 0 && _vit_scratch_alpha[idx] > 0.001
	return _widget_counts_for_layout(w)


func _vital_should_participate_in_layout(sid: StringName, w: Control) -> bool:
	if !_is_stat_enabled(sid):
		return false
	## For fill-empty-space layout decisions, derive active state directly from live data + cfg
	## so placement remains correct even when render updates are hash-skipped.
	if _force_show_all:
		return true
	if _cfg == null || _game_data == null || !is_instance_valid(_game_data):
		return _vital_counts_for_layout(sid, w)
	var raw: float = _percent_for(sid)
	var p: float = _normalized_percent(sid, raw)
	var th: float = float(_cfg.get_threshold(sid))
	var show_stat: bool = true if th <= 0.0 else p <= th
	if !show_stat:
		## Show on Change can keep a vital visible even when it is above the display threshold.
		var idx := SimpleHUDConfigScript.STAT_IDS.find(sid)
		if idx >= 0 && idx < _soc_expiry_ms.size():
			if _soc_expiry_ms[idx] >= 0 && Time.get_ticks_msec() <= _soc_expiry_ms[idx]:
				return true
		return false
	var trans_mode: String = str(_cfg.get_vitals_transparency_mode())
	var alpha: float = 1.0
	var computed: float = 1.0 - clampf(p, 0.0, 100.0) / 100.0
	match trans_mode:
		"opaque":
			alpha = 1.0
		"static":
			alpha = clampf(float(_cfg.vitals_static_opacity), 0.0, 1.0)
		_:
			alpha = maxf(computed, float(_cfg.min_stat_alpha_floor))
	return alpha > 0.001


func _group_edge_padding(ids: Array, anchor: String) -> float:
	var m := 0.0
	for sid in ids:
		m = maxf(m, float(_cfg.get_vitals_padding_px(sid)))
	return m


func _place_row_bottom(vp: Vector2, ids: Array, pad_from_bottom: float) -> void:
	var align: String = str(_cfg.get_vitals_strip_alignment())
	var ml := float(_cfg.vitals_margin_left)
	var mr := float(_cfg.vitals_margin_right)
	var sizes: Array = []
	var placed_ids: Array = []
	var total_w := 0.0
	for sid in ids:
		var w: Control = _widgets.get(sid) as Control
		if w == null:
			continue
		var sz := _widget_place_size(w, bool(_cfg.vitals_fill_empty_space))
		sizes.append(sz)
		placed_ids.append(sid)
		total_w += sz.x
	for i in range(placed_ids.size() - 1):
		total_w += float(_cfg.get_spacing_after_stat(placed_ids[i]))
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
	for sid in placed_ids:
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
	var placed_ids: Array = []
	var total_w := 0.0
	for sid in ids:
		var w: Control = _widgets.get(sid) as Control
		if w == null:
			continue
		var sz := _widget_place_size(w, bool(_cfg.vitals_fill_empty_space))
		sizes.append(sz)
		placed_ids.append(sid)
		total_w += sz.x
	for i in range(placed_ids.size() - 1):
		total_w += float(_cfg.get_spacing_after_stat(placed_ids[i]))
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
	for sid in placed_ids:
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
	var placed_ids: Array = []
	var total_h := 0.0
	for sid in ids:
		var w: Control = _widgets.get(sid) as Control
		if w == null:
			continue
		var sz := _widget_place_size(w, bool(_cfg.vitals_fill_empty_space))
		sizes.append(sz)
		placed_ids.append(sid)
		total_h += sz.y
	for i in range(placed_ids.size() - 1):
		total_h += float(_cfg.get_spacing_after_stat(placed_ids[i]))
	var y := mt
	match align:
		"center":
			y = (vp.y - total_h) * 0.5
		"trailing":
			y = vp.y - mb - total_h
		_:
			y = mt
	match align:
		"center":
			## Center on viewport; clamp only to screen bounds (not top margin) for oversized columns.
			y = clampf(y, 0.0, maxf(0.0, vp.y - total_h))
		"trailing":
			## Bottom-align without forcing top margin as minimum (that snapped long columns back to top).
			y = clampf(y, 0.0, maxf(0.0, vp.y - mb - total_h))
		_:
			var max_y0 := maxf(mt, vp.y - mb - total_h)
			y = clampf(y, mt, max_y0)
	var idx := 0
	var first_pos := Vector2(-1.0, -1.0)
	for sid in placed_ids:
		var w: Control = _widgets.get(sid) as Control
		if w == null:
			continue
		if idx >= sizes.size():
			break
		var sz: Vector2 = sizes[idx]
		idx += 1
		w.position = Vector2(pad_from_left, y)
		w.size = sz
		if first_pos.x < 0.0:
			first_pos = w.position + (sz * 0.5)
		y += sz.y + float(_cfg.get_spacing_after_stat(sid))
	_vitals_layout_diag_maybe("left", align, vp, placed_ids, total_h, y, first_pos)


func _place_col_right(vp: Vector2, ids: Array, pad_from_right: float) -> void:
	var align: String = str(_cfg.get_vitals_strip_alignment())
	var mt := float(_cfg.vitals_margin_top)
	var mb := float(_cfg.vitals_margin_bottom)
	var sizes: Array = []
	var placed_ids: Array = []
	var total_h := 0.0
	for sid in ids:
		var w: Control = _widgets.get(sid) as Control
		if w == null:
			continue
		var sz := _widget_place_size(w, bool(_cfg.vitals_fill_empty_space))
		sizes.append(sz)
		placed_ids.append(sid)
		total_h += sz.y
	for i in range(placed_ids.size() - 1):
		total_h += float(_cfg.get_spacing_after_stat(placed_ids[i]))
	var y := mt
	match align:
		"center":
			y = (vp.y - total_h) * 0.5
		"trailing":
			y = vp.y - mb - total_h
		_:
			y = mt
	match align:
		"center":
			## Center on viewport; clamp only to screen bounds (not top margin) for oversized columns.
			y = clampf(y, 0.0, maxf(0.0, vp.y - total_h))
		"trailing":
			## Bottom-align without forcing top margin as minimum (that snapped long columns back to top).
			y = clampf(y, 0.0, maxf(0.0, vp.y - mb - total_h))
		_:
			var max_y0 := maxf(mt, vp.y - mb - total_h)
			y = clampf(y, mt, max_y0)
	var idx := 0
	var first_pos := Vector2(-1.0, -1.0)
	for sid in placed_ids:
		var w: Control = _widgets.get(sid) as Control
		if w == null:
			continue
		if idx >= sizes.size():
			break
		var sz: Vector2 = sizes[idx]
		idx += 1
		w.position = Vector2(vp.x - pad_from_right - sz.x, y)
		w.size = sz
		if first_pos.x < 0.0:
			first_pos = w.position + (sz * 0.5)
		y += sz.y + float(_cfg.get_spacing_after_stat(sid))
	_vitals_layout_diag_maybe("right", align, vp, placed_ids, total_h, y, first_pos)


func _widget_place_size(w: Control, reserve_slot: bool = false) -> Vector2:
	var sz := w.custom_minimum_size if reserve_slot else w.size
	if sz.x <= 1.0 || sz.y <= 1.0:
		sz = w.custom_minimum_size
	if sz.x <= 1.0 || sz.y <= 1.0:
		sz = w.get_combined_minimum_size()
	if sz.x <= 1.0 || sz.y <= 1.0:
		sz = Vector2(56.0, 56.0)
	return sz


func _vitals_layout_diag_maybe(
	edge: String,
	align: String,
	vp: Vector2,
	placed_ids: Array,
	total_h: float,
	y_after_layout: float,
	first_center: Vector2,
) -> void:
	if !SIMPLEHUD_VITALS_LAYOUT_DIAG:
		return
	var f: int = Engine.get_process_frames()
	if f - _vitals_layout_diag_last_frame < 30:
		return
	_vitals_layout_diag_last_frame = f
	print(
		"[SimpleHUD][vitals_layout] edge=%s align=%s vp=%s fill_empty=%s ids=%s total_h=%.2f y_after=%.2f first_center=%s"
		% [
			edge,
			align,
			vp,
			bool(_cfg.vitals_fill_empty_space),
			placed_ids,
			total_h,
			y_after_layout,
			first_center,
		]
	)


func _layout_status_tray(vp: Vector2) -> void:
	## Content refresh runs from `tick()` so we do not rescan GameData on every layout pass.

	var mode := str(_cfg.status_mode)
	var allow := mode != "hidden"
	if allow && bool(_cfg.status_auto_hide_when_none) && mode == "inflicted_only":
		allow = _tray.get_icon_count() > 0

	if !allow:
		if _tray.visible:
			_tray.visible = false
		_tray_cached_allow = false
		return

	var invalidated: bool = _tray.consume_minimum_invalidated()
	var must_measure: bool = (
		invalidated
		|| allow != _tray_cached_allow
		|| !vp.is_equal_approx(_tray_cached_vp)
		|| _tray_cached_size.x <= 16.0
		|| _tray_cached_size.y <= 16.0
	)

	var tray_size: Vector2
	if must_measure:
		tray_size = _tray.get_combined_minimum_size()
	else:
		tray_size = _tray_cached_size
	tray_size.x = maxf(tray_size.x, 28.0)
	tray_size.y = maxf(tray_size.y, 28.0)

	var pad := float(_cfg.status_padding_px)
	var ax := str(_cfg.status_anchor).to_lower()
	var align := str(_cfg.get_status_strip_alignment())
	var tw := tray_size.x
	var th := tray_size.y

	var pos := Vector2(maxf(0.0, vp.x - pad - tw), maxf(0.0, vp.y - pad - th))
	match ax:
		"top":
			var x_top := pad
			match align:
				"center":
					x_top = (vp.x - tw) * 0.5
				"trailing":
					x_top = vp.x - pad - tw
				_:
					x_top = pad
			pos = Vector2(clampf(x_top, 0.0, maxf(0.0, vp.x - tw)), pad)
		"bottom":
			var x_bottom := pad
			match align:
				"center":
					x_bottom = (vp.x - tw) * 0.5
				"trailing":
					x_bottom = vp.x - pad - tw
				_:
					x_bottom = pad
			pos = Vector2(clampf(x_bottom, 0.0, maxf(0.0, vp.x - tw)), maxf(0.0, vp.y - pad - th))
		"left":
			var y_left := pad
			match align:
				"center":
					y_left = (vp.y - th) * 0.5
				"trailing":
					y_left = vp.y - pad - th
				_:
					y_left = pad
			pos = Vector2(pad, clampf(y_left, 0.0, maxf(0.0, vp.y - th)))
		"right":
			var y_right := pad
			match align:
				"center":
					y_right = (vp.y - th) * 0.5
				"trailing":
					y_right = vp.y - pad - th
				_:
					y_right = pad
			pos = Vector2(maxf(0.0, vp.x - pad - tw), clampf(y_right, 0.0, maxf(0.0, vp.y - th)))
		_:
			pos = Vector2(maxf(0.0, vp.x - pad - tw), maxf(0.0, vp.y - pad - th))

	if (
		allow == _tray_cached_allow
		&& vp.is_equal_approx(_tray_cached_vp)
		&& pos.is_equal_approx(_tray_cached_pos)
		&& tray_size.is_equal_approx(_tray_cached_size)
	):
		if !_tray.visible:
			_tray.visible = true
		return

	_tray.visible = true
	_tray.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tray.position = pos
	_tray.size = tray_size
	_tray_cached_vp = vp
	_tray_cached_pos = pos
	_tray_cached_size = tray_size
	_tray_cached_allow = allow


func _layout_compass(vp: Vector2, stats_visible: bool) -> void:
	if _compass == null:
		return
	var show_compass: bool = bool(_cfg.compass_enabled) && bool(stats_visible) && bool(_cfg.enabled)
	var was_showing: bool = _compass.visible
	_compass.visible = show_compass
	if !show_compass:
		## Invalidate cached rect so the next show recomputes position (viewport/settings may have changed while hidden).
		_compass_layout_vp = Vector2(-1.0, -1.0)
		_compass_diag_maybe(vp, stats_visible, show_compass)
		return
	var compass_size: Vector2 = _compass.get_combined_minimum_size()
	if compass_size.x <= 1.0 || compass_size.y <= 1.0:
		compass_size = Vector2(520.0, 44.0)
	_compass_place_size = compass_size
	var use_bottom: bool = str(_cfg.compass_anchor).to_lower() == "bottom"
	var layout_dirty: bool = (
		!vp.is_equal_approx(_compass_layout_vp)
		|| use_bottom != _compass_layout_bottom
		|| !compass_size.is_equal_approx(_compass_layout_size)
	)
	if layout_dirty:
		var x := (vp.x - compass_size.x) * 0.5
		var y := maxf(0.0, vp.y - compass_size.y - 8.0) if use_bottom else 8.0
		_compass.position = Vector2(x, y)
		_compass.size = compass_size
		_compass_layout_vp = vp
		_compass_layout_bottom = use_bottom
		_compass_layout_size = compass_size
	if layout_dirty || !was_showing:
		_compass.queue_redraw()
	_compass_diag_maybe(vp, stats_visible, show_compass)


func _compass_diag_maybe(vp: Vector2, stats_visible: bool, show_compass: bool) -> void:
	if !SIMPLEHUD_COMPASS_DIAG:
		return
	var f_diag: int = Engine.get_process_frames()
	if f_diag - _compass_diag_last_frame < 120:
		return
	_compass_diag_last_frame = f_diag
	print(
		"[SimpleHUD][compass] show_compass=%s compass_enabled=%s stats_visible=%s cfg.enabled=%s vp=%s compass_pos=%s compass_size=%s compass.visible=%s"
		% [
			show_compass,
			bool(_cfg.compass_enabled),
			stats_visible,
			bool(_cfg.enabled),
			vp,
			_compass.position,
			_compass.size,
			_compass.visible,
		]
	)


func _layout_crosshair(vp: Vector2, stats_visible: bool) -> void:
	if _crosshair == null:
		return
	var hide_for_ads: bool = _crosshair_hidden_for_ads()
	var hide_for_stowed: bool = _crosshair_hidden_for_stowed()
	var show_crosshair: bool = bool(_cfg.crosshair_enabled) && bool(stats_visible) && bool(_cfg.enabled) && !hide_for_ads && !hide_for_stowed
	_crosshair.visible = show_crosshair
	if !show_crosshair:
		return
	var xsz: Vector2 = _crosshair.get_combined_minimum_size()
	if xsz.x <= 1.0 || xsz.y <= 1.0:
		xsz = Vector2(96.0, 96.0)
	var x := (vp.x - xsz.x) * 0.5
	var y := (vp.y - xsz.y) * 0.5
	_crosshair.position = Vector2(x, y)
	_crosshair.size = xsz
	_crosshair_place_size = xsz


## Cheap per-frame placement for compass/crosshair (full layout only runs when cache misses). Avoids `get_combined_minimum_size` + heavy layout on the fast path.
func _chrome_quick_layout(vp: Vector2, hud_layer_visible: bool) -> void:
	if !bool(_cfg.compass_enabled) && !bool(_cfg.crosshair_enabled):
		return
	if _compass != null && bool(_cfg.compass_enabled):
		var show_c: bool = bool(_cfg.compass_enabled) && hud_layer_visible && bool(_cfg.enabled)
		if _compass.visible != show_c:
			_compass.visible = show_c
		if show_c:
			var cs: Vector2 = _compass_place_size
			var use_bottom: bool = str(_cfg.compass_anchor).to_lower() == "bottom"
			var x: float = (vp.x - cs.x) * 0.5
			var y: float = maxf(0.0, vp.y - cs.y - 8.0) if use_bottom else 8.0
			var new_pos := Vector2(x, y)
			if !_compass.position.is_equal_approx(new_pos):
				_compass.position = new_pos
			if !_compass.size.is_equal_approx(cs):
				_compass.size = cs
	if _crosshair != null && bool(_cfg.crosshair_enabled):
		var hide_for_ads: bool = _crosshair_hidden_for_ads()
		var hide_for_stowed: bool = _crosshair_hidden_for_stowed()
		var show_x: bool = (
			bool(_cfg.crosshair_enabled)
			&& hud_layer_visible
			&& bool(_cfg.enabled)
			&& !hide_for_ads
			&& !hide_for_stowed
		)
		if _crosshair.visible != show_x:
			_crosshair.visible = show_x
		if show_x:
			var xsz: Vector2 = _crosshair_place_size
			var new_x_pos := Vector2((vp.x - xsz.x) * 0.5, (vp.y - xsz.y) * 0.5)
			if !_crosshair.position.is_equal_approx(new_x_pos):
				_crosshair.position = new_x_pos
			if !_crosshair.size.is_equal_approx(xsz):
				_crosshair.size = xsz


func _crosshair_hidden_for_ads() -> bool:
	if !bool(_cfg.crosshair_hide_during_aiming):
		return false
	var gd: Resource = _game_data
	if gd == null || !is_instance_valid(gd):
		return false
	return bool(gd.isAiming) && !bool(gd.isCanted)


func _crosshair_hidden_for_stowed() -> bool:
	if !bool(_cfg.crosshair_hide_while_stowed):
		return false
	var gd: Resource = _game_data
	if gd == null || !is_instance_valid(gd):
		return false
	var any_weapon_out := (
		bool(gd.primary)
		|| bool(gd.secondary)
		|| bool(gd.knife)
		|| bool(gd.grenade1)
		|| bool(gd.grenade2)
	)
	return !any_weapon_out


## `viewport_px`: pass visible viewport size from Main every frame so compass/crosshair can update without running the expensive layout fast path.
## `skip_prefs_guard`: when true, refresh widgets even if escape-menu HUD has vitals disabled — used after inventory panel edits so the overlay matches saved cfg.
## `hud_layer_visible`: when false (menu / forced HUD hide), skip compass/crosshair bearing work — layout already hides them.
func tick(delta_sec: float = -1.0, skip_prefs_guard: bool = false, hud_layer_visible: bool = true, viewport_px: Vector2 = Vector2.ZERO) -> void:
	if !_cfg.enabled || !is_instance_valid(_game_data):
		return
	if bool(_cfg.misc_vital_helmet_enabled) || bool(_cfg.misc_vital_plate_enabled):
		_refresh_equipment_status_cache()
	if hud_layer_visible && _tray != null:
		## When status tray is hidden by config and already invisible, skip `refresh()` work entirely.
		if str(_cfg.status_mode) != "hidden" || _tray.visible:
			_tray.refresh()
	if _permadeath_icon != null:
		_permadeath_icon.tick(_game_data)
	## Compass/crosshair are optional beta features: skip all per-frame chrome work when both are off (no GameData reads, no placement).
	var chrome_on: bool = bool(_cfg.compass_enabled) || bool(_cfg.crosshair_enabled)
	if chrome_on && viewport_px.x > 1.0 && viewport_px.y > 1.0:
		_chrome_quick_layout(viewport_px, hud_layer_visible)
	if chrome_on && hud_layer_visible:
		_tick_compass()
		_tick_crosshair(delta_sec)
	if !skip_prefs_guard && !_prefs_vitals:
		return

	var trans_mode: String = str(_cfg.get_vitals_transparency_mode())
	var static_op_q: int = int(
		round(clampf(float(_cfg.vitals_static_opacity), 0.0, 1.0) * 1000.0)
	)
	var floor_q: int = int(round(clampf(float(_cfg.min_stat_alpha_floor), 0.0, 1.0) * 1000.0))

	var soc_on: bool = bool(_cfg.show_on_change_enabled)
	var soc_min_delta: float = clampf(float(_cfg.show_on_change_min_delta_pct), 0.0, 100.0)
	var soc_dur_ms: int = int(round(clampf(float(_cfg.show_on_change_duration_sec), 0.0, 30.0) * 1000.0))
	var now_ms: int = Time.get_ticks_msec() if soc_on else 0

	var h: int = 2166136261
	h = (h ^ hash(trans_mode)) * 16777619
	h = (h ^ static_op_q) * 16777619
	h = (h ^ floor_q) * 16777619
	h = (h ^ (1 if _force_show_all else 0)) * 16777619
	h = (h ^ (1 if soc_on else 0)) * 16777619

	var idx: int = 0
	for sid in _stat_ids():
		var raw: float = _percent_for(sid)
		var p: float = _normalized_percent(sid, raw)
		var th: float = float(_cfg.get_threshold(sid))
		var show_stat: bool
		if !_is_stat_enabled(sid):
			show_stat = false
		elif _force_show_all || th <= 0.0:
			show_stat = true
		else:
			show_stat = p <= th
		var use_radial: bool = bool(_cfg.get_radial(sid))
		var computed: float = 1.0 - clampf(p, 0.0, 100.0) / 100.0
		var alpha: float = computed

		## Show on Change: arm the expiry window when the stat drops by at least soc_min_delta.
		var soc_active: bool = false
		if soc_on && idx < _soc_last_pct.size():
			var last_p: float = _soc_last_pct[idx]
			if last_p >= 0.0 && (last_p - p) >= soc_min_delta:
				_soc_expiry_ms[idx] = now_ms + soc_dur_ms
			_soc_last_pct[idx] = p
			if _soc_expiry_ms[idx] >= 0:
				if now_ms <= _soc_expiry_ms[idx]:
					soc_active = true
				else:
					_soc_expiry_ms[idx] = -1

		if _force_show_all:
			alpha = 1.0
		elif soc_active:
			show_stat = true
			alpha = 1.0
		elif show_stat:
			match trans_mode:
				"opaque":
					alpha = 1.0
				"static":
					alpha = clampf(float(_cfg.vitals_static_opacity), 0.0, 1.0)
				_:
					var fl: float = float(_cfg.min_stat_alpha_floor)
					alpha = maxf(computed, fl)

		var pi: int = int(round(p * 100.0))
		var ai: int = int(round(alpha * 1000.0))
		h = (h ^ pi) * 16777619
		h = (h ^ ai) * 16777619
		h = (h ^ (1 if show_stat else 0)) * 16777619
		h = (h ^ (1 if use_radial else 0)) * 16777619
		h = (h ^ int(round(th * 10.0))) * 16777619
		h = (h ^ (1 if soc_active else 0)) * 16777619

		_vit_scratch_p[idx] = p
		_vit_scratch_alpha[idx] = alpha
		_vit_show[idx] = 1 if show_stat else 0
		_vit_radial[idx] = 1 if use_radial else 0
		idx += 1

	## Force relayout when the set of vitals participating in strip layout changes.
	var lh: int = 2166136261
	var fill_empty_layout: bool = bool(_cfg.vitals_fill_empty_space)
	lh = (lh ^ (1 if fill_empty_layout else 0)) * 16777619
	var any_soc_active_now: bool = false
	for j in range(idx):
		var active_layout: int = 1
		if fill_empty_layout:
			var soc_lh_active: bool = (
				soc_on && j < _soc_expiry_ms.size()
				&& _soc_expiry_ms[j] >= 0 && now_ms <= _soc_expiry_ms[j]
			)
			if soc_lh_active:
				any_soc_active_now = true
			active_layout = 1 if (_vit_show[j] != 0 && _vit_scratch_alpha[j] > 0.001) || soc_lh_active else 0
		lh = (lh ^ active_layout) * 16777619
	if lh != _last_vitals_layout_hash:
		## When fill-empty is on, stat values cross thresholds continuously during combat/sprinting,
		## triggering a layout pass every frame. Gate these on a 200 ms debounce so layout only fires
		## after the values have been stable for 1/5 s.
		## Exception: SoC activation/expiry must reposition immediately so the vital appears in the
		## correct location without a one-frame flash at (0,0).
		var apply_now := true
		if fill_empty_layout && !any_soc_active_now:
			if _fill_layout_debounce_usec < 0:
				_fill_layout_debounce_usec = Time.get_ticks_usec()
				apply_now = false
			elif Time.get_ticks_usec() - _fill_layout_debounce_usec < _FILL_LAYOUT_DEBOUNCE_USEC:
				apply_now = false
		if apply_now:
			_last_vitals_layout_hash = lh
			_layout_revision += 1
			_fill_layout_debounce_usec = -1
	else:
		_fill_layout_debounce_usec = -1

	if !skip_prefs_guard && h == _last_vitals_tick_hash:
		return
	_last_vitals_tick_hash = h

	for j in range(idx):
		var sid2: StringName = _stat_ids()[j]
		var w := _widgets.get(sid2) as STAT_WIDGET_SCRIPT
		if w != null:
			w.update_display(
				_vit_scratch_p[j],
				_vit_show[j] != 0,
				_vit_radial[j] != 0,
				_vit_scratch_alpha[j]
			)


func _tick_compass() -> void:
	if _compass == null || !bool(_cfg.compass_enabled):
		return
	if !_compass.visible:
		return
	var bearing := _bearing_from_game_data()
	if (_compass as Object).has_method(&"set_bearing_degrees"):
		(_compass as Object).call(&"set_bearing_degrees", bearing)


func _tick_crosshair(delta_sec: float) -> void:
	if _crosshair == null || !bool(_cfg.crosshair_enabled):
		return
	if !_crosshair.visible:
		return
	if !bool(_cfg.crosshair_bloom_enabled):
		if !is_equal_approx(_crosshair_bloom_px, 0.0):
			_crosshair_bloom_px = 0.0
			if (_crosshair as Object).has_method(&"set_bloom_radius_px"):
				(_crosshair as Node).call(&"set_bloom_radius_px", _crosshair_bloom_px)
		return
	var dt: float = delta_sec
	if dt < 0.0:
		dt = 1.0 / 60.0
	var target_px: float = _estimate_bloom_radius_px()
	# Responsive but smooth.
	var t := clampf(dt * 14.0, 0.0, 1.0)
	_crosshair_bloom_px = lerpf(_crosshair_bloom_px, target_px, t)
	if (_crosshair as Object).has_method(&"set_bloom_radius_px"):
		(_crosshair as Node).call(&"set_bloom_radius_px", _crosshair_bloom_px)


func _estimate_bloom_radius_px() -> float:
	var spread_deg := _read_runtime_spread_degrees()
	if spread_deg < 0.0:
		spread_deg = _heuristic_spread_degrees()
	var scale_mul := clampf(float(_cfg.crosshair_scale_pct) / 100.0, 0.25, 3.0)
	# 1.0 degree maps to 18 px at 100% scale.
	return clampf(spread_deg * 18.0 * scale_mul, 0.0, 56.0 * scale_mul)


func _read_runtime_spread_degrees() -> float:
	if _game_data == null || !is_instance_valid(_game_data):
		_spread_key_hint_idx = -1
		return -1.0
	var gd: Resource = _game_data
	var hint := _spread_key_hint_idx
	if hint >= 0 && hint < _GAME_DATA_SPREAD_KEYS.size():
		var vh: Variant = gd.get(_GAME_DATA_SPREAD_KEYS[hint])
		if vh != null:
			var fh := float(vh)
			if fh >= 0.0:
				return fh
	for i in range(_GAME_DATA_SPREAD_KEYS.size()):
		var v: Variant = gd.get(_GAME_DATA_SPREAD_KEYS[i])
		if v != null:
			var f := float(v)
			if f >= 0.0:
				_spread_key_hint_idx = i
				return f
	_spread_key_hint_idx = -1
	return -1.0


func _heuristic_spread_degrees() -> float:
	if _game_data == null || !is_instance_valid(_game_data):
		return 0.35
	var s: float = 0.35
	if bool(_game_data.get("isAiming")) || bool(_game_data.get("isScoped")):
		s = 0.12
	if bool(_game_data.get("isRunning")):
		s += 0.85
	elif bool(_game_data.get("isMoving")):
		s += 0.35
	if bool(_game_data.get("isCrouching")):
		s = maxf(0.06, s - 0.10)
	var weapon_pos: int = int(_game_data.get("weaponPosition"))
	if weapon_pos != 2:
		s += 0.25
	if bool(_game_data.get("isFiring")):
		s += 0.30
	return clampf(s, 0.02, 2.5)


func _bearing_from_game_data() -> float:
	if _game_data == null || !is_instance_valid(_game_data):
		_bearing_have_cache = false
		return 0.0
	var pv: Variant = _game_data.get("playerVector")
	if pv is Vector3:
		var v: Vector3 = pv as Vector3
		if _bearing_have_cache && v.distance_squared_to(_bearing_cache_pv) < 1e-12:
			return _bearing_cache_deg
		if v.length() > 0.001:
			var dir := v.normalized()
			var yaw := rad_to_deg(atan2(dir.x, dir.z))
			_bearing_cache_pv = v
			_bearing_have_cache = true
			_bearing_cache_deg = wrapf(yaw, 0.0, 360.0)
			return _bearing_cache_deg
	_bearing_have_cache = false
	return 0.0


func _uses_radial_mode() -> bool:
	if _cfg == null:
		return false
	for sid in _stat_ids():
		if !_is_stat_enabled(sid):
			continue
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
		&"helmet":
			return _helmet_percent_cached
		&"cat":
			return _game_data.cat if bool(_game_data.get("catFound")) && !bool(_game_data.get("catDead")) else 0.0
		&"plate":
			return _plate_percent_cached
	return 0.0


func _is_stat_enabled(sid: StringName) -> bool:
	match sid:
		&"helmet":
			return bool(_cfg.misc_vital_helmet_enabled) && _helmet_available_cached
		&"cat":
			return bool(_cfg.misc_vital_cat_enabled) && bool(_game_data.get("catFound")) && !bool(_game_data.get("catDead"))
		&"plate":
			return bool(_cfg.misc_vital_plate_enabled) && _plate_available_cached
		_:
			return true


func _refresh_equipment_status_cache() -> void:
	if !bool(_cfg.misc_vital_helmet_enabled) && !bool(_cfg.misc_vital_plate_enabled):
		_helmet_percent_cached = 0.0
		_plate_percent_cached = 0.0
		_helmet_available_cached = false
		_plate_available_cached = false
		return
	var frame := Engine.get_process_frames()
	if frame < _next_interface_probe_frame:
		return
	_next_interface_probe_frame = frame + _INTERFACE_PROBE_INTERVAL_FRAMES
	var ui := _resolve_interface_node()
	if ui == null:
		_helmet_percent_cached = 0.0
		_plate_percent_cached = 0.0
		_helmet_available_cached = false
		_plate_available_cached = false
		return
	_helmet_percent_cached = _read_slot_condition_percent(ui, 8)
	_plate_percent_cached = _read_plate_condition_percent(ui, 7)
	_helmet_available_cached = _helmet_percent_cached >= 0.0
	_plate_available_cached = _plate_percent_cached >= 0.0
	if !_helmet_available_cached:
		_helmet_percent_cached = 0.0
	if !_plate_available_cached:
		_plate_percent_cached = 0.0


func _resolve_interface_node() -> Node:
	if _interface_node != null && is_instance_valid(_interface_node):
		return _interface_node
	var tree := get_tree()
	if tree == null || tree.root == null:
		return null
	var stack: Array = [tree.root]
	while !stack.is_empty():
		var n: Node = stack.pop_back()
		if n != null && str(n.name) == "Interface" && n.get("equipmentUI") != null:
			_interface_node = n
			return _interface_node
		for c in n.get_children():
			stack.append(c)
	return null


func _read_plate_condition_percent(interface_node: Node, slot_idx: int) -> float:
	var equipment_ui: Node = interface_node.get("equipmentUI") as Node
	if equipment_ui == null || slot_idx < 0 || slot_idx >= equipment_ui.get_child_count():
		return -1.0
	var slot := equipment_ui.get_child(slot_idx)
	if slot == null || slot.get_child_count() == 0:
		return -1.0
	var item_node: Node = slot.get_child(0)
	var slot_data: Variant = item_node.get("slotData")
	if slot_data == null:
		return -1.0
	var nested: Variant = slot_data.get("nested")
	if nested is Array:
		for nv in nested as Array:
			if nv == null:
				continue
			var t := str(nv.get("type", ""))
			if t == "Armor":
				return clampf(float(slot_data.get("condition", 0.0)), 0.0, 100.0)
	return -1.0


func _read_slot_condition_percent(interface_node: Node, slot_idx: int) -> float:
	var equipment_ui: Node = interface_node.get("equipmentUI") as Node
	if equipment_ui == null || slot_idx < 0 || slot_idx >= equipment_ui.get_child_count():
		return -1.0
	var slot := equipment_ui.get_child(slot_idx)
	if slot == null || slot.get_child_count() == 0:
		return -1.0
	var item_node: Node = slot.get_child(0)
	var slot_data: Variant = item_node.get("slotData")
	if slot_data == null:
		return -1.0
	return clampf(float(slot_data.get("condition", 0.0)), 0.0, 100.0)

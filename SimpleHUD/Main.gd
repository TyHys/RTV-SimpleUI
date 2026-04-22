extends Node

## Same pattern as BikeMod: path from scene tree root, not "/root/Map/..." (that breaks when resolved from root).
const SimpleHUDConfigScript := preload("res://SimpleHUD/Config.gd")
const SimpleHudOverlay := preload("res://SimpleHUD/HudOverlay.gd")

var game_data: Resource = preload("res://Resources/GameData.tres")

var _cfg: RefCounted
var _hud: Control
var _canvas_layer: CanvasLayer
var _overlay: SimpleHudOverlay

## Runtime `GameData` the game mutates (often not the same object identity as preload if the scene holds a live ref).
var _live_game_data: Resource = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cfg = SimpleHUDConfigScript.new()
	_cfg.load_all()


func _process(delta: float) -> void:
	if !_cfg.enabled:
		return

	var hud: Control = _resolve_hud()
	if hud == null:
		_clear_binding()
		return

	if _hud == hud && is_instance_valid(_overlay):
		_apply_overlay(hud, delta)
		return

	_bind_hud(hud)


func _bind_hud(hud: Control) -> void:
	_clear_binding()
	_hud = hud

	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "SimpleHUDCanvas"
	_canvas_layer.layer = 128
	_canvas_layer.follow_viewport_enabled = true
	get_tree().root.add_child(_canvas_layer)

	_overlay = SimpleHudOverlay.new()
	_overlay.setup(game_data, _cfg)
	_overlay.visible = true
	_canvas_layer.add_child(_overlay)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_apply_overlay(hud, 0.0)


func _apply_overlay(hud: Control, delta: float) -> void:
	if !is_instance_valid(_overlay):
		return

	var prefs := _load_preferences()

	var vitals_on: bool = _prefs_bool(prefs, &"vitals", true)
	var medical_on: bool = _prefs_bool(prefs, &"medical", true)

	_overlay.configure_hud_prefs(vitals_on, medical_on)

	_sync_vanilla_hud_overrides(hud, vitals_on, medical_on)

	var live := _resolve_live_game_data(hud)
	_overlay.set_live_game_data(live)

	var menu_hide: bool = false
	if live != null:
		menu_hide = bool(live.menu)

	# Drive our vitals strip only from pause/menu — not from HUD/Stats.visible. The game may hide the
	# Stats node while gameplay values are still meaningful; tying show_layer to it skipped tick()
	# and left the overlay blank (no updates, widgets never filled in).
	var show_layer: bool = !menu_hide

	_overlay.layout_for_viewport(get_viewport().get_visible_rect().size, show_layer)

	if show_layer:
		_overlay.tick(delta)

	_apply_fps_map(hud, prefs)


## Escape menu / Settings toggles (Preferences.tres). When true, we hide vanilla rows and draw replacements.
func _sync_vanilla_hud_overrides(hud: Control, vitals_on: bool, medical_on: bool) -> void:
	var vn := hud.get_node_or_null("Stats/Vitals") as Control
	if vn != null && vitals_on:
		vn.visible = false

	var mn := hud.get_node_or_null("Stats/Medical") as Control
	if mn != null && medical_on:
		mn.visible = false


func _load_preferences() -> Resource:
	return load("user://Preferences.tres") as Resource


func _prefs_bool(prefs: Resource, key: StringName, fallback: bool) -> bool:
	if prefs == null:
		return fallback
	var v: Variant = prefs.get(key)
	if v == null:
		return fallback
	return bool(v)


## Targets HUD/Info (same nodes Settings → HUD.ShowMap / ShowFPS affect). Visibility is driven by vanilla + prefs.map / prefs.FPS.
func _apply_fps_map(hud: Control, prefs: Resource) -> void:
	var info := hud.get_node_or_null("Info") as Control
	if info == null:
		return

	info.scale = Vector2(_cfg.fps_map_scale, _cfg.fps_map_scale)
	info.position = Vector2(_cfg.fps_map_offset_x, _cfg.fps_map_offset_y)
	var a: float = clampf(float(_cfg.fps_map_alpha), 0.0, 1.0)
	info.modulate = Color(1.0, 1.0, 1.0, a)

	# Keep only the numeric FPS readout and force it white for readability.
	var fps_label := info.get_node_or_null("FPS") as Label
	if fps_label != null:
		var fps_text := fps_label.text.strip_edges()
		if fps_text.begins_with("FPS"):
			fps_text = fps_text.trim_prefix("FPS")
			if fps_text.begins_with(":"):
				fps_text = fps_text.trim_prefix(":")
			fps_text = fps_text.strip_edges()
		fps_label.text = fps_text
		fps_label.add_theme_color_override("font_color", Color.WHITE)

	var fps_value := info.get_node_or_null("FPS/Frames") as Label
	if fps_value != null:
		var val_text := fps_value.text.strip_edges()
		if val_text.begins_with("FPS"):
			val_text = val_text.trim_prefix("FPS")
			if val_text.begins_with(":"):
				val_text = val_text.trim_prefix(":")
			val_text = val_text.strip_edges()
		fps_value.text = val_text
		fps_value.add_theme_color_override("font_color", Color.WHITE)
		fps_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Vanilla scene offsets Frames by +36 to clear "FPS:"; collapse that gap.
		fps_value.offset_left = 0.0
		fps_value.offset_right = 40.0


func _clear_binding() -> void:
	if is_instance_valid(_canvas_layer):
		_canvas_layer.queue_free()
	elif is_instance_valid(_overlay):
		_overlay.queue_free()
	_canvas_layer = null
	_overlay = null
	_hud = null
	_live_game_data = null


func _resolve_live_game_data(for_hud: Control) -> Resource:
	if _live_game_data != null && is_instance_valid(_live_game_data):
		return _live_game_data

	var f := Engine.get_process_frames()
	if for_hud == null && f >= 180 && f % 60 != 0:
		return game_data

	var found: Resource = null

	if for_hud != null:
		for kn in ["game_data", "gameData", "GameData", "data", "playerData", "player_data", "state"]:
			var v: Variant = for_hud.get(kn)
			if v is Resource && _resource_is_game_data(v as Resource):
				found = v as Resource
				break
		if found == null:
			found = _extract_game_data_from_object(for_hud)
		if found == null:
			found = _scan_parents_for_game_data(for_hud)
		if found == null:
			found = _scan_node_for_game_data(for_hud, 0, 14)

	var tree := get_tree()
	if tree == null:
		return game_data

	if found == null:
		var root := tree.root
		for nm in [&"GameData", &"game_data", &"Game", &"World", &"UI", &"UIManager", &"Interface"]:
			var qn := root.get_node_or_null(NodePath(str(nm)))
			if qn != null:
				found = _extract_game_data_from_object(qn)
				if found != null:
					break

	if found == null:
		found = _scan_tree_for_game_data(tree.current_scene)
	if found == null:
		found = _scan_tree_for_game_data(tree.root)

	if found != null && _resource_is_game_data(found):
		_live_game_data = found
		return _live_game_data

	return game_data


func _scan_parents_for_game_data(hud: Control) -> Resource:
	var n: Node = hud.get_parent()
	var depth := 0
	while n != null && depth < 32:
		var r := _extract_game_data_from_object(n)
		if r != null:
			return r
		for kn in ["game_data", "gameData", "GameData", "data", "playerData", "player_state"]:
			var v: Variant = n.get(kn)
			if v is Resource && _resource_is_game_data(v as Resource):
				return v as Resource
		n = n.get_parent()
		depth += 1
	return null


func _scan_tree_for_game_data(from: Node) -> Resource:
	if from == null:
		return null
	return _scan_node_for_game_data(from, 0, 24)


func _scan_node_for_game_data(n: Node, depth: int, max_depth: int) -> Resource:
	if depth > max_depth:
		return null
	var r := _extract_game_data_from_object(n)
	if r != null:
		return r
	for c in n.get_children():
		var rr := _scan_node_for_game_data(c, depth + 1, max_depth)
		if rr != null:
			return rr
	return null


func _extract_game_data_from_object(o: Object) -> Resource:
	if o is Resource && _resource_is_game_data(o as Resource):
		return o as Resource
	if o is Node:
		var node := o as Node
		for pi in node.get_property_list():
			if pi is not Dictionary:
				continue
			var key := String(pi.get("name", ""))
			if key.is_empty():
				continue
			var v: Variant = node.get(key)
			if v is Resource:
				var res := v as Resource
				if _resource_is_game_data(res):
					return res
	return null


func _resource_is_game_data(res: Resource) -> bool:
	var has_h := false
	var has_hy := false
	for p in res.get_property_list():
		match String(p.name):
			"health":
				has_h = true
			"hydration":
				has_hy = true
			_:
				pass
	return has_h && has_hy


func _resolve_hud() -> Control:
	var tree := get_tree()
	var r := tree.root
	var cs := tree.current_scene

	if cs != null:
		var abs_hud := cs.get_node_or_null("/root/Map/Core/UI/HUD") as Control
		if abs_hud != null:
			return abs_hud
		var core_hud := cs.get_node_or_null("Core/UI/HUD") as Control
		if core_hud != null:
			return core_hud
		var map_hud := cs.get_node_or_null("Map/Core/UI/HUD") as Control
		if map_hud != null:
			return map_hud

	var rel := r.get_node_or_null("Map/Core/UI/HUD") as Control
	if rel != null:
		return rel

	return _find_hud_control(r)


func _find_hud_control(from: Node) -> Control:
	for n in from.get_children():
		var h := _find_hud_control(n)
		if h != null:
			return h
	if from is Control && str(from.name) == "HUD":
		var c := from as Control
		if c.has_node("Stats") && c.has_node("Info"):
			return c
	return null

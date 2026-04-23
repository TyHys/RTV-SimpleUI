extends Control

var _game_data: Resource
var _cfg: RefCounted

var _box: Container
var _icon_nodes: Dictionary = {}
static var _texture_cache: Dictionary = {}

func setup(game_data: Resource, cfg: RefCounted) -> void:
	_game_data = game_data
	_cfg = cfg

	var horizontal: bool = str(_cfg.status_stack_direction) == "horizontal_left"
	var rebuild := _box == null
	if !rebuild:
		rebuild = horizontal && !(_box is HBoxContainer)
	if !rebuild:
		rebuild = !horizontal && !(_box is VBoxContainer)
	if rebuild:
		for c in get_children():
			c.queue_free()
		_icon_nodes.clear()
		if horizontal:
			_box = HBoxContainer.new()
		else:
			_box = VBoxContainer.new()
		add_child(_box)
		_box.set_anchors_preset(Control.PRESET_FULL_RECT)
		_box.offset_left = 0.0
		_box.offset_top = 0.0
		_box.offset_right = 0.0
		_box.offset_bottom = 0.0
		_ensure_icon_nodes()
	elif _icon_nodes.is_empty():
		_ensure_icon_nodes()

	match str(_cfg.get_status_strip_alignment()):
		"center":
			_box.alignment = BoxContainer.ALIGNMENT_CENTER
		"trailing":
			_box.alignment = BoxContainer.ALIGNMENT_END
		_:
			_box.alignment = BoxContainer.ALIGNMENT_BEGIN

	_box.add_theme_constant_override("separation", int(_cfg.status_spacing_px))

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)


func rebuild_from_cfg() -> void:
	setup(_game_data, _cfg)
	refresh()


func set_game_data(r: Resource) -> void:
	if r != null && is_instance_valid(r):
		_game_data = r


static func _icon_paths() -> Array:
	return [
		[&"overweight", "res://UI/Sprites/Icon_Overweight.png"],
		[&"starvation", "res://UI/Sprites/Icon_Starvation.png"],
		[&"dehydration", "res://UI/Sprites/Icon_Dehydration.png"],
		[&"bleeding", "res://UI/Sprites/Icon_Bleeding.png"],
		[&"fracture", "res://UI/Sprites/Icon_Fracture.png"],
		[&"burn", "res://UI/Sprites/Icon_Burn.png"],
		[&"frostbite", "res://UI/Sprites/Icon_Frostbite.png"],
		[&"insanity", "res://UI/Sprites/Icon_Insanity.png"],
		[&"poisoning", "res://UI/Sprites/Icon_Poisoning.png"],
		[&"rupture", "res://UI/Sprites/Icon_Rupture.png"],
		[&"headshot", "res://UI/Sprites/Icon_Headshot.png"],
	]


func refresh() -> void:
	if !is_instance_valid(_game_data) || _box == null:
		return

	var mode: String = str(_cfg.status_mode)
	if mode == "hidden":
		visible = false
		return

	visible = true
	var fill_empty: bool = bool(_cfg.status_fill_empty_space)
	var active_color: Color = _cfg.get_status_icon_color()
	var inactive_rgb: Color = _cfg.get_status_inactive_icon_color()
	var ina: float = clampf(float(_cfg.status_inactive_alpha), 0.0, 1.0)
	var px := float(_cfg.status_icon_size_px) * float(_cfg.status_scale_pct) / 100.0

	for row in _icon_paths():
		var flag: StringName = row[0]
		var path: String = row[1]
		var tr := _icon_nodes.get(flag, null) as TextureRect
		if tr == null:
			continue
		# Retry icon load lazily if initial setup occurred before resource became available.
		if tr.texture == null:
			tr.texture = _load_texture_cached(path)
		var active := _flag_active(flag)
		var hidden_by_mode := mode == "inflicted_only" && !active
		var hidden_by_alpha := !active && mode == "always" && ina <= 0.001
		var hide_icon := hidden_by_mode || hidden_by_alpha
		if fill_empty:
			tr.visible = !hide_icon
		else:
			tr.visible = true

		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2.ONE * px
		tr.size = tr.custom_minimum_size
		tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		match mode:
			"always":
				tr.modulate = active_color if active else Color(inactive_rgb.r, inactive_rgb.g, inactive_rgb.b, ina)
			_:
				tr.modulate = active_color if active || fill_empty else Color(active_color.r, active_color.g, active_color.b, 0.0)

	var min_size: Vector2 = _box.get_combined_minimum_size()
	var base_px := float(_cfg.status_icon_size_px) * float(_cfg.status_scale_pct) / 100.0
	if min_size.x <= 0.0 || min_size.y <= 0.0:
		min_size = Vector2.ONE * base_px
	custom_minimum_size = min_size
	size = min_size


func get_icon_count() -> int:
	if _box == null:
		return 0
	var count := 0
	for c in _box.get_children():
		if c is CanvasItem && (c as CanvasItem).visible:
			count += 1
	return count


func _ensure_icon_nodes() -> void:
	if _box == null:
		return
	for row in _icon_paths():
		var flag: StringName = row[0]
		var path: String = row[1]
		var tr := TextureRect.new()
		tr.name = String(flag)
		tr.texture = _load_texture_cached(path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_box.add_child(tr)
		_icon_nodes[flag] = tr


func _load_texture_cached(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	var tex: Texture2D = load(path) as Texture2D
	if tex != null:
		_texture_cache[path] = tex
	return tex


func _flag_active(flag: StringName) -> bool:
	match flag:
		&"overweight":
			return _status_flag_bool(["overweight"])
		&"starvation":
			return _status_flag_bool(["starvation"])
		&"dehydration":
			return _status_flag_bool(["dehydration"])
		&"bleeding":
			return _status_flag_bool(["bleeding"])
		&"fracture":
			return _status_flag_bool(["fracture"])
		&"burn":
			return _status_flag_bool(["burn"])
		&"frostbite":
			return _status_flag_bool(["frostbite"])
		&"insanity":
			return _status_flag_bool(["insanity"])
		&"poisoning":
			return _status_flag_bool(["poisoning"])
		&"rupture":
			return _status_flag_bool(["rupture"])
		&"headshot":
			return _status_flag_bool(["headshot", "head_shot"])
		_:
			return false


func _status_flag_bool(keys: Array) -> bool:
	if _game_data == null || !is_instance_valid(_game_data):
		return false
	for k in keys:
		var key: String = str(k)
		var v: Variant = _game_data.get(key)
		if v != null:
			return bool(v)
	return false

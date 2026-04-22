extends Control

var _game_data: Resource
var _cfg: RefCounted

var _box: Container

func setup(game_data: Resource, cfg: RefCounted) -> void:
	_game_data = game_data
	_cfg = cfg

	for c in get_children():
		c.queue_free()

	if _cfg.status_stack_direction == "horizontal_left":
		_box = HBoxContainer.new()
	else:
		var vb := VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_END
		_box = vb

	_box.add_theme_constant_override("separation", int(_cfg.status_spacing_px))
	add_child(_box)
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.offset_left = 0.0
	_box.offset_top = 0.0
	_box.offset_right = 0.0
	_box.offset_bottom = 0.0

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)


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
	if !visible:
		return
	if !is_instance_valid(_game_data) || _box == null:
		return

	var mode: String = str(_cfg.status_mode)
	for c in _box.get_children():
		c.queue_free()

	if mode == "hidden":
		visible = false
		return

	visible = true

	for row in _icon_paths():
		var flag: StringName = row[0]
		var path: String = row[1]
		var active := false
		match flag:
			&"overweight":
				active = _game_data.overweight
			&"starvation":
				active = _game_data.starvation
			&"dehydration":
				active = _game_data.dehydration
			&"bleeding":
				active = _game_data.bleeding
			&"fracture":
				active = _game_data.fracture
			&"burn":
				active = _game_data.burn
			&"frostbite":
				active = _game_data.frostbite
			&"insanity":
				active = _game_data.insanity
			&"poisoning":
				active = _game_data.poisoning
			&"rupture":
				active = _game_data.rupture
			&"headshot":
				active = _game_data.headshot

		if mode == "inflicted_only" && !active:
			continue

		var tex: Texture2D = load(path)
		if tex == null:
			continue

		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2.ONE * float(_cfg.status_icon_size_px)
		tr.size = tr.custom_minimum_size
		tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var active_color: Color = _cfg.get_status_icon_color()
		match mode:
			"always":
				tr.modulate = active_color if active else Color(active_color.r, active_color.g, active_color.b, 0.25)
			_:
				tr.modulate = active_color

		_box.add_child(tr)

	var min_size: Vector2 = _box.get_combined_minimum_size()
	if min_size.x <= 0.0 || min_size.y <= 0.0:
		min_size = Vector2.ONE * float(_cfg.status_icon_size_px)
	custom_minimum_size = min_size
	size = min_size


func _physics_process(_delta: float) -> void:
	if Engine.get_physics_frames() % 12 == 0:
		refresh()

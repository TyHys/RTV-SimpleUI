extends Control

var _game_data: Resource
var _cfg: RefCounted

var _box: Container
var _icon_nodes: Dictionary = {}
static var _texture_cache: Dictionary = {}

## Integer compare only (no string `hash()` / per-frame signature rebuild). Invalid = force full pass.
var _last_game_bits: int = -1
var _last_tex_bits: int = -1
var _last_cfg_fast: int = -2147483648
## Updated whenever a full `refresh()` runs; used by HudOverlay tray layout / auto-hide.
var _cached_visible_icon_count: int = 0
## True after a full `refresh()` path updates icons/minimum size; HudOverlay consumes this to skip redundant outer `get_combined_minimum_size()`.
var _minimum_invalidated: bool = true

func setup(game_data: Resource, cfg: RefCounted) -> void:
	_game_data = game_data
	_cfg = cfg
	## Always invalidate the config snapshot so the next refresh() picks up any changes,
	## even when the box layout itself doesn't need a rebuild (e.g. icon color change).
	_last_cfg_fast = -2147483648

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
		_last_game_bits = -1
		_last_tex_bits = -1
		_last_cfg_fast = -2147483648
		_cached_visible_icon_count = 0
		_minimum_invalidated = true
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


static var _cached_icon_paths: Array = []

static func _icon_paths() -> Array:
	if _cached_icon_paths.is_empty():
		_cached_icon_paths = [
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
	return _cached_icon_paths


func _cfg_fast_id(
	mode: String,
	fill_empty: bool,
	px: float,
	ina: float,
	active_color: Color,
	inactive_rgb: Color,
) -> int:
	var m := 3
	match mode:
		"hidden":
			m = 0
		"always":
			m = 1
		"inflicted_only":
			m = 2
	var sig := 2166136261
	sig = (sig ^ m) * 16777619
	sig = (sig ^ (1 if fill_empty else 0)) * 16777619
	sig = (sig ^ int(px * 1000.0)) * 16777619
	sig = (sig ^ int(ina * 4000.0)) * 16777619
	sig = (sig ^ int(active_color.to_rgba32())) * 16777619
	sig = (sig ^ int(Color(inactive_rgb.r, inactive_rgb.g, inactive_rgb.b, 1.0).to_rgba32())) * 16777619
	sig = (sig ^ int(_cfg.status_spacing_px)) * 16777619
	return sig


func refresh() -> void:
	if !is_instance_valid(_game_data) || _box == null:
		return

	var mode: String = str(_cfg.status_mode)
	if mode == "hidden":
		visible = false
		_last_game_bits = -1
		_last_tex_bits = -1
		_last_cfg_fast = -2147483648
		_cached_visible_icon_count = 0
		return

	visible = true
	var fill_empty: bool = bool(_cfg.status_fill_empty_space)
	var active_color: Color = _cfg.get_status_icon_color()
	var inactive_rgb: Color = _cfg.get_status_inactive_icon_color()
	var ina: float = clampf(float(_cfg.status_inactive_alpha), 0.0, 1.0)
	var px := float(_cfg.status_icon_size_px) * float(_cfg.status_scale_pct) / 100.0

	var gd: Resource = _game_data
	var bits := 0
	if bool(gd.get(&"overweight")):
		bits |= 1 << 0
	if bool(gd.get(&"starvation")):
		bits |= 1 << 1
	if bool(gd.get(&"dehydration")):
		bits |= 1 << 2
	if bool(gd.get(&"bleeding")):
		bits |= 1 << 3
	if bool(gd.get(&"fracture")):
		bits |= 1 << 4
	if bool(gd.get(&"burn")):
		bits |= 1 << 5
	if bool(gd.get(&"frostbite")):
		bits |= 1 << 6
	if bool(gd.get(&"insanity")):
		bits |= 1 << 7
	if bool(gd.get(&"poisoning")):
		bits |= 1 << 8
	if bool(gd.get(&"rupture")):
		bits |= 1 << 9
	## Use only the canonical `headshot` ailment flag; `head_shot` can be set in non-ailment contexts and caused false positives.
	if bool(gd.get(&"headshot")):
		bits |= 1 << 10

	var tex_bits := 0
	var bit_i := 0
	for row in _icon_paths():
		var tr0: TextureRect = _icon_nodes.get(row[0], null) as TextureRect
		if tr0 != null && tr0.texture != null:
			tex_bits |= (1 << bit_i)
		bit_i += 1

	## Cheap early-exit: game state and textures unchanged, and config hasn't been reset by setup().
	## Skips the Color-constructing _cfg_fast_id() call in the common steady-state.
	if bits == _last_game_bits && tex_bits == _last_tex_bits && _last_cfg_fast != -2147483648:
		return
	var cfg_fast := _cfg_fast_id(mode, fill_empty, px, ina, active_color, inactive_rgb)
	if bits == _last_game_bits && tex_bits == _last_tex_bits && cfg_fast == _last_cfg_fast:
		return

	_minimum_invalidated = true

	var visible_children := 0

	var apply_i := 0
	for row in _icon_paths():
		var flag: StringName = row[0]
		var path: String = row[1]
		var tr := _icon_nodes.get(flag, null) as TextureRect
		if tr == null:
			apply_i += 1
			continue
		# Retry icon load lazily if initial setup occurred before resource became available.
		if tr.texture == null:
			tr.texture = _load_texture_cached(path)
		var active := (bits & (1 << apply_i)) != 0
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

		if tr.visible:
			visible_children += 1
		apply_i += 1

	var min_size: Vector2 = _box.get_combined_minimum_size()
	var base_px := float(_cfg.status_icon_size_px) * float(_cfg.status_scale_pct) / 100.0
	if min_size.x <= 0.0 || min_size.y <= 0.0:
		min_size = Vector2.ONE * base_px
	custom_minimum_size = min_size
	size = min_size
	_cached_visible_icon_count = visible_children
	_last_game_bits = bits
	_last_tex_bits = tex_bits
	_last_cfg_fast = cfg_fast


func get_icon_count() -> int:
	return _cached_visible_icon_count


func consume_minimum_invalidated() -> bool:
	var r := _minimum_invalidated
	_minimum_invalidated = false
	return r


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

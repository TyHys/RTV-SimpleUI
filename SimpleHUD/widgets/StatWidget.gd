extends Control

const RADIAL_SCRIPT := preload("res://SimpleHUD/widgets/RadialStat.gd")
const SimpleHudConfigScript := preload("res://SimpleHUD/Config.gd")
const STAT_ICON_PATHS := {
	&"health": "res://SimpleHUD/icons/hp_icon.png",
	&"energy": "res://SimpleHUD/icons/hunger_icon.png",
	&"hydration": "res://SimpleHUD/icons/hydration_icon.png",
	&"mental": "res://SimpleHUD/icons/mental_icon.png",
	&"body_temp": "res://SimpleHUD/icons/temperature_icon.png",
	&"stamina": "res://SimpleHUD/icons/stamina_icon.png",
	&"fatigue": "res://SimpleHUD/icons/fatigue_icon.png",
}

var stat_id: StringName
var title: String = ""

var _label: Label
var _radial: RADIAL_SCRIPT
var _built_radial: bool = false
var _cfg: RefCounted

func setup(p_stat_id: StringName, p_title: String, _game_data: Resource, use_radial: bool, cfg: RefCounted = null) -> void:
	stat_id = p_stat_id
	title = p_title
	if cfg != null:
		_cfg = cfg

	for c in get_children():
		c.queue_free()
	_radial = null
	_label = null

	custom_minimum_size = Vector2(56, 56) if use_radial else Vector2(72, 36)

	if use_radial:
		var r: RADIAL_SCRIPT = RADIAL_SCRIPT.new()
		r.custom_minimum_size = Vector2(52, 52)
		r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var icon_path: String = str(STAT_ICON_PATHS.get(stat_id, ""))
		if icon_path != "":
			var tex: Texture2D = _load_icon_texture(icon_path)
			if tex != null:
				r.set_icon(tex)
		add_child(r)
		_radial = r
	else:
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05, 1.0))
		l.add_theme_constant_override("outline_size", 6)
		add_child(l)
		_label = l

	_built_radial = use_radial

func update_display(percent: float, visible_rule: bool, use_radial: bool, alpha_mult: float) -> void:
	if use_radial != _built_radial:
		setup(stat_id, title, null, use_radial, _cfg)

	modulate.a = alpha_mult
	visible = visible_rule
	if !visible_rule:
		return

	if use_radial && _radial != null:
		_radial.set_ratio(percent / 100.0)
		var rc := Color.WHITE
		var cfg_radial := _cfg as SimpleHudConfigScript
		if cfg_radial != null:
			rc = cfg_radial.get_stat_text_color(percent)
		_radial.set_progress_color(rc)
	elif _label:
		_label.text = "%s %d" % [title, int(round(percent))]
	_apply_text_color(percent)

func _apply_text_color(percent: float) -> void:
	var c := Color.WHITE
	var cfg_txt := _cfg as SimpleHudConfigScript
	if cfg_txt != null:
		c = cfg_txt.get_stat_text_color(percent)
	if _label:
		_label.add_theme_color_override("font_color", c)


func _load_icon_texture(path: String) -> Texture2D:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null

	var img := Image.new()
	var lower := path.to_lower()
	var err := ERR_FILE_UNRECOGNIZED
	if lower.ends_with(".png"):
		err = img.load_png_from_buffer(bytes)
	elif lower.ends_with(".jpg") || lower.ends_with(".jpeg"):
		err = img.load_jpg_from_buffer(bytes)
	elif lower.ends_with(".webp"):
		err = img.load_webp_from_buffer(bytes)
	elif lower.ends_with(".svg"):
		err = img.load_svg_from_buffer(bytes, 1.0)
	else:
		return null

	if err != OK:
		return null
	return ImageTexture.create_from_image(img)

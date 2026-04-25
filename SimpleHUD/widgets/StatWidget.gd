extends Control

const RADIAL_SCRIPT := preload("res://SimpleHUD/widgets/RadialStat.gd")
const SimpleHudConfigScript := preload("res://SimpleHUD/SimpleHUDConfigCore.gd")
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
var _last_layout_scale: float = -1.0
var _last_layout_radial: bool = false
var _last_numeric_percent: int = -999999
var _last_label_color_rgba: int = -1
var _last_gradient_color_bucket: int = -2147483648
var _cached_gradient_color: Color = Color.WHITE
var _last_alpha_permille: int = -1

const _BASE_FONT := 13
const _BASE_OUTLINE := 6

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
	_last_layout_scale = -1.0
	_last_layout_radial = use_radial
	_last_numeric_percent = -999999
	_last_label_color_rgba = -1
	_last_gradient_color_bucket = -2147483648
	_last_alpha_permille = -1
	_sync_layout_scale(true)

func _percent_color_bucket(p: float) -> int:
	if stat_id == SimpleHudConfigScript.STAT_BODY_TEMP:
		return int(round(p * 10.0))
	return int(round(clampf(p, 0.0, 100.0)))


func update_display(percent: float, visible_rule: bool, use_radial: bool, alpha_mult: float) -> void:
	if use_radial != _built_radial:
		setup(stat_id, title, null, use_radial, _cfg)

	if !visible_rule:
		if visible:
			visible = false
		return

	if !visible:
		visible = true

	var ap: int = int(round(clampf(alpha_mult, 0.0, 1.0) * 1000.0))
	if ap != _last_alpha_permille:
		_last_alpha_permille = ap
		modulate.a = alpha_mult

	var cfg_grad := _cfg as SimpleHudConfigScript
	var grad_bucket := _percent_color_bucket(percent)
	if cfg_grad != null && grad_bucket != _last_gradient_color_bucket:
		_last_gradient_color_bucket = grad_bucket
		_cached_gradient_color = cfg_grad.get_stat_text_color_for(stat_id, percent)

	if use_radial && _radial != null:
		_radial.set_ratio(percent / 100.0)
		var rc: Color = _cached_gradient_color if cfg_grad != null else Color.WHITE
		_radial.set_progress_color(rc)
	elif _label:
		var ip := int(round(percent))
		if ip != _last_numeric_percent:
			_last_numeric_percent = ip
			_label.text = "%s %d" % [title, ip]
		var c: Color = _cached_gradient_color if cfg_grad != null else Color.WHITE
		var cr := c.to_rgba32()
		if cr != _last_label_color_rgba:
			_last_label_color_rgba = cr
			_label.add_theme_color_override("font_color", c)
	_sync_layout_scale(false)


func _sync_layout_scale(force: bool) -> void:
	var sc := 1.0
	var cfg_txt := _cfg as SimpleHudConfigScript
	if cfg_txt != null:
		sc = clampf(float(cfg_txt.get_vitals_scale_pct(stat_id)) / 100.0, 0.25, 4.0)

	var use_radial := _built_radial && _radial != null
	if !force && is_equal_approx(sc, _last_layout_scale) && use_radial == _last_layout_radial:
		return
	_last_layout_scale = sc
	_last_layout_radial = use_radial

	if use_radial:
		custom_minimum_size = Vector2(56.0, 56.0) * sc
		if _radial != null:
			_radial.custom_minimum_size = Vector2(52.0, 52.0) * sc
			_radial.ring_width = clampf(5.0 * sc, 2.0, 16.0)
			_radial.icon_size_px = clampf(32.0 * sc, 8.0, 96.0)
	else:
		custom_minimum_size = Vector2(72.0, 36.0) * sc
	if _label:
		var fs := maxi(6, int(round(float(_BASE_FONT) * sc)))
		var ol := maxi(0, int(round(float(_BASE_OUTLINE) * sc)))
		_label.add_theme_font_size_override("font_size", fs)
		_label.add_theme_constant_override("outline_size", ol)


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

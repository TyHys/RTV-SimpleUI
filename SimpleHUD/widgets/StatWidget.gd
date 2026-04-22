extends Control

const RADIAL_SCRIPT := preload("res://SimpleHUD/widgets/RadialStat.gd")

var stat_id: StringName
var title: String = ""

var _label: Label
var _radial: Control
var _caption: Label
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
	_caption = null

	custom_minimum_size = Vector2(52, 62) if use_radial else Vector2(72, 36)

	if use_radial:
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 2)

		var r: Control = RADIAL_SCRIPT.new() as Control
		r.custom_minimum_size = Vector2(44, 44)
		r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(r)

		var cap := Label.new()
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_theme_font_size_override("font_size", 10)
		cap.add_theme_color_override("font_color", Color.WHITE)
		cap.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05, 1.0))
		cap.add_theme_constant_override("outline_size", 6)
		box.add_child(cap)

		add_child(box)
		_radial = r
		_caption = cap
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

	if use_radial && _radial:
		if _radial.has_method("set_ratio"):
			_radial.call("set_ratio", percent / 100.0)
		if _caption:
			_caption.text = "%s %d" % [title, int(round(percent))]
	elif _label:
		_label.text = "%s %d" % [title, int(round(percent))]
	_apply_text_color(percent)

func _apply_text_color(percent: float) -> void:
	var c := Color.WHITE
	if _cfg != null && _cfg.has_method("get_stat_text_color"):
		c = _cfg.call("get_stat_text_color", percent)
	if _caption:
		_caption.add_theme_color_override("font_color", c)
	if _label:
		_label.add_theme_color_override("font_color", c)

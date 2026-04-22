extends Control

const RADIAL_SCRIPT := preload("res://SimpleHUD/widgets/RadialStat.gd")
const STAT_ICON_PATHS := {
	&"health": "res://SimpleHUD/icons/health.png",
	&"energy": "res://SimpleHUD/icons/energy.png",
	&"hydration": "res://SimpleHUD/icons/hydration.png",
	&"mental": "res://SimpleHUD/icons/mental.png",
	&"body_temp": "res://SimpleHUD/icons/bodytemp.png",
	&"stamina": "res://SimpleHUD/icons/stamina.png",
	&"fatigue": "res://SimpleHUD/icons/fatigue.png",
}

var stat_id: StringName
var title: String = ""

var _label: Label
var _radial: Control
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
		var r: Control = RADIAL_SCRIPT.new() as Control
		r.custom_minimum_size = Vector2(52, 52)
		r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var icon_path: String = str(STAT_ICON_PATHS.get(stat_id, ""))
		if icon_path != "":
			var tex: Texture2D = load(icon_path)
			if tex != null && r.has_method("set_icon"):
				r.call("set_icon", tex)
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

	if use_radial && _radial:
		if _radial.has_method("set_ratio"):
			_radial.call("set_ratio", percent / 100.0)
	elif _label:
		_label.text = "%s %d" % [title, int(round(percent))]
	_apply_text_color(percent)

func _apply_text_color(percent: float) -> void:
	var c := Color.WHITE
	if _cfg != null && _cfg.has_method("get_stat_text_color"):
		c = _cfg.call("get_stat_text_color", percent)
	if _label:
		_label.add_theme_color_override("font_color", c)

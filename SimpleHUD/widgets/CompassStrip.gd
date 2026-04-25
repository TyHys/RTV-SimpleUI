extends Control

var _cfg: RefCounted = null
var _bearing_deg: float = 0.0

const _MAJOR_FONT_SIZE := 20
const _MINOR_FONT_SCALE := 0.4
const _PIXELS_PER_DEGREE := 3.0
const _STRIP_HEIGHT := 44.0
const _STRIP_WIDTH := 520.0
const _EDGE_PADDING := 10.0
## Skip redraw until bearing moves by at least this many degrees (reduces queue_redraw + full canvas redraw cost).
const _BEARING_DEADZONE_DEG := 0.35

var _DIR_NAME: PackedStringArray = PackedStringArray(["N", "NE", "E", "SE", "S", "SW", "W", "NW"])
var _DIR_DEG: PackedFloat32Array = PackedFloat32Array([
	0.0,
	45.0,
	90.0,
	135.0,
	180.0,
	225.0,
	270.0,
	315.0,
])
var _DIR_MAJOR: Array[bool] = [true, false, true, false, true, false, true, false]

var _font: Font = null
## Half of measured text width per cardinal (used to center labels); rebuilt in setup().
var _half_text_w: Array[float] = []


func setup(cfg: RefCounted) -> void:
	_cfg = cfg
	_ensure_font()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(_STRIP_WIDTH, _STRIP_HEIGHT)
	_rebuild_label_half_widths()


func _ensure_font() -> void:
	if _font != null:
		return
	_font = ThemeDB.fallback_font
	if _font == null:
		var th: Theme = ThemeDB.get_default_theme()
		if th != null:
			_font = th.get_font(&"font", &"Label")
	if _font == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Segoe UI", "Arial", "Noto Sans", "sans-serif"])
		_font = sf


func _rebuild_label_half_widths() -> void:
	_half_text_w.clear()
	_ensure_font()
	if _font == null:
		return
	var major_fs: int = _MAJOR_FONT_SIZE
	var minor_fs: int = maxi(6, int(round(float(_MAJOR_FONT_SIZE) * _MINOR_FONT_SCALE)))
	for i in range(8):
		var fs: int = major_fs if _DIR_MAJOR[i] else minor_fs
		var nm: String = String(_DIR_NAME[i])
		var tw: float = _font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
		_half_text_w.append(tw * 0.5)


func set_bearing_degrees(deg: float) -> void:
	var wrapped: float = wrapf(deg, 0.0, 360.0)
	var diff: float = wrapped - _bearing_deg
	if diff > 180.0:
		diff -= 360.0
	elif diff < -180.0:
		diff += 360.0
	if absf(diff) < _BEARING_DEADZONE_DEG:
		return
	_bearing_deg = wrapped
	queue_redraw()


func _shortest_delta_deg(bearing: float, world_deg: float) -> float:
	return rad_to_deg(angle_difference(deg_to_rad(bearing), deg_to_rad(world_deg)))


func _draw() -> void:
	if _cfg == null || !bool(_cfg.compass_enabled):
		return
	if _half_text_w.size() != 8:
		_rebuild_label_half_widths()
	if _font == null || _half_text_w.size() != 8:
		return

	var c: Color = _cfg.get_compass_color()
	var w: float = size.x
	var h: float = size.y
	var cx: float = w * 0.5
	var cy: float = h * 0.5

	var dim: Color = Color(c.r, c.g, c.b, c.a * 0.35)
	draw_line(Vector2(0.0, cy), Vector2(w, cy), dim, 1.5)
	draw_line(Vector2(cx, cy - 10.0), Vector2(cx, cy + 10.0), c, 2.0)

	var major_fs: int = _MAJOR_FONT_SIZE
	var minor_fs: int = maxi(6, int(round(float(_MAJOR_FONT_SIZE) * _MINOR_FONT_SCALE)))
	var margin: float = 60.0
	var tick_dim: Color = Color(c.r, c.g, c.b, c.a * 0.8)

	for i in range(8):
		var world_deg: float = float(_DIR_DEG[i])
		var delta: float = _shortest_delta_deg(_bearing_deg, world_deg)
		var x: float = cx + delta * _PIXELS_PER_DEGREE
		if x < -margin || x > w + margin:
			continue
		var is_major: bool = _DIR_MAJOR[i]
		var fs: int = major_fs if is_major else minor_fs
		var nm: String = String(_DIR_NAME[i])
		var hw: float = float(_half_text_w[i])
		var label_pos: Vector2 = Vector2(x - hw, cy - _EDGE_PADDING)
		draw_string(_font, label_pos, nm, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, c)
		var tick_h: float = 8.0 if is_major else 5.0
		draw_line(Vector2(x, cy + 2.0), Vector2(x, cy + 2.0 + tick_h), tick_dim, 1.0)

extends Control

var _cfg: RefCounted = null
var _bearing_deg: float = 0.0

const _MAJOR_FONT_SIZE := 20
const _MINOR_FONT_SCALE := 0.4
const _PIXELS_PER_DEGREE := 3.0
const _STRIP_HEIGHT := 44.0
const _STRIP_WIDTH := 520.0
const _EDGE_PADDING := 10.0

func setup(cfg: RefCounted) -> void:
	_cfg = cfg
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(_STRIP_WIDTH, _STRIP_HEIGHT)


func set_bearing_degrees(deg: float) -> void:
	_bearing_deg = wrapf(deg, 0.0, 360.0)
	queue_redraw()


func _draw() -> void:
	if _cfg == null || !bool(_cfg.compass_enabled):
		return

	var c: Color = _cfg.get_compass_color()
	var w: float = size.x
	var h: float = size.y
	var cx: float = w * 0.5
	var cy: float = h * 0.5

	# Baseline + center notch for modern "tape" readability.
	draw_line(Vector2(0.0, cy), Vector2(w, cy), Color(c.r, c.g, c.b, c.a * 0.35), 1.5)
	draw_line(Vector2(cx, cy - 10.0), Vector2(cx, cy + 10.0), c, 2.0)

	var dirs: Array = [
		{"name": "N", "deg": 0.0, "major": true},
		{"name": "NE", "deg": 45.0, "major": false},
		{"name": "E", "deg": 90.0, "major": true},
		{"name": "SE", "deg": 135.0, "major": false},
		{"name": "S", "deg": 180.0, "major": true},
		{"name": "SW", "deg": 225.0, "major": false},
		{"name": "W", "deg": 270.0, "major": true},
		{"name": "NW", "deg": 315.0, "major": false},
	]

	var major_fs: int = _MAJOR_FONT_SIZE
	var minor_fs: int = maxi(6, int(round(float(_MAJOR_FONT_SIZE) * _MINOR_FONT_SCALE)))
	var font: Font = ThemeDB.fallback_font
	var margin: float = 60.0

	for wrap in [-360.0, 0.0, 360.0]:
		var wrap_deg: float = float(wrap)
		for d in dirs:
			var abs_deg: float = float(d["deg"]) + wrap_deg
			var delta: float = abs_deg - _bearing_deg
			if delta < -180.0:
				delta += 360.0
			elif delta > 180.0:
				delta -= 360.0
			var x: float = cx + delta * _PIXELS_PER_DEGREE
			if x < -margin || x > w + margin:
				continue
			var text: String = String(d["name"])
			var is_major: bool = bool(d["major"])
			var fs: int = major_fs if is_major else minor_fs
			var text_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
			var label_pos: Vector2 = Vector2(x - text_w * 0.5, cy - _EDGE_PADDING)
			draw_string(font, label_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, c)
			var tick_h: float = 8.0 if is_major else 5.0
			draw_line(Vector2(x, cy + 2.0), Vector2(x, cy + 2.0 + tick_h), Color(c.r, c.g, c.b, c.a * 0.8), 1.0)

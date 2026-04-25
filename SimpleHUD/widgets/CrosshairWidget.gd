extends Control

var _cfg: RefCounted = null
var _bloom_radius_px: float = 0.0
var _bloom_has_received_value: bool = false

## Cached from cfg in `setup()` so `_draw` avoids repeated color/string work every frame.
var _draw_color: Color = Color.WHITE
var _draw_scale_mul: float = 1.0
var _draw_is_dot: bool = false
var _draw_bloom_enabled: bool = false

const _DEFAULT_SIZE := 96.0
const _BASE_LINE_LEN := 10.0
const _BASE_LINE_THICK := 2.0
const _BASE_GAP := 6.0
const _MAX_BLOOM_RADIUS := 56.0

func setup(cfg: RefCounted) -> void:
	_cfg = cfg
	_bloom_has_received_value = false
	_refresh_draw_cache()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(_DEFAULT_SIZE, _DEFAULT_SIZE)
	queue_redraw()


func _refresh_draw_cache() -> void:
	if _cfg == null:
		return
	_draw_color = _cfg.get_crosshair_color()
	_draw_scale_mul = clampf(float(_cfg.crosshair_scale_pct) / 100.0, 0.25, 4.0)
	_draw_is_dot = str(_cfg.crosshair_shape).to_lower() == "dot"
	_draw_bloom_enabled = bool(_cfg.crosshair_bloom_enabled)


func set_bloom_radius_px(v: float) -> void:
	var nv := clampf(v, 0.0, _MAX_BLOOM_RADIUS)
	if _bloom_has_received_value && is_equal_approx(nv, _bloom_radius_px):
		return
	_bloom_has_received_value = true
	_bloom_radius_px = nv
	queue_redraw()


func _draw() -> void:
	if _cfg == null || !bool(_cfg.crosshair_enabled):
		return

	var color: Color = _draw_color
	var scale_mul: float = _draw_scale_mul
	var center: Vector2 = size * 0.5

	if _draw_is_dot:
		var dot_r := maxf(1.5, 2.0 * scale_mul)
		draw_circle(center, dot_r, color)
		return

	var gap: float = _BASE_GAP * scale_mul
	if _draw_bloom_enabled:
		gap = _bloom_radius_px
	var line_len: float = _BASE_LINE_LEN * scale_mul
	var thick: float = maxf(1.0, _BASE_LINE_THICK * scale_mul)

	# Conventional transparent-core crosshair (+): four segments around an open center — one `draw_multiline` vs four `draw_line` calls.
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(8)
	pts[0] = Vector2(center.x - gap - line_len, center.y)
	pts[1] = Vector2(center.x - gap, center.y)
	pts[2] = Vector2(center.x + gap, center.y)
	pts[3] = Vector2(center.x + gap + line_len, center.y)
	pts[4] = Vector2(center.x, center.y - gap - line_len)
	pts[5] = Vector2(center.x, center.y - gap)
	pts[6] = Vector2(center.x, center.y + gap)
	pts[7] = Vector2(center.x, center.y + gap + line_len)
	draw_multiline(pts, color, thick, false)

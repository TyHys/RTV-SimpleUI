extends Control

var _cfg: RefCounted = null
var _bloom_radius_px: float = 0.0

const _DEFAULT_SIZE := 96.0
const _BASE_LINE_LEN := 10.0
const _BASE_LINE_THICK := 2.0
const _BASE_GAP := 6.0
const _MAX_BLOOM_RADIUS := 56.0

func setup(cfg: RefCounted) -> void:
	_cfg = cfg
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(_DEFAULT_SIZE, _DEFAULT_SIZE)


func set_bloom_radius_px(v: float) -> void:
	_bloom_radius_px = clampf(v, 0.0, _MAX_BLOOM_RADIUS)
	queue_redraw()


func _draw() -> void:
	if _cfg == null || !bool(_cfg.crosshair_enabled):
		return

	var color: Color = _cfg.get_crosshair_color()
	var scale_mul: float = clampf(float(_cfg.crosshair_scale_pct) / 100.0, 0.25, 4.0)
	var shape: String = str(_cfg.crosshair_shape).to_lower()
	var center: Vector2 = size * 0.5

	if shape == "dot":
		var dot_r := maxf(1.5, 2.0 * scale_mul)
		draw_circle(center, dot_r, color)
		return

	var gap: float = _BASE_GAP * scale_mul
	if bool(_cfg.crosshair_bloom_enabled):
		gap = _bloom_radius_px
	var line_len: float = _BASE_LINE_LEN * scale_mul
	var thick: float = maxf(1.0, _BASE_LINE_THICK * scale_mul)

	# Conventional transparent-core crosshair (+): four segments around an open center.
	draw_line(
		Vector2(center.x - gap - line_len, center.y),
		Vector2(center.x - gap, center.y),
		color,
		thick
	)
	draw_line(
		Vector2(center.x + gap, center.y),
		Vector2(center.x + gap + line_len, center.y),
		color,
		thick
	)
	draw_line(
		Vector2(center.x, center.y - gap - line_len),
		Vector2(center.x, center.y - gap),
		color,
		thick
	)
	draw_line(
		Vector2(center.x, center.y + gap),
		Vector2(center.x, center.y + gap + line_len),
		color,
		thick
	)

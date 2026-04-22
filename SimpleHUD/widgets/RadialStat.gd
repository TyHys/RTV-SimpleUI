extends Control

## Donut progress from 12 o'clock, clockwise. Ratio 0–1 maps to visible arc.

@export var ring_width: float = 5.0
@export var icon_size_px: float = 32.0

var _ratio: float = 1.0
var _icon: Texture2D
var _progress_color: Color = Color.WHITE

func set_ratio(r: float) -> void:
	_ratio = clampf(r, 0.0, 1.0)
	queue_redraw()

func set_icon(texture: Texture2D) -> void:
	_icon = texture
	queue_redraw()

func set_progress_color(color: Color) -> void:
	_progress_color = color
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var rad: float = minf(size.x, size.y) * 0.38
	var w: float = clampf(ring_width, 1.0, rad * 0.5)
	var start := -PI / 2.0
	var seg_end := start + _ratio * TAU
	const ARC_POINTS := 48

	# Dark circular backdrop for icon + donut ring.
	draw_circle(center, rad + (w * 0.95), Color8(0, 5, 15, 255))

	# Keep a full donut track visible at any value.
	draw_arc(center, rad, start, start + TAU, ARC_POINTS, Color(1.0, 1.0, 1.0, 0.24), w, true)
	if _ratio > 0.0:
		draw_arc(center, rad, start, seg_end, ARC_POINTS, _progress_color, w, true)

	if _icon != null:
		var icon_side: float = clampf(icon_size_px, 8.0, minf(size.x, size.y))
		var icon_rect := Rect2(
			center - Vector2.ONE * (icon_side * 0.5),
			Vector2.ONE * icon_side
		)
		draw_texture_rect(_icon, icon_rect, false)

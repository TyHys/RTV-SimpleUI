extends Control

## Donut progress from 12 o'clock, clockwise. Ratio 0–1 maps to visible arc.

@export var ring_width: float = 5.0

var _ratio: float = 1.0

func set_ratio(r: float) -> void:
	_ratio = clampf(r, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var rad: float = minf(size.x, size.y) * 0.45
	var w: float = clampf(ring_width, 1.0, rad * 0.5)
	var start := -PI / 2.0
	var seg_end := start + _ratio * TAU
	const ARC_POINTS := 48
	draw_arc(center, rad, start, start + TAU, ARC_POINTS, Color(0.15, 0.15, 0.15, 0.85), w, true)
	draw_arc(center, rad, start, seg_end, ARC_POINTS, Color(0.95, 0.95, 0.95, 1.0), w, true)

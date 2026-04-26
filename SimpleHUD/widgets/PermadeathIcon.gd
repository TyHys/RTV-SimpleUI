extends Control

## Use the game's Red skull — same asset vanilla HUD uses for the permadeath indicator.
const _ICON_PATH := "res://UI/Sprites/Icon_Skull_Red.png"
const _ICON_BASE_SIZE_PX := 100.0
const _MARGIN_PX := 8.0

var _texture_rect: TextureRect
var _cfg: RefCounted
var _last_placed_pos: Vector2 = Vector2(-9999.0, -9999.0)
var _last_placed_vp: Vector2 = Vector2.ZERO


func setup(cfg: RefCounted) -> void:
	_cfg = cfg
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 35
	## Zero anchors — parent HudOverlay is FULL_RECT and would override position otherwise.
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	if _texture_rect == null:
		_texture_rect = TextureRect.new()
		_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		## Prevent the TextureRect from expanding beyond the explicit size we set.
		_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_texture_rect.anchor_left = 0.0
		_texture_rect.anchor_top = 0.0
		_texture_rect.anchor_right = 0.0
		_texture_rect.anchor_bottom = 0.0
		var tex: Texture2D = load(_ICON_PATH) as Texture2D
		if tex != null:
			_texture_rect.texture = tex
		add_child(_texture_rect)
	_apply_size()
	_last_placed_pos = Vector2(-9999.0, -9999.0)
	_last_placed_vp = Vector2.ZERO


func _icon_size_px() -> float:
	if _cfg == null:
		return _ICON_BASE_SIZE_PX
	return _ICON_BASE_SIZE_PX * clampf(float(_cfg.permadeath_icon_scale_pct), 10.0, 400.0) / 100.0


func _apply_size() -> void:
	var s := _icon_size_px()
	var sz := Vector2(s, s)
	custom_minimum_size = sz
	size = sz
	if _texture_rect != null:
		_texture_rect.position = Vector2.ZERO
		_texture_rect.custom_minimum_size = sz
		_texture_rect.size = sz


func place(vp: Vector2) -> void:
	if _cfg == null:
		return
	var pos_key := _normalize_pos_key(str(_cfg.permadeath_icon_position))
	if pos_key == "always_hide":
		_last_placed_vp = Vector2.ZERO
		return
	var s := _icon_size_px()
	var half := s * 0.5
	var m := _MARGIN_PX
	## Each position defines a center point; subtract half to get top-left corner for `position`.
	var cx: float
	var cy: float
	match pos_key:
		"top_left":      cx = m + half;        cy = m + half
		"top_center":    cx = vp.x * 0.5;      cy = m + half
		"top_right":     cx = vp.x - m - half; cy = m + half
		"left_center":   cx = m + half;        cy = vp.y * 0.5
		"right_center":  cx = vp.x - m - half; cy = vp.y * 0.5
		"bottom_left":   cx = m + half;        cy = vp.y - m - half
		"bottom_center": cx = vp.x * 0.5;      cy = vp.y - m - half
		"bottom_right":  cx = vp.x - m - half; cy = vp.y - m - half
		_:
			return
	var new_pos := Vector2(cx - half, cy - half)
	if new_pos.is_equal_approx(_last_placed_pos) && vp.is_equal_approx(_last_placed_vp):
		return
	_last_placed_pos = new_pos
	_last_placed_vp = vp
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	position = new_pos
	_apply_size()


func tick(game_data: Resource) -> void:
	if _cfg == null || game_data == null || !is_instance_valid(game_data):
		if visible: visible = false
		return
	if _normalize_pos_key(str(_cfg.permadeath_icon_position)) == "always_hide":
		if visible: visible = false
		return
	var should_show: bool = bool(game_data.get("permadeath"))
	if visible != should_show:
		visible = should_show
	if should_show:
		var a := clampf(float(_cfg.permadeath_icon_alpha), 0.0, 1.0)
		if !is_equal_approx(modulate.a, a):
			modulate.a = a


static func _normalize_pos_key(s: String) -> String:
	var k := s.strip_edges().to_lower()
	return "always_hide" if (k == "always_hide" || k == "hidden" || k == "") else k

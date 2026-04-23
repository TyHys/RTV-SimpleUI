extends "res://SimpleHUD/SimpleHUDConfigCore.gd"

func _embedded_defaults_ini() -> String:
	return """[general]
enabled=true
min_stat_alpha_floor=0
numeric_only=false
[health]
visible_threshold=101.0
radial=true
[energy]
visible_threshold=79.0
radial=true
[hydration]
visible_threshold=79.0
radial=true
[mental]
visible_threshold=79.0
radial=true
[body_temp]
visible_threshold=79.0
radial=true
[stamina]
visible_threshold=79.0
radial=true
[fatigue]
visible_threshold=79.0
radial=true
[status_icons]
mode=\"inflicted_only\"
corner=\"bottom_right\"
spacing_px=2
icon_scale=0.12
icon_size_px=32
stack_direction=\"vertical_up\"
margin_right=5
margin_bottom=5
color_r=120
color_g=0
color_b=0
[fps_map]
alpha=0.5
scale=0.81
anchor=\"top_left\"
offset_x=4
offset_y=4
[vitals_layout]
margin_left=8
margin_bottom=5
strip_width_px=960
row_height_px=36
[stat_text_colors]
mode=\"white_only\"
high_start_pct=75
mid_pct=50
high_r=255
high_g=255
high_b=255
mid_r=255
mid_g=255
mid_b=255
low_r=255
low_g=255
low_b=255"""

func apply_defaults() -> void:
	super.apply_defaults()
	stat_text_color_mode = "white_only"
	stat_text_mid_r = 255
	stat_text_mid_g = 255
	stat_text_mid_b = 255
	stat_text_low_r = 255
	stat_text_low_g = 255
	stat_text_low_b = 255

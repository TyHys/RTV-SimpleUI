extends "res://SimpleHUD/SimpleHUDConfigCore.gd"

func _embedded_defaults_ini() -> String:
	return """[general]
enabled=true
min_stat_alpha_floor=0
numeric_only=false
stamina_fatigue_near_zero_cutoff=1.0
vitals_transparency_mode=\"static\"
vitals_static_opacity=0.45
[health]
visible_threshold=101.0
radial=true
[energy]
visible_threshold=101.0
radial=true
[hydration]
visible_threshold=101.0
radial=true
[mental]
visible_threshold=101.0
radial=true
[body_temp]
visible_threshold=101.0
radial=true
[stamina]
visible_threshold=101.0
radial=true
[fatigue]
visible_threshold=101.0
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
color_r=150
color_g=0
color_b=0
inactive_r=255
inactive_g=255
inactive_b=255
inactive_alpha=0.25
fill_empty_space=true
[misc]
compass_enabled=true
compass_anchor=\"top\"
compass_color_r=220
compass_color_g=220
compass_color_b=220
compass_color_a=0.95
crosshair_enabled=true
crosshair_color_r=220
crosshair_color_g=220
crosshair_color_b=220
crosshair_color_a=0.95
crosshair_shape=\"crosshair\"
crosshair_scale_pct=100
crosshair_bloom_enabled=true
crosshair_hide_during_aiming=true
crosshair_hide_while_stowed=true
fps_hide_label_prefix=true
map_label_mode=\"region_only\"
[fps_map]
alpha=0.5
scale=0.81
anchor=\"top_left\"
offset_x=4
offset_y=4
[vitals_layout]
margin_left=8
margin_right=8
margin_top=8
margin_bottom=5
spacing_px=12
strip_width_px=960
row_height_px=36
fill_empty_space=false
strip_alignment=\"center\"
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

	# Values not fully represented in INI parsing are set here.
	vitals_strip_alignment = "center"
	status_auto_hide_when_none = true
	status_anchor = "right"
	status_strip_alignment = "center"
	status_stack_direction = "vertical_up"
	status_padding_px = 5.0
	status_scale_pct = 100.0

	for sid in STAT_IDS:
		vitals_anchor[sid] = "left"
		vitals_padding_px[sid] = 5.0
		vitals_scale_pct[sid] = 95.0
		vitals_spacing_px[sid] = 12.0
		visible_threshold[sid] = 101.0
		radial[sid] = true
		stat_gradient_overrides[sid] = {"mode": "white_only"}

extends RefCounted

## Shared SimpleHUD preferences UI: vitals + status tray (same as legacy inventory Tools tab).

const CFG := preload("res://SimpleHUD/Config.gd")
const UserPreferencesScript := preload("res://SimpleHUD/UserPreferences.gd")
const SimpleHUDPresetsReg := preload("res://SimpleHUD/PresetsRegistry.gd")

var _menu_root: Control
var _panel_root: Control

var _auto_hide_cb: CheckBox
var _ailments_fill_empty_cb: CheckBox
var _anchor_option: OptionButton
var _status_strip_align_opt: OptionButton
var _padding_spin: SpinBox
var _status_spacing_spin: SpinBox
var _scale_spin: SpinBox
var _inactive_alpha_spin: SpinBox
var _r_spin: SpinBox
var _g_spin: SpinBox
var _b_spin: SpinBox
var _ir_spin: SpinBox
var _ig_spin: SpinBox
var _ib_spin: SpinBox
var _compass_enable_cb: CheckBox
var _compass_anchor_opt: OptionButton
var _compass_anchor_row: Control
var _compass_alpha_spin: SpinBox
var _compass_alpha_row: Control
var _compass_r_spin: SpinBox
var _compass_g_spin: SpinBox
var _compass_b_spin: SpinBox
var _compass_rgb_title: Label
var _compass_rgb_row: Control
var _crosshair_enable_cb: CheckBox
var _crosshair_shape_opt: OptionButton
var _crosshair_shape_row: Control
var _crosshair_alpha_spin: SpinBox
var _crosshair_alpha_row: Control
var _crosshair_scale_spin: SpinBox
var _crosshair_scale_row: Control
var _crosshair_bloom_cb: CheckBox
var _crosshair_bloom_row: Control
var _crosshair_hide_ads_cb: CheckBox
var _crosshair_hide_ads_row: Control
var _crosshair_hide_stowed_cb: CheckBox
var _crosshair_hide_stowed_row: Control
var _crosshair_group_end_sep: Control
var _fps_hide_label_cb: CheckBox
var _fps_hide_label_row: Control
var _map_label_mode_opt: OptionButton
var _map_label_mode_row: Control
var _crosshair_rgb_title: Label
var _crosshair_rgb_row: Control
var _crosshair_r_spin: SpinBox
var _crosshair_g_spin: SpinBox
var _crosshair_b_spin: SpinBox

var _spacing_spin: SpinBox
var _vitals_strip_align_opt: OptionButton
var _vitals_fill_empty_cb: CheckBox
var _vitals_transparency_opt: OptionButton
var _vitals_static_opacity_spin: SpinBox
var _vitals_static_opacity_row: Control

var _stat_mode: OptionButton
var _stat_anchor: OptionButton
var _stat_padding: SpinBox
var _stat_scale: SpinBox
var _stat_threshold: SpinBox
var _grad_mode: OptionButton
var _grad_custom: VBoxContainer

var _g_hi_pct: SpinBox
var _g_mid_pct: SpinBox
var _g_lo_pct: SpinBox
var _gh_r: SpinBox
var _gh_g: SpinBox
var _gh_b: SpinBox
var _gm_r: SpinBox
var _gm_g: SpinBox
var _gm_b: SpinBox
var _gl_r: SpinBox
var _gl_g: SpinBox
var _gl_b: SpinBox

var _ui_sync: bool = false

var _preset_option: OptionButton
var _current_preset_value: Label

var _customize_toggle_btn: Button
var _vitals_toggle_btn: Button
var _ailments_toggle_btn: Button
var _misc_toggle_btn: Button
var _customize_open: bool = false
var _vitals_open: bool = false
var _ailments_open: bool = false
var _misc_open: bool = false
var _vitals_start_idx: int = -1
var _vitals_end_idx: int = -1
var _ailments_start_idx: int = -1
var _ailments_end_idx: int = -1
var _misc_start_idx: int = -1
var _misc_end_idx: int = -1


func _init(menu_root: Control, panel_root: Control) -> void:
	_menu_root = menu_root
	_panel_root = panel_root


func build(vbox: VBoxContainer) -> void:
	_panel_menu_log("SettingsPanel.build() start")
	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 8)
	var preset_lbl := Label.new()
	preset_lbl.text = "Presets"
	preset_lbl.custom_minimum_size.x = 120
	preset_row.add_child(preset_lbl)
	_preset_option = OptionButton.new()
	_preset_option.focus_mode = Control.FOCUS_ALL
	_preset_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset_option.add_item("— Select preset —")
	for d in SimpleHUDPresetsReg.PRESETS:
		_preset_option.add_item(str(d["label"]))
	_preset_option.item_selected.connect(_on_preset_selected)
	preset_row.add_child(_preset_option)
	vbox.add_child(preset_row)

	var back := Button.new()
	back.text = "Return"
	back.focus_mode = Control.FOCUS_ALL
	back.pressed.connect(_on_back_pressed)
	vbox.add_child(back)

	var cur_row := HBoxContainer.new()
	cur_row.add_theme_constant_override("separation", 8)
	var cur_lbl := Label.new()
	cur_lbl.text = "Current Preset"
	cur_lbl.custom_minimum_size.x = 120
	cur_row.add_child(cur_lbl)
	_current_preset_value = Label.new()
	_current_preset_value.text = "User Customized"
	_current_preset_value.add_theme_color_override("font_color", Color8(10, 80, 0, 255))
	_current_preset_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cur_row.add_child(_current_preset_value)
	vbox.add_child(cur_row)

	_customize_toggle_btn = Button.new()
	_customize_toggle_btn.toggle_mode = true
	_customize_toggle_btn.button_pressed = _customize_open
	_customize_toggle_btn.focus_mode = Control.FOCUS_ALL
	_customize_toggle_btn.pressed.connect(_on_customize_toggled)
	vbox.add_child(_customize_toggle_btn)

	_vitals_toggle_btn = Button.new()
	_vitals_toggle_btn.toggle_mode = true
	_vitals_toggle_btn.button_pressed = _vitals_open
	_vitals_toggle_btn.focus_mode = Control.FOCUS_ALL
	_vitals_toggle_btn.pressed.connect(_on_vitals_section_toggled)
	vbox.add_child(_vitals_toggle_btn)

	_vitals_start_idx = vbox.get_child_count()

	var vt := Label.new()
	vt.text = "Vitals"
	vt.add_theme_font_size_override("font_size", 18)
	vbox.add_child(vt)

	_stat_threshold = _add_labeled_spin(vbox, "Minimum display threshold", 0, 101, 1, 0)
	_stat_threshold.value_changed.connect(_on_stat_field_changed_val)

	_vitals_strip_align_opt = _add_labeled_option(
		vbox,
		"Order on edge",
		[
			"Left to right",
			"Centered on the edge",
			"Right to left",
		],
	)
	_vitals_strip_align_opt.item_selected.connect(_on_vitals_strip_align_changed)

	_vitals_fill_empty_cb = CheckBox.new()
	_vitals_fill_empty_cb.text = "Fill empty space"
	_vitals_fill_empty_cb.focus_mode = Control.FOCUS_NONE
	_vitals_fill_empty_cb.toggled.connect(_on_vitals_fill_empty_toggled)
	vbox.add_child(_vitals_fill_empty_cb)

	_stat_mode = _add_labeled_option(vbox, "Display", ["Numeric", "Radial"])
	_stat_mode.item_selected.connect(_on_stat_field_changed)

	_stat_anchor = _add_labeled_option(
		vbox,
		"Edge",
		["Top", "Bottom", "Left", "Right"],
	)
	_stat_anchor.item_selected.connect(_on_vitals_anchor_changed)
	_refresh_vitals_order_option_items("leading")

	_stat_padding = _add_labeled_spin(vbox, "Edge Padding (px)", 0, 512, 1, 0)
	_stat_padding.value_changed.connect(_on_stat_field_changed_val)
	_spacing_spin = _add_labeled_spin(vbox, "Spacing between vitals", 0, 256, 1, 0)
	_spacing_spin.value_changed.connect(_on_spacing_strip_changed)
	_stat_scale = _add_labeled_spin(vbox, "Scale (%)", 25, 400, 5, 0)
	_stat_scale.value_changed.connect(_on_stat_field_changed_val)

	_vitals_transparency_opt = _add_labeled_option(
		vbox,
		"Transparency",
		["Dynamic", "Static"],
	)
	_vitals_transparency_opt.item_selected.connect(_on_vitals_transparency_changed)

	var static_row := HBoxContainer.new()
	static_row.add_theme_constant_override("separation", 8)
	var sol := Label.new()
	sol.text = "Opacity (%)"
	sol.custom_minimum_size.x = 160
	static_row.add_child(sol)
	_vitals_static_opacity_spin = SpinBox.new()
	_vitals_static_opacity_spin.min_value = 1
	_vitals_static_opacity_spin.max_value = 100
	_vitals_static_opacity_spin.step = 1
	_vitals_static_opacity_spin.rounded = true
	_vitals_static_opacity_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vitals_static_opacity_spin.focus_mode = Control.FOCUS_ALL
	_vitals_static_opacity_spin.value_changed.connect(_on_vitals_static_opacity_changed)
	static_row.add_child(_vitals_static_opacity_spin)
	vbox.add_child(static_row)
	_vitals_static_opacity_row = static_row

	_grad_mode = _add_labeled_option(
		vbox,
		"Vital colors",
		["Preset default", "White only", "Custom gradient"],
	)
	_grad_mode.item_selected.connect(_on_grad_mode_changed)

	_grad_custom = VBoxContainer.new()
	_grad_custom.add_theme_constant_override("separation", 6)
	vbox.add_child(_grad_custom)

	var hi_rgb := Label.new()
	hi_rgb.text = "High RGB"
	hi_rgb.add_theme_font_size_override("font_size", 12)
	_grad_custom.add_child(hi_rgb)
	var row_hi := HBoxContainer.new()
	row_hi.add_theme_constant_override("separation", 8)
	_gh_r = _mini_spin(row_hi, "R", 0, 255)
	_gh_g = _mini_spin(row_hi, "G", 0, 255)
	_gh_b = _mini_spin(row_hi, "B", 0, 255)
	_gh_r.value_changed.connect(_on_stat_field_changed_val)
	_gh_g.value_changed.connect(_on_stat_field_changed_val)
	_gh_b.value_changed.connect(_on_stat_field_changed_val)
	var hi_th_lbl := Label.new()
	hi_th_lbl.text = "Threshold"
	hi_th_lbl.custom_minimum_size.x = 70
	row_hi.add_child(hi_th_lbl)
	_g_hi_pct = SpinBox.new()
	_g_hi_pct.min_value = 0
	_g_hi_pct.max_value = 100
	_g_hi_pct.step = 1
	_g_hi_pct.rounded = true
	_g_hi_pct.custom_minimum_size.x = 72
	_g_hi_pct.focus_mode = Control.FOCUS_ALL
	_g_hi_pct.value_changed.connect(_on_stat_field_changed_val)
	row_hi.add_child(_g_hi_pct)
	_grad_custom.add_child(row_hi)

	var mid_rgb := Label.new()
	mid_rgb.text = "Mid RGB"
	mid_rgb.add_theme_font_size_override("font_size", 12)
	_grad_custom.add_child(mid_rgb)
	var row_mid := HBoxContainer.new()
	row_mid.add_theme_constant_override("separation", 8)
	_gm_r = _mini_spin(row_mid, "R", 0, 255)
	_gm_g = _mini_spin(row_mid, "G", 0, 255)
	_gm_b = _mini_spin(row_mid, "B", 0, 255)
	_gm_r.value_changed.connect(_on_stat_field_changed_val)
	_gm_g.value_changed.connect(_on_stat_field_changed_val)
	_gm_b.value_changed.connect(_on_stat_field_changed_val)
	var mid_th_lbl := Label.new()
	mid_th_lbl.text = "Threshold"
	mid_th_lbl.custom_minimum_size.x = 70
	row_mid.add_child(mid_th_lbl)
	_g_mid_pct = SpinBox.new()
	_g_mid_pct.min_value = 0
	_g_mid_pct.max_value = 100
	_g_mid_pct.step = 1
	_g_mid_pct.rounded = true
	_g_mid_pct.custom_minimum_size.x = 72
	_g_mid_pct.focus_mode = Control.FOCUS_ALL
	_g_mid_pct.value_changed.connect(_on_stat_field_changed_val)
	row_mid.add_child(_g_mid_pct)
	_grad_custom.add_child(row_mid)

	var low_rgb := Label.new()
	low_rgb.text = "Low RGB"
	low_rgb.add_theme_font_size_override("font_size", 12)
	_grad_custom.add_child(low_rgb)
	var row_lo := HBoxContainer.new()
	row_lo.add_theme_constant_override("separation", 8)
	_gl_r = _mini_spin(row_lo, "R", 0, 255)
	_gl_g = _mini_spin(row_lo, "G", 0, 255)
	_gl_b = _mini_spin(row_lo, "B", 0, 255)
	_gl_r.value_changed.connect(_on_stat_field_changed_val)
	_gl_g.value_changed.connect(_on_stat_field_changed_val)
	_gl_b.value_changed.connect(_on_stat_field_changed_val)
	var low_th_lbl := Label.new()
	low_th_lbl.text = "Threshold"
	low_th_lbl.custom_minimum_size.x = 70
	row_lo.add_child(low_th_lbl)
	_g_lo_pct = SpinBox.new()
	_g_lo_pct.min_value = 0
	_g_lo_pct.max_value = 100
	_g_lo_pct.step = 1
	_g_lo_pct.rounded = true
	_g_lo_pct.custom_minimum_size.x = 72
	_g_lo_pct.focus_mode = Control.FOCUS_ALL
	_g_lo_pct.value_changed.connect(_on_stat_field_changed_val)
	row_lo.add_child(_g_lo_pct)
	_grad_custom.add_child(row_lo)
	vbox.add_child(HSeparator.new())
	_vitals_end_idx = vbox.get_child_count() - 1

	_ailments_toggle_btn = Button.new()
	_ailments_toggle_btn.toggle_mode = true
	_ailments_toggle_btn.button_pressed = _ailments_open
	_ailments_toggle_btn.focus_mode = Control.FOCUS_ALL
	_ailments_toggle_btn.pressed.connect(_on_ailments_section_toggled)
	vbox.add_child(_ailments_toggle_btn)
	_ailments_start_idx = vbox.get_child_count()

	var title := Label.new()
	title.text = "Ailment icons"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	_auto_hide_cb = CheckBox.new()
	_auto_hide_cb.text = "Hide tray when no active ailments"
	_auto_hide_cb.focus_mode = Control.FOCUS_NONE
	_auto_hide_cb.toggled.connect(_on_auto_hide_toggled)
	vbox.add_child(_auto_hide_cb)

	_ailments_fill_empty_cb = CheckBox.new()
	_ailments_fill_empty_cb.text = "Fill empty space"
	_ailments_fill_empty_cb.focus_mode = Control.FOCUS_NONE
	_ailments_fill_empty_cb.toggled.connect(_on_ailments_fill_empty_toggled)
	vbox.add_child(_ailments_fill_empty_cb)

	var anchor_row := HBoxContainer.new()
	anchor_row.add_theme_constant_override("separation", 8)
	var anchor_lbl := Label.new()
	anchor_lbl.text = "Edge"
	anchor_lbl.custom_minimum_size.x = 120
	anchor_row.add_child(anchor_lbl)
	_anchor_option = OptionButton.new()
	_anchor_option.focus_mode = Control.FOCUS_ALL
	_anchor_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_anchor_option.add_item("Top", 0)
	_anchor_option.add_item("Bottom", 1)
	_anchor_option.add_item("Left", 2)
	_anchor_option.add_item("Right", 3)
	_anchor_option.item_selected.connect(_on_anchor_selected)
	anchor_row.add_child(_anchor_option)
	vbox.add_child(anchor_row)

	var spread_row := HBoxContainer.new()
	spread_row.add_theme_constant_override("separation", 8)
	var spread_lbl := Label.new()
	spread_lbl.text = "Icon order on edge"
	spread_lbl.custom_minimum_size.x = 160
	spread_row.add_child(spread_lbl)
	_status_strip_align_opt = OptionButton.new()
	_status_strip_align_opt.focus_mode = Control.FOCUS_ALL
	_status_strip_align_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spread_row.add_child(_status_strip_align_opt)
	vbox.add_child(spread_row)
	_status_strip_align_opt.item_selected.connect(_on_status_field_changed)

	_padding_spin = _add_labeled_spin(vbox, "Edge padding (px)", 0, 512, 1, 0)
	_padding_spin.value_changed.connect(_on_padding_changed)

	_status_spacing_spin = _add_labeled_spin(vbox, "Spacing between (px)", 0, 64, 1, 0)
	_status_spacing_spin.value_changed.connect(_on_status_spacing_changed)

	_scale_spin = _add_labeled_spin(vbox, "Scale (%)", 25, 400, 5, 0)
	_scale_spin.value_changed.connect(_on_scale_changed)

	var rgb_title := Label.new()
	rgb_title.text = "Active ailment tint (RGB)"
	rgb_title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(rgb_title)

	var rgb_row := HBoxContainer.new()
	rgb_row.add_theme_constant_override("separation", 8)
	_r_spin = _mini_spin(rgb_row, "R", 0, 255)
	_g_spin = _mini_spin(rgb_row, "G", 0, 255)
	_b_spin = _mini_spin(rgb_row, "B", 0, 255)
	_r_spin.value_changed.connect(_on_rgb_changed)
	_g_spin.value_changed.connect(_on_rgb_changed)
	_b_spin.value_changed.connect(_on_rgb_changed)
	vbox.add_child(rgb_row)

	var in_rgb_title := Label.new()
	in_rgb_title.text = "Inactive ailment tint (RGB)"
	in_rgb_title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(in_rgb_title)

	var in_rgb_row := HBoxContainer.new()
	in_rgb_row.add_theme_constant_override("separation", 8)
	_ir_spin = _mini_spin(in_rgb_row, "R", 0, 255)
	_ig_spin = _mini_spin(in_rgb_row, "G", 0, 255)
	_ib_spin = _mini_spin(in_rgb_row, "B", 0, 255)
	_ir_spin.value_changed.connect(_on_inactive_rgb_changed)
	_ig_spin.value_changed.connect(_on_inactive_rgb_changed)
	_ib_spin.value_changed.connect(_on_inactive_rgb_changed)
	vbox.add_child(in_rgb_row)

	_inactive_alpha_spin = _add_labeled_spin(vbox, "Inactive ailment opacity (%)", 0, 100, 1, 0)
	_inactive_alpha_spin.value_changed.connect(_on_status_numeric_field_changed)
	vbox.add_child(HSeparator.new())
	_ailments_end_idx = vbox.get_child_count() - 1

	_misc_toggle_btn = Button.new()
	_misc_toggle_btn.toggle_mode = true
	_misc_toggle_btn.button_pressed = _misc_open
	_misc_toggle_btn.focus_mode = Control.FOCUS_ALL
	_misc_toggle_btn.pressed.connect(_on_misc_section_toggled)
	vbox.add_child(_misc_toggle_btn)
	_misc_start_idx = vbox.get_child_count()

	var misc_title := Label.new()
	misc_title.text = "Misc"
	misc_title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(misc_title)

	var compass_enable_row := HBoxContainer.new()
	compass_enable_row.add_theme_constant_override("separation", 8)
	_compass_enable_cb = CheckBox.new()
	_compass_enable_cb.text = "Enable Compass"
	_compass_enable_cb.focus_mode = Control.FOCUS_NONE
	_compass_enable_cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compass_enable_cb.toggled.connect(_on_misc_field_toggled)
	compass_enable_row.add_child(_compass_enable_cb)
	var compass_beta := RichTextLabel.new()
	compass_beta.bbcode_enabled = true
	compass_beta.scroll_active = false
	compass_beta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass_beta.autowrap_mode = TextServer.AUTOWRAP_OFF
	compass_beta.fit_content = true
	compass_beta.text = "[i][color=#e6d040]*Beta[/color][/i]"
	compass_beta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	compass_enable_row.add_child(compass_beta)
	vbox.add_child(compass_enable_row)

	var misc_anchor_row := HBoxContainer.new()
	misc_anchor_row.add_theme_constant_override("separation", 8)
	var misc_anchor_lbl := Label.new()
	misc_anchor_lbl.text = "Edge"
	misc_anchor_lbl.custom_minimum_size.x = 160
	misc_anchor_row.add_child(misc_anchor_lbl)
	_compass_anchor_opt = OptionButton.new()
	_compass_anchor_opt.focus_mode = Control.FOCUS_ALL
	_compass_anchor_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compass_anchor_opt.add_item("Top")
	_compass_anchor_opt.add_item("Bottom")
	_compass_anchor_opt.item_selected.connect(_on_misc_field_changed_idx)
	misc_anchor_row.add_child(_compass_anchor_opt)
	vbox.add_child(misc_anchor_row)
	_compass_anchor_row = misc_anchor_row

	_compass_alpha_spin = _add_labeled_spin(vbox, "Transparency (%)", 0, 100, 1, 0)
	_compass_alpha_spin.value_changed.connect(_on_misc_field_changed)
	_compass_alpha_row = _compass_alpha_spin.get_parent()

	_compass_rgb_title = Label.new()
	_compass_rgb_title.text = "Compass color (RGB)"
	_compass_rgb_title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_compass_rgb_title)

	var comp_rgb_row := HBoxContainer.new()
	comp_rgb_row.add_theme_constant_override("separation", 8)
	_compass_r_spin = _mini_spin(comp_rgb_row, "R", 0, 255)
	_compass_g_spin = _mini_spin(comp_rgb_row, "G", 0, 255)
	_compass_b_spin = _mini_spin(comp_rgb_row, "B", 0, 255)
	_compass_r_spin.value_changed.connect(_on_misc_field_changed)
	_compass_g_spin.value_changed.connect(_on_misc_field_changed)
	_compass_b_spin.value_changed.connect(_on_misc_field_changed)
	vbox.add_child(comp_rgb_row)
	_compass_rgb_row = comp_rgb_row

	vbox.add_child(HSeparator.new())

	var crosshair_enable_row := HBoxContainer.new()
	crosshair_enable_row.add_theme_constant_override("separation", 8)
	_crosshair_enable_cb = CheckBox.new()
	_crosshair_enable_cb.text = "Enable Dynamic Crosshair"
	_crosshair_enable_cb.focus_mode = Control.FOCUS_NONE
	_crosshair_enable_cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crosshair_enable_cb.toggled.connect(_on_misc_field_toggled)
	crosshair_enable_row.add_child(_crosshair_enable_cb)
	var crosshair_beta := RichTextLabel.new()
	crosshair_beta.bbcode_enabled = true
	crosshair_beta.scroll_active = false
	crosshair_beta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_beta.autowrap_mode = TextServer.AUTOWRAP_OFF
	crosshair_beta.fit_content = true
	crosshair_beta.text = "[i][color=#e6d040]*Beta[/color][/i]"
	crosshair_beta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	crosshair_enable_row.add_child(crosshair_beta)
	vbox.add_child(crosshair_enable_row)

	var xr_shape_row := HBoxContainer.new()
	xr_shape_row.add_theme_constant_override("separation", 8)
	var xr_shape_lbl := Label.new()
	xr_shape_lbl.text = "Shape"
	xr_shape_lbl.custom_minimum_size.x = 160
	xr_shape_row.add_child(xr_shape_lbl)
	_crosshair_shape_opt = OptionButton.new()
	_crosshair_shape_opt.focus_mode = Control.FOCUS_ALL
	_crosshair_shape_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crosshair_shape_opt.add_item("Crosshair")
	_crosshair_shape_opt.add_item("Dot")
	_crosshair_shape_opt.item_selected.connect(_on_misc_field_changed_idx)
	xr_shape_row.add_child(_crosshair_shape_opt)
	vbox.add_child(xr_shape_row)
	_crosshair_shape_row = xr_shape_row

	_crosshair_alpha_spin = _add_labeled_spin(vbox, "Transparency (%)", 0, 100, 1, 0)
	_crosshair_alpha_spin.value_changed.connect(_on_misc_field_changed)
	_crosshair_alpha_row = _crosshair_alpha_spin.get_parent()

	_crosshair_scale_spin = _add_labeled_spin(vbox, "Scale (%)", 25, 300, 5, 0)
	_crosshair_scale_spin.value_changed.connect(_on_misc_field_changed)
	_crosshair_scale_row = _crosshair_scale_spin.get_parent()

	_crosshair_bloom_cb = CheckBox.new()
	_crosshair_bloom_cb.text = "Bloom (dynamic spread expansion)"
	_crosshair_bloom_cb.focus_mode = Control.FOCUS_NONE
	_crosshair_bloom_cb.toggled.connect(_on_misc_field_toggled)
	vbox.add_child(_crosshair_bloom_cb)
	_crosshair_bloom_row = _crosshair_bloom_cb

	_crosshair_hide_ads_cb = CheckBox.new()
	_crosshair_hide_ads_cb.text = "Hide during aiming"
	_crosshair_hide_ads_cb.focus_mode = Control.FOCUS_NONE
	_crosshair_hide_ads_cb.toggled.connect(_on_misc_field_toggled)
	vbox.add_child(_crosshair_hide_ads_cb)
	_crosshair_hide_ads_row = _crosshair_hide_ads_cb

	_crosshair_hide_stowed_cb = CheckBox.new()
	_crosshair_hide_stowed_cb.text = "Hide while stowed"
	_crosshair_hide_stowed_cb.focus_mode = Control.FOCUS_NONE
	_crosshair_hide_stowed_cb.toggled.connect(_on_misc_field_toggled)
	vbox.add_child(_crosshair_hide_stowed_cb)
	_crosshair_hide_stowed_row = _crosshair_hide_stowed_cb

	var crosshair_end_sep := HSeparator.new()
	vbox.add_child(crosshair_end_sep)
	_crosshair_group_end_sep = crosshair_end_sep

	_fps_hide_label_cb = CheckBox.new()
	_fps_hide_label_cb.text = "Hide \"FPS:\" label prefix"
	_fps_hide_label_cb.focus_mode = Control.FOCUS_NONE
	_fps_hide_label_cb.toggled.connect(_on_misc_field_toggled)
	vbox.add_child(_fps_hide_label_cb)
	_fps_hide_label_row = _fps_hide_label_cb

	var map_mode_row := HBoxContainer.new()
	map_mode_row.add_theme_constant_override("separation", 8)
	var map_mode_lbl := Label.new()
	map_mode_lbl.text = "Map label format"
	map_mode_lbl.custom_minimum_size.x = 160
	map_mode_row.add_child(map_mode_lbl)
	_map_label_mode_opt = OptionButton.new()
	_map_label_mode_opt.focus_mode = Control.FOCUS_ALL
	_map_label_mode_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_label_mode_opt.add_item("Default (Village (Area 05))")
	_map_label_mode_opt.add_item("Map Only (Village)")
	_map_label_mode_opt.add_item("Region Only (Area 05)")
	_map_label_mode_opt.item_selected.connect(_on_misc_field_changed_idx)
	map_mode_row.add_child(_map_label_mode_opt)
	vbox.add_child(map_mode_row)
	_map_label_mode_row = map_mode_row

	_crosshair_rgb_title = Label.new()
	_crosshair_rgb_title.text = "Crosshair color (RGB)"
	_crosshair_rgb_title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_crosshair_rgb_title)

	var xr_rgb_row := HBoxContainer.new()
	xr_rgb_row.add_theme_constant_override("separation", 8)
	_crosshair_r_spin = _mini_spin(xr_rgb_row, "R", 0, 255)
	_crosshair_g_spin = _mini_spin(xr_rgb_row, "G", 0, 255)
	_crosshair_b_spin = _mini_spin(xr_rgb_row, "B", 0, 255)
	_crosshair_r_spin.value_changed.connect(_on_misc_field_changed)
	_crosshair_g_spin.value_changed.connect(_on_misc_field_changed)
	_crosshair_b_spin.value_changed.connect(_on_misc_field_changed)
	vbox.add_child(xr_rgb_row)
	_crosshair_rgb_row = xr_rgb_row

	vbox.add_child(HSeparator.new())
	_misc_end_idx = vbox.get_child_count() - 1

	sync_from_main()
	_refresh_expandable_state()
	_panel_menu_log("SettingsPanel.build() end vbox_children=%d" % vbox.get_child_count())


func _set_vbox_children_visible(vbox: VBoxContainer, start_idx: int, end_idx: int, visible: bool) -> void:
	if vbox == null:
		return
	if start_idx < 0 || end_idx < start_idx:
		return
	var last := mini(end_idx, vbox.get_child_count() - 1)
	for i in range(start_idx, last + 1):
		var n := vbox.get_child(i)
		if n is CanvasItem:
			(n as CanvasItem).visible = visible


func _refresh_expandable_state() -> void:
	var root := _current_content_vbox()
	if root == null:
		return
	if _customize_toggle_btn != null:
		_customize_toggle_btn.text = "Customize %s" % ("▼" if _customize_open else "▶")
		_customize_toggle_btn.button_pressed = _customize_open
	if _vitals_toggle_btn != null:
		_vitals_toggle_btn.visible = _customize_open
		_vitals_toggle_btn.text = "Vitals %s" % ("▼" if _vitals_open else "▶")
		_vitals_toggle_btn.button_pressed = _vitals_open
	if _ailments_toggle_btn != null:
		_ailments_toggle_btn.visible = _customize_open
		_ailments_toggle_btn.text = "Ailments %s" % ("▼" if _ailments_open else "▶")
		_ailments_toggle_btn.button_pressed = _ailments_open
	if _misc_toggle_btn != null:
		_misc_toggle_btn.visible = _customize_open
		_misc_toggle_btn.text = "Misc %s" % ("▼" if _misc_open else "▶")
		_misc_toggle_btn.button_pressed = _misc_open
	_set_vbox_children_visible(root, _vitals_start_idx, _vitals_end_idx, _customize_open && _vitals_open)
	_set_vbox_children_visible(root, _ailments_start_idx, _ailments_end_idx, _customize_open && _ailments_open)
	_set_vbox_children_visible(root, _misc_start_idx, _misc_end_idx, _customize_open && _misc_open)
	# Re-apply nested Misc visibility after section-level visibility changes.
	_update_misc_compass_rows_visibility()


func _current_content_vbox() -> VBoxContainer:
	if _preset_option != null:
		var p := _preset_option.get_parent()
		if p != null:
			return p.get_parent() as VBoxContainer
	return null


func _on_customize_toggled() -> void:
	_customize_open = _customize_toggle_btn.button_pressed if _customize_toggle_btn != null else _customize_open
	_refresh_expandable_state()


func _on_vitals_section_toggled() -> void:
	_vitals_open = _vitals_toggle_btn.button_pressed if _vitals_toggle_btn != null else _vitals_open
	_refresh_expandable_state()


func _on_ailments_section_toggled() -> void:
	_ailments_open = _ailments_toggle_btn.button_pressed if _ailments_toggle_btn != null else _ailments_open
	_refresh_expandable_state()


func _on_misc_section_toggled() -> void:
	_misc_open = _misc_toggle_btn.button_pressed if _misc_toggle_btn != null else _misc_open
	_refresh_expandable_state()


func _panel_menu_log(msg: String) -> void:
	var mm: Variant = Engine.get_meta(&"SimpleHUDMain", null)
	if mm != null && (mm as Object).has_method(&"log_menu_panel_diag"):
		(mm as Node).call(&"log_menu_panel_diag", msg)


func _on_back_pressed() -> void:
	var m: Variant = Engine.get_meta(&"SimpleHUDMain", null)
	if m != null && (m as Object).has_method(&"close_simplehud_menu_panel"):
		(m as Node).call(&"close_simplehud_menu_panel")
		return
	if _panel_root != null:
		_panel_root.hide()
	var main_blk: Node = null
	if _menu_root != null:
		main_blk = _menu_root.get_node_or_null("Main")
	if main_blk != null:
		main_blk.show()


func on_menu_opened() -> void:
	_customize_open = false
	_vitals_open = false
	_ailments_open = false
	_misc_open = false
	_refresh_expandable_state()
	sync_from_main()


func _add_labeled_option(parent: Control, label_text: String, items: Array) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lab := Label.new()
	lab.text = label_text
	lab.custom_minimum_size.x = 160
	row.add_child(lab)
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_ALL
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in items:
		ob.add_item(str(s))
	row.add_child(ob)
	parent.add_child(row)
	return ob


func _add_labeled_spin(
	parent: Control,
	label_text: String,
	min_v: float,
	max_v: float,
	step: float,
	decimals: int,
) -> SpinBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lab := Label.new()
	lab.text = label_text
	lab.custom_minimum_size.x = 160
	row.add_child(lab)
	var sp := SpinBox.new()
	sp.min_value = min_v
	sp.max_value = max_v
	sp.step = step
	sp.decimals = decimals
	sp.rounded = decimals <= 0
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.focus_mode = Control.FOCUS_ALL
	row.add_child(sp)
	parent.add_child(row)
	return sp


func _mini_spin(row: HBoxContainer, letter: String, min_v: float, max_v: float) -> SpinBox:
	var l := Label.new()
	l.text = letter
	l.custom_minimum_size.x = 14
	row.add_child(l)
	var sp := SpinBox.new()
	sp.min_value = min_v
	sp.max_value = max_v
	sp.step = 1
	sp.rounded = true
	sp.custom_minimum_size.x = 56
	sp.focus_mode = Control.FOCUS_ALL
	row.add_child(sp)
	return sp


func _anchor_index_from_key(key: String) -> int:
	match key.strip_edges().to_lower():
		"top":
			return 0
		"bottom":
			return 1
		"left":
			return 2
		"right":
			return 3
		_:
			return 1


func _anchor_key_from_index(idx: int) -> String:
	match clampi(idx, 0, 3):
		0:
			return "top"
		1:
			return "bottom"
		2:
			return "left"
		_:
			return "right"


## Top/Bottom → horizontal strip; Left/Right → vertical strip (matches Main.status_stack_direction).
func _ailment_anchor_is_horizontal() -> bool:
	var i := clampi(_anchor_option.selected, 0, 3)
	return i == 0 or i == 1


func _refresh_ailment_spread_option_items(strip_align_from_cfg: String) -> void:
	if _status_strip_align_opt == null:
		return
	_status_strip_align_opt.clear()
	if _ailment_anchor_is_horizontal():
		_status_strip_align_opt.add_item("Left to right")
		_status_strip_align_opt.add_item("Centered on the edge")
		_status_strip_align_opt.add_item("Right to left")
	else:
		_status_strip_align_opt.add_item("Top to bottom")
		_status_strip_align_opt.add_item("Centered on the edge")
		_status_strip_align_opt.add_item("Bottom to top")
	_status_strip_align_opt.select(_status_strip_align_sel_from_cfg(str(strip_align_from_cfg)))


func _vitals_anchor_is_horizontal() -> bool:
	var i := clampi(_stat_anchor.selected, 0, 3)
	return i == 0 or i == 1


func _refresh_vitals_order_option_items(strip_align_from_cfg: String) -> void:
	if _vitals_strip_align_opt == null:
		return
	_vitals_strip_align_opt.set_block_signals(true)
	_vitals_strip_align_opt.clear()
	if _vitals_anchor_is_horizontal():
		_vitals_strip_align_opt.add_item("Left to right")
		_vitals_strip_align_opt.add_item("Centered on the edge")
		_vitals_strip_align_opt.add_item("Right to left")
	else:
		_vitals_strip_align_opt.add_item("Top to bottom")
		_vitals_strip_align_opt.add_item("Centered on the edge")
		_vitals_strip_align_opt.add_item("Bottom to top")
	_vitals_strip_align_opt.select(_vitals_strip_align_sel_from_cfg(str(strip_align_from_cfg)))
	_vitals_strip_align_opt.set_block_signals(false)


func _vitals_strip_align_sel_from_cfg(key: String) -> int:
	match UserPreferencesScript.normalize_strip_alignment(str(key)):
		"center":
			return 1
		"trailing":
			return 2
		_:
			return 0


func _vitals_strip_align_key_from_sel(sel: int) -> String:
	match clampi(sel, 0, 2):
		1:
			return "center"
		2:
			return "trailing"
		_:
			return "leading"


func _status_strip_align_sel_from_cfg(key: String) -> int:
	match UserPreferencesScript.normalize_status_strip_alignment(str(key)):
		"center":
			return 1
		"leading":
			return 0
		_:
			return 2


func _status_strip_align_key_from_sel(sel: int) -> String:
	match clampi(sel, 0, 2):
		0:
			return "leading"
		1:
			return "center"
		_:
			return "trailing"


func sync_from_main() -> void:
	_ui_sync = true
	var m := _simplehud_main()
	if m == null:
		push_warning("SimpleHUD: sync_from_main: SimpleHUDMain missing — menu UI may be blank or stale.")
		_panel_menu_log("sync_from_main: SimpleHUDMain missing — UI values not refreshed")
		_ui_sync = false
		return

	_refresh_current_preset_label()

	var sd: Dictionary = m.get_status_tray_settings_for_ui()
	_auto_hide_cb.set_pressed_no_signal(bool(sd.get("auto_hide", false)))
	_ailments_fill_empty_cb.set_pressed_no_signal(bool(sd.get("fill_empty_space", false)))
	_anchor_option.select(_anchor_index_from_key(str(sd.get("anchor", "right"))))
	_refresh_ailment_spread_option_items(str(sd.get("strip_alignment", "trailing")))
	_padding_spin.set_value_no_signal(float(sd.get("padding_px", 5.0)))
	_status_spacing_spin.set_value_no_signal(float(sd.get("spacing_px", 2.0)))
	_scale_spin.set_value_no_signal(float(sd.get("scale_pct", 100.0)))
	_inactive_alpha_spin.set_value_no_signal(float(sd.get("inactive_alpha_pct", 25.0)))
	_r_spin.set_value_no_signal(float(sd.get("r", 120)))
	_g_spin.set_value_no_signal(float(sd.get("g", 0)))
	_b_spin.set_value_no_signal(float(sd.get("b", 0)))
	_ir_spin.set_value_no_signal(float(sd.get("inactive_r", sd.get("r", 120))))
	_ig_spin.set_value_no_signal(float(sd.get("inactive_g", sd.get("g", 0))))
	_ib_spin.set_value_no_signal(float(sd.get("inactive_b", sd.get("b", 0))))

	var strip: Dictionary = m.get_vitals_strip_settings_for_ui()
	_spacing_spin.set_value_no_signal(float(strip.get("spacing_px", 12.0)))
	_refresh_vitals_order_option_items(str(strip.get("strip_alignment", "leading")))
	_vitals_fill_empty_cb.set_pressed_no_signal(bool(strip.get("fill_empty_space", false)))

	if m.has_method(&"get_misc_settings_for_ui"):
		var misc: Dictionary = (m as Node).call(&"get_misc_settings_for_ui")
		_compass_enable_cb.set_pressed_no_signal(bool(misc.get("compass_enabled", false)))
		_compass_anchor_opt.select(1 if str(misc.get("compass_anchor", "top")).to_lower() == "bottom" else 0)
		_compass_alpha_spin.set_value_no_signal(float(misc.get("compass_alpha_pct", 95.0)))
		_compass_r_spin.set_value_no_signal(float(misc.get("compass_r", 220)))
		_compass_g_spin.set_value_no_signal(float(misc.get("compass_g", 220)))
		_compass_b_spin.set_value_no_signal(float(misc.get("compass_b", 220)))
		_crosshair_enable_cb.set_pressed_no_signal(bool(misc.get("crosshair_enabled", false)))
		_crosshair_shape_opt.select(1 if str(misc.get("crosshair_shape", "crosshair")).to_lower() == "dot" else 0)
		_crosshair_alpha_spin.set_value_no_signal(float(misc.get("crosshair_alpha_pct", 95.0)))
		_crosshair_scale_spin.set_value_no_signal(float(misc.get("crosshair_scale_pct", 100.0)))
		_crosshair_bloom_cb.set_pressed_no_signal(bool(misc.get("crosshair_bloom_enabled", true)))
		_crosshair_hide_ads_cb.set_pressed_no_signal(bool(misc.get("crosshair_hide_during_aiming", false)))
		_crosshair_hide_stowed_cb.set_pressed_no_signal(bool(misc.get("crosshair_hide_while_stowed", false)))
		_fps_hide_label_cb.set_pressed_no_signal(bool(misc.get("fps_hide_label_prefix", true)))
		match str(misc.get("map_label_mode", "default")).to_lower():
			"map_only":
				_map_label_mode_opt.select(1)
			"region_only":
				_map_label_mode_opt.select(2)
			_:
				_map_label_mode_opt.select(0)
		_crosshair_r_spin.set_value_no_signal(float(misc.get("crosshair_r", 220)))
		_crosshair_g_spin.set_value_no_signal(float(misc.get("crosshair_g", 220)))
		_crosshair_b_spin.set_value_no_signal(float(misc.get("crosshair_b", 220)))
	_update_misc_compass_rows_visibility()

	var vm := str(strip.get("vitals_transparency_mode", "dynamic"))
	_vitals_transparency_opt.set_block_signals(true)
	match vm:
		"static":
			_vitals_transparency_opt.select(1)
		"opaque":
			# Legacy mode: treat as static with 100% opacity in the 2-option UI.
			_vitals_transparency_opt.select(1)
		_:
			_vitals_transparency_opt.select(0)
	_vitals_transparency_opt.set_block_signals(false)
	var static_pct := float(strip.get("vitals_static_opacity_pct", 75.0))
	if vm == "opaque":
		static_pct = 100.0
	_vitals_static_opacity_spin.set_value_no_signal(static_pct)
	_update_vitals_static_opacity_row_visibility()

	if m.has_method(&"get_simplehud_preset_dropdown_index_for_active"):
		_preset_option.set_block_signals(true)
		_preset_option.select((m as Node).call(&"get_simplehud_preset_dropdown_index_for_active"))
		_preset_option.set_block_signals(false)

	_sync_stat_editor_panel()
	_ui_sync = false
	_refresh_expandable_state()


func _refresh_current_preset_label() -> void:
	var m := _simplehud_main()
	if _current_preset_value == null || m == null:
		return
	if m.has_method(&"get_simplehud_current_preset_state_for_ui"):
		var st: Dictionary = (m as Node).call(&"get_simplehud_current_preset_state_for_ui")
		_current_preset_value.text = str(st.get("label", "User Customized"))


func _sync_stat_editor_panel() -> void:
	var m := _simplehud_main()
	if m == null:
		return

	var d: Dictionary = {}
	if m.has_method(&"get_vitals_common_settings_for_ui"):
		d = (m as Node).call(&"get_vitals_common_settings_for_ui")
	else:
		d = m.get_stat_settings_for_ui(CFG.STAT_HEALTH)
	var num_only := bool(d.get("numeric_only_global", false))

	_stat_mode.set_item_disabled(1, num_only)
	var want_radial := bool(d.get("radial", true))
	if num_only:
		_stat_mode.select(0)
	else:
		_stat_mode.select(1 if want_radial else 0)

	_stat_anchor.select(_anchor_index_from_key(str(d.get("anchor", "bottom"))))
	_refresh_vitals_order_option_items(_vitals_strip_align_key_from_sel(_vitals_strip_align_opt.selected))
	_stat_padding.set_value_no_signal(float(d.get("padding_px", 8.0)))
	_stat_scale.set_value_no_signal(float(d.get("scale_pct", 100.0)))
	_stat_threshold.set_value_no_signal(float(d.get("visible_threshold_pct", 79.0)))

	var gm := str(d.get("gradient_mode", "preset"))
	var gidx := 0
	if gm == "white":
		gidx = 1
	elif gm == "custom":
		gidx = 2
	_grad_mode.select(gidx)

	var gd: Dictionary = {}
	var gv: Variant = d.get("gradient", {})
	if gv is Dictionary:
		gd = gv as Dictionary

	_g_hi_pct.set_value_no_signal(float(gd.get("high_threshold_pct", 75.0)))
	_g_mid_pct.set_value_no_signal(float(gd.get("mid_threshold_pct", 50.0)))
	_g_lo_pct.set_value_no_signal(float(gd.get("low_threshold_pct", 0.0)))

	var hir: Array = gd.get("high_rgb", [255, 255, 255])
	var mir: Array = gd.get("mid_rgb", [190, 190, 15])
	var lor: Array = gd.get("low_rgb", [200, 25, 15])
	if hir.size() < 3:
		hir = [255, 255, 255]
	if mir.size() < 3:
		mir = [190, 190, 15]
	if lor.size() < 3:
		lor = [200, 25, 15]

	_gh_r.set_value_no_signal(float(hir[0]))
	_gh_g.set_value_no_signal(float(hir[1]))
	_gh_b.set_value_no_signal(float(hir[2]))
	_gm_r.set_value_no_signal(float(mir[0]))
	_gm_g.set_value_no_signal(float(mir[1]))
	_gm_b.set_value_no_signal(float(mir[2]))
	_gl_r.set_value_no_signal(float(lor[0]))
	_gl_g.set_value_no_signal(float(lor[1]))
	_gl_b.set_value_no_signal(float(lor[2]))

	_grad_custom.visible = gidx == 2


func _simplehud_main() -> Node:
	var v: Variant = Engine.get_meta(&"SimpleHUDMain", null)
	if v is Node && is_instance_valid(v):
		return v as Node
	## RefCounted is not a Node — cannot use get_node_or_null() on self. Resolve autoload from tree root.
	var tree := Engine.get_main_loop() as SceneTree
	var root: Node = tree.root if tree != null else null
	var n: Node = null
	if root != null:
		n = root.get_node_or_null(NodePath("SimpleHUDMain"))
	if n == null && !Engine.has_meta(&"_simplehud_warned_missing_main"):
		Engine.set_meta(&"_simplehud_warned_missing_main", true)
		push_warning(
			"SimpleHUD: SimpleHUDMain not found (Engine meta or root/SimpleHUDMain). Preferences UI cannot apply settings."
		)
	return n


func _apply_status_from_ui() -> void:
	if _ui_sync:
		return
	var mm := _simplehud_main()
	if mm == null:
		return
	mm.apply_status_tray_settings_from_ui(
		_auto_hide_cb.button_pressed,
		_ailments_fill_empty_cb.button_pressed,
		_anchor_key_from_index(_anchor_option.selected),
		float(_padding_spin.value),
		float(_status_spacing_spin.value),
		float(_scale_spin.value),
		float(_inactive_alpha_spin.value),
		int(_r_spin.value),
		int(_g_spin.value),
		int(_b_spin.value),
		_status_strip_align_key_from_sel(_status_strip_align_opt.selected),
		int(_ir_spin.value),
		int(_ig_spin.value),
		int(_ib_spin.value),
	)
	_refresh_current_preset_label()


func _on_status_numeric_field_changed(_v: float) -> void:
	_apply_status_from_ui()


func _apply_strip_from_ui() -> void:
	if _ui_sync:
		return
	var mm := _simplehud_main()
	if mm == null:
		return
	mm.apply_vitals_strip_settings_from_ui(
		float(_spacing_spin.value),
		_vitals_strip_align_key_from_sel(_vitals_strip_align_opt.selected),
		_vitals_fill_empty_cb.button_pressed,
	)
	_refresh_current_preset_label()


func _apply_misc_from_ui() -> void:
	if _ui_sync:
		return
	var mm := _simplehud_main()
	if mm == null || !(mm as Object).has_method(&"apply_misc_settings_from_ui"):
		return
	(mm as Node).call(
		&"apply_misc_settings_from_ui",
		_compass_enable_cb.button_pressed,
		"bottom" if _compass_anchor_opt.selected == 1 else "top",
		float(_compass_alpha_spin.value),
		int(_compass_r_spin.value),
		int(_compass_g_spin.value),
		int(_compass_b_spin.value),
		_crosshair_enable_cb.button_pressed,
		float(_crosshair_alpha_spin.value),
		int(_crosshair_r_spin.value),
		int(_crosshair_g_spin.value),
		int(_crosshair_b_spin.value),
		"dot" if _crosshair_shape_opt.selected == 1 else "crosshair",
		float(_crosshair_scale_spin.value),
		_crosshair_bloom_cb.button_pressed,
		_crosshair_hide_ads_cb.button_pressed,
		_crosshair_hide_stowed_cb.button_pressed,
		_fps_hide_label_cb.button_pressed,
		"map_only" if _map_label_mode_opt.selected == 1 else ("region_only" if _map_label_mode_opt.selected == 2 else "default")
	)
	_refresh_current_preset_label()


func _update_misc_compass_rows_visibility() -> void:
	var show_misc: bool = _customize_open && _misc_open
	var show_extra: bool = show_misc && _compass_enable_cb != null && _compass_enable_cb.button_pressed
	if _compass_anchor_row != null:
		(_compass_anchor_row as CanvasItem).visible = show_extra
	if _compass_alpha_row != null:
		(_compass_alpha_row as CanvasItem).visible = show_extra
	if _compass_rgb_title != null:
		_compass_rgb_title.visible = show_extra
	if _compass_rgb_row != null:
		(_compass_rgb_row as CanvasItem).visible = show_extra
	var show_crosshair: bool = show_misc && _crosshair_enable_cb != null && _crosshair_enable_cb.button_pressed
	if _crosshair_shape_row != null:
		(_crosshair_shape_row as CanvasItem).visible = show_crosshair
	if _crosshair_alpha_row != null:
		(_crosshair_alpha_row as CanvasItem).visible = show_crosshair
	if _crosshair_scale_row != null:
		(_crosshair_scale_row as CanvasItem).visible = show_crosshair
	if _crosshair_bloom_row != null:
		(_crosshair_bloom_row as CanvasItem).visible = show_crosshair
	if _crosshair_hide_ads_row != null:
		(_crosshair_hide_ads_row as CanvasItem).visible = show_crosshair
	if _crosshair_hide_stowed_row != null:
		(_crosshair_hide_stowed_row as CanvasItem).visible = show_crosshair
	if _crosshair_group_end_sep != null:
		(_crosshair_group_end_sep as CanvasItem).visible = show_crosshair
	if _fps_hide_label_row != null:
		(_fps_hide_label_row as CanvasItem).visible = show_misc
	if _map_label_mode_row != null:
		(_map_label_mode_row as CanvasItem).visible = show_misc
	if _crosshair_rgb_title != null:
		_crosshair_rgb_title.visible = show_crosshair
	if _crosshair_rgb_row != null:
		(_crosshair_rgb_row as CanvasItem).visible = show_crosshair


func _update_vitals_static_opacity_row_visibility() -> void:
	if _vitals_static_opacity_row != null:
		_vitals_static_opacity_row.visible = _vitals_transparency_opt.selected == 1


func _on_vitals_transparency_changed(_idx: int) -> void:
	_update_vitals_static_opacity_row_visibility()
	_push_vitals_transparency_to_main()


func _on_vitals_static_opacity_changed(_v: float) -> void:
	_push_vitals_transparency_to_main()


func _push_vitals_transparency_to_main() -> void:
	if _ui_sync:
		return
	var mm := _simplehud_main()
	if mm == null || !(mm as Object).has_method(&"apply_vitals_transparency_from_ui"):
		return
	var mk := "dynamic"
	match _vitals_transparency_opt.selected:
		1:
			mk = "static"
		_:
			mk = "dynamic"
	(mm as Node).call(&"apply_vitals_transparency_from_ui", mk, float(_vitals_static_opacity_spin.value))
	_refresh_current_preset_label()


func _build_gradient_dict_for_custom() -> Dictionary:
	return {
		"mode": "gradient",
		"high_threshold_pct": float(_g_hi_pct.value),
		"mid_threshold_pct": float(_g_mid_pct.value),
		"low_threshold_pct": float(_g_lo_pct.value),
		"high_rgb": [int(_gh_r.value), int(_gh_g.value), int(_gh_b.value)],
		"mid_rgb": [int(_gm_r.value), int(_gm_g.value), int(_gm_b.value)],
		"low_rgb": [int(_gl_r.value), int(_gl_g.value), int(_gl_b.value)],
	}


func _apply_stat_from_ui() -> void:
	if _ui_sync:
		return
	var mm := _simplehud_main()
	if mm == null:
		return
	var radial := _stat_mode.selected == 1
	var gmode := "preset"
	match _grad_mode.selected:
		1:
			gmode = "white"
		2:
			gmode = "custom"
		_:
			gmode = "preset"

	var stat_dict: Dictionary = {
		"radial": radial,
		"anchor": _anchor_key_from_index(_stat_anchor.selected),
		"padding_px": float(_stat_padding.value),
		"scale_pct": float(_stat_scale.value),
		"visible_threshold_pct": float(_stat_threshold.value),
		"gradient_mode": gmode,
	}
	if gmode == "custom":
		stat_dict["gradient"] = _build_gradient_dict_for_custom()

	mm.apply_stat_settings_to_all_from_ui(stat_dict)
	_refresh_current_preset_label()


func _on_auto_hide_toggled(_on: bool) -> void:
	_apply_status_from_ui()


func _on_ailments_fill_empty_toggled(_on: bool) -> void:
	_apply_status_from_ui()


func _on_misc_field_toggled(_on: bool) -> void:
	_update_misc_compass_rows_visibility()
	_apply_misc_from_ui()


func _on_misc_field_changed(_v: float) -> void:
	_apply_misc_from_ui()


func _on_misc_field_changed_idx(_idx: int) -> void:
	_apply_misc_from_ui()


func _on_anchor_selected(_idx: int) -> void:
	if _ui_sync:
		return
	var preserve_key := "trailing"
	if _status_strip_align_opt != null && _status_strip_align_opt.item_count > 0:
		preserve_key = _status_strip_align_key_from_sel(_status_strip_align_opt.selected)
	_refresh_ailment_spread_option_items(preserve_key)
	_apply_status_from_ui()


func _on_padding_changed(_v: float) -> void:
	_apply_status_from_ui()


func _on_scale_changed(_v: float) -> void:
	_apply_status_from_ui()


func _on_rgb_changed(_v: float) -> void:
	_apply_status_from_ui()


func _on_spacing_strip_changed(_v: float) -> void:
	_apply_strip_from_ui()


func _on_vitals_strip_align_changed(_idx: int) -> void:
	_apply_strip_from_ui()


func _on_vitals_fill_empty_toggled(_on: bool) -> void:
	_apply_strip_from_ui()


func _on_vitals_anchor_changed(idx: int) -> void:
	var preserve_key := "leading"
	if _vitals_strip_align_opt != null && _vitals_strip_align_opt.item_count > 0:
		preserve_key = _vitals_strip_align_key_from_sel(_vitals_strip_align_opt.selected)
	_refresh_vitals_order_option_items(preserve_key)
	_on_stat_field_changed(idx)


func _on_preset_selected(idx: int) -> void:
	if _ui_sync:
		return
	if idx <= 0:
		return
	var mm := _simplehud_main()
	if mm == null || !(mm as Object).has_method(&"get_simplehud_preset_id_at_dropdown_index"):
		return
	var pid: String = str((mm as Node).call(&"get_simplehud_preset_id_at_dropdown_index", idx))
	if pid == "":
		return
	if !(mm as Object).has_method(&"apply_simplehud_preset"):
		return
	var ok: bool = bool((mm as Node).call(&"apply_simplehud_preset", pid))
	if !ok:
		return
	_ui_sync = true
	sync_from_main()
	_ui_sync = false


func _on_status_field_changed(_idx: int) -> void:
	_apply_status_from_ui()


func _on_status_spacing_changed(_v: float) -> void:
	_apply_status_from_ui()


func _on_inactive_rgb_changed(_v: float) -> void:
	_apply_status_from_ui()


func _on_stat_field_changed(_idx: int) -> void:
	_apply_stat_from_ui()


func _on_stat_field_changed_val(_v: float) -> void:
	_apply_stat_from_ui()


func _on_grad_mode_changed(_idx: int) -> void:
	_grad_custom.visible = _grad_mode.selected == 2
	_apply_stat_from_ui()

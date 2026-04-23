extends RefCounted

## Shared SimpleHUD preferences UI: vitals + status tray (same as legacy inventory Tools tab).

const CFG := preload("res://SimpleHUD/Config.gd")
const UserPreferencesScript := preload("res://SimpleHUD/UserPreferences.gd")
const SimpleHUDPresetsReg := preload("res://SimpleHUD/PresetsRegistry.gd")

const STAT_ROWS: Array = [
	[CFG.STAT_HEALTH, "Health"],
	[CFG.STAT_ENERGY, "Energy"],
	[CFG.STAT_HYDRATION, "Hydration"],
	[CFG.STAT_MENTAL, "Mental"],
	[CFG.STAT_BODY_TEMP, "Temperature"],
	[CFG.STAT_STAMINA, "Stamina"],
	[CFG.STAT_FATIGUE, "Fatigue"],
]

var _menu_root: Control
var _panel_root: Control

var _auto_hide_cb: CheckBox
var _anchor_option: OptionButton
var _stack_direction_opt: OptionButton
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

var _spacing_spin: SpinBox
var _vitals_strip_align_opt: OptionButton
var _numeric_hint: Label
var _numeric_only_cb: CheckBox

var _stat_pick: OptionButton
var _batch_hint: Label
var _stat_mode: OptionButton
var _stat_anchor: OptionButton
var _stat_padding: SpinBox
var _stat_spacing: SpinBox
var _stat_scale: SpinBox
var _stat_threshold: SpinBox
var _grad_mode: OptionButton
var _grad_custom: VBoxContainer

var _g_hi_pct: SpinBox
var _g_mid_pct: SpinBox
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

	var vt := Label.new()
	vt.text = "Vitals (per stat)"
	vt.add_theme_font_size_override("font_size", 18)
	vbox.add_child(vt)

	_spacing_spin = _add_labeled_spin(vbox, "Default spacing between vitals on same edge (px)", 0, 256, 1, 0)
	_spacing_spin.value_changed.connect(_on_spacing_strip_changed)

	_vitals_strip_align_opt = _add_labeled_option(
		vbox,
		"Alignment (vitals along shared edge)",
		["Leading (start → end)", "Center as a block", "Trailing (end ← start)"],
	)
	_vitals_strip_align_opt.item_selected.connect(_on_vitals_strip_align_changed)

	_numeric_hint = Label.new()
	_numeric_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_numeric_hint.add_theme_font_size_override("font_size", 12)
	_numeric_hint.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	vbox.add_child(_numeric_hint)

	_numeric_only_cb = CheckBox.new()
	_numeric_only_cb.text = "Numeric-only vitals (preset lock; disables radial)"
	_numeric_only_cb.focus_mode = Control.FOCUS_NONE
	_numeric_only_cb.toggled.connect(_on_numeric_only_toggled)
	vbox.add_child(_numeric_only_cb)

	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 8)
	var spl := Label.new()
	spl.text = "Configure stat"
	spl.custom_minimum_size.x = 120
	stat_row.add_child(spl)
	_stat_pick = OptionButton.new()
	_stat_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stat_pick.focus_mode = Control.FOCUS_ALL
	_stat_pick.add_item("All stats (batch)")
	for row in STAT_ROWS:
		_stat_pick.add_item(str(row[1]))
	_stat_pick.item_selected.connect(_on_stat_pick_changed)
	stat_row.add_child(_stat_pick)
	vbox.add_child(stat_row)

	_batch_hint = Label.new()
	_batch_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_batch_hint.text = "Batch mode on: values below apply to every vitals stat at once. The panel uses Health as a readout template."
	_batch_hint.add_theme_font_size_override("font_size", 11)
	_batch_hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	_batch_hint.visible = false
	vbox.add_child(_batch_hint)

	_stat_pick.select(1)

	_stat_mode = _add_labeled_option(vbox, "Display", ["Numeric", "Radial"])
	_stat_mode.item_selected.connect(_on_stat_field_changed)

	_stat_anchor = _add_labeled_option(
		vbox,
		"Justification (screen edge)",
		["Top", "Bottom", "Left", "Right"],
	)
	_stat_anchor.item_selected.connect(_on_stat_field_changed)

	_stat_padding = _add_labeled_spin(vbox, "Inset from screen edge (px)", 0, 512, 1, 0)
	_stat_padding.value_changed.connect(_on_stat_field_changed_val)
	_stat_spacing = _add_labeled_spin(vbox, "Spacing to next vital on same edge (px)", 0, 256, 1, 0)
	_stat_spacing.value_changed.connect(_on_stat_field_changed_val)
	_stat_scale = _add_labeled_spin(vbox, "Scale (% of default)", 25, 400, 5, 0)
	_stat_scale.value_changed.connect(_on_stat_field_changed_val)
	_stat_threshold = _add_labeled_spin(vbox, "Show when % ≤ threshold (101 = always)", 0, 101, 1, 0)
	_stat_threshold.value_changed.connect(_on_stat_field_changed_val)

	_grad_mode = _add_labeled_option(
		vbox,
		"Text / arc colors",
		["Default preset", "White only", "Custom gradient"],
	)
	_grad_mode.item_selected.connect(_on_grad_mode_changed)

	_grad_custom = VBoxContainer.new()
	_grad_custom.add_theme_constant_override("separation", 6)
	vbox.add_child(_grad_custom)

	var th_lbl := Label.new()
	th_lbl.text = "Custom gradient (percent of bar / value)"
	th_lbl.add_theme_font_size_override("font_size", 13)
	_grad_custom.add_child(th_lbl)

	_g_hi_pct = _add_labeled_spin(_grad_custom, "High band starts at %", 0, 100, 1, 0)
	_g_hi_pct.value_changed.connect(_on_stat_field_changed_val)
	_g_mid_pct = _add_labeled_spin(_grad_custom, "Mid blend at %", 0, 100, 1, 0)
	_g_mid_pct.value_changed.connect(_on_stat_field_changed_val)

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
	_grad_custom.add_child(row_lo)

	vbox.add_child(HSeparator.new())

	var title := Label.new()
	title.text = "Status ailments"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "Icons for bleeding, dehydration, etc. Saved to user://simplehud_preferences.json."
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	vbox.add_child(hint)

	_auto_hide_cb = CheckBox.new()
	_auto_hide_cb.text = "Hide tray when no active ailments"
	_auto_hide_cb.focus_mode = Control.FOCUS_NONE
	_auto_hide_cb.toggled.connect(_on_auto_hide_toggled)
	vbox.add_child(_auto_hide_cb)

	var status_mode_hint := Label.new()
	status_mode_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_mode_hint.text = "When unchecked (show all icons): inactive ailments use “Inactive ailment RGB” and “Inactive opacity”. When checked: only active ailments are shown (inflicted-only)."
	status_mode_hint.add_theme_font_size_override("font_size", 11)
	status_mode_hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	vbox.add_child(status_mode_hint)

	var anchor_row := HBoxContainer.new()
	anchor_row.add_theme_constant_override("separation", 8)
	var anchor_lbl := Label.new()
	anchor_lbl.text = "Justification"
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

	_stack_direction_opt = _add_labeled_option(
		vbox,
		"Stack direction",
		["Vertical (along edge)", "Horizontal (along edge)"],
	)
	_stack_direction_opt.item_selected.connect(_on_status_field_changed)

	_status_strip_align_opt = _add_labeled_option(
		vbox,
		"Alignment (icons along strip)",
		["Leading (start → end)", "Center as a block", "Trailing (end ← start)"],
	)
	_status_strip_align_opt.item_selected.connect(_on_status_field_changed)

	_padding_spin = _add_labeled_spin(vbox, "Inset from screen edge (px)", 0, 512, 1, 0)
	_padding_spin.value_changed.connect(_on_padding_changed)

	_status_spacing_spin = _add_labeled_spin(vbox, "Spacing between ailment icons (px)", 0, 64, 1, 0)
	_status_spacing_spin.value_changed.connect(_on_status_spacing_changed)

	_scale_spin = _add_labeled_spin(vbox, "Scale (% of default)", 25, 400, 5, 0)
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

	sync_from_main()
	_panel_menu_log("SettingsPanel.build() end vbox_children=%d" % vbox.get_child_count())


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


func _stack_dir_sel(dir: String) -> int:
	return 1 if str(dir) == "horizontal_left" else 0


func _stack_dir_from_sel(sel: int) -> String:
	return "horizontal_left" if clampi(sel, 0, 1) == 1 else "vertical_up"


func _editor_template_stat_id() -> StringName:
	var sel := _stat_pick.selected
	if sel <= 0:
		return CFG.STAT_HEALTH
	return STAT_ROWS[sel - 1][0]


func sync_from_main() -> void:
	_ui_sync = true
	var m := _simplehud_main()
	if m == null:
		push_warning("SimpleHUD: sync_from_main: SimpleHUDMain missing — menu UI may be blank or stale.")
		_panel_menu_log("sync_from_main: SimpleHUDMain missing — UI values not refreshed")
		_ui_sync = false
		return

	var sd: Dictionary = m.get_status_tray_settings_for_ui()
	_auto_hide_cb.set_pressed_no_signal(bool(sd.get("auto_hide", false)))
	_anchor_option.select(_anchor_index_from_key(str(sd.get("anchor", "right"))))
	_stack_direction_opt.select(_stack_dir_sel(str(sd.get("stack_direction", "vertical_up"))))
	_status_strip_align_opt.select(_status_strip_align_sel_from_cfg(str(sd.get("strip_alignment", "trailing"))))
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
	_vitals_strip_align_opt.select(_vitals_strip_align_sel_from_cfg(str(strip.get("strip_alignment", "leading"))))
	var num_only := bool(strip.get("numeric_only", false))
	_numeric_only_cb.set_pressed_no_signal(num_only)

	if m.has_method(&"get_simplehud_preset_dropdown_index_for_active"):
		_preset_option.set_block_signals(true)
		_preset_option.select((m as Node).call(&"get_simplehud_preset_dropdown_index_for_active"))
		_preset_option.set_block_signals(false)

	_sync_stat_editor_panel()
	_ui_sync = false


func _sync_stat_editor_panel() -> void:
	var m := _simplehud_main()
	if m == null:
		return
	_batch_hint.visible = _stat_pick.selected == 0

	var sid := _editor_template_stat_id()
	var d: Dictionary = m.get_stat_settings_for_ui(sid)
	var num_only := bool(d.get("numeric_only_global", false))
	if num_only:
		_numeric_hint.text = "Numeric-only is on (common on TextNumeric* VMZ presets). Uncheck “Numeric-only vitals” or choose Radial to clear it."
	else:
		_numeric_hint.text = ""

	_stat_mode.set_item_disabled(1, num_only)
	var want_radial := bool(d.get("radial", true))
	if num_only:
		_stat_mode.select(0)
	else:
		_stat_mode.select(1 if want_radial else 0)

	_stat_anchor.select(_anchor_index_from_key(str(d.get("anchor", "bottom"))))
	_stat_padding.set_value_no_signal(float(d.get("padding_px", 8.0)))
	_stat_spacing.set_value_no_signal(float(d.get("spacing_px", 12.0)))
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
		_anchor_key_from_index(_anchor_option.selected),
		float(_padding_spin.value),
		float(_status_spacing_spin.value),
		float(_scale_spin.value),
		float(_inactive_alpha_spin.value),
		int(_r_spin.value),
		int(_g_spin.value),
		int(_b_spin.value),
		_stack_dir_from_sel(_stack_direction_opt.selected),
		_status_strip_align_key_from_sel(_status_strip_align_opt.selected),
		int(_ir_spin.value),
		int(_ig_spin.value),
		int(_ib_spin.value),
	)


func _on_status_numeric_field_changed(_v: float) -> void:
	_apply_status_from_ui()


func _on_numeric_only_toggled(_on: bool) -> void:
	if _ui_sync:
		return
	var mm := _simplehud_main()
	if mm == null:
		return
	mm.apply_numeric_only_from_ui(_numeric_only_cb.button_pressed)
	_ui_sync = true
	_sync_stat_editor_panel()
	_ui_sync = false


func _apply_strip_from_ui() -> void:
	if _ui_sync:
		return
	var mm := _simplehud_main()
	if mm == null:
		return
	mm.apply_vitals_strip_settings_from_ui(
		float(_spacing_spin.value),
		_vitals_strip_align_key_from_sel(_vitals_strip_align_opt.selected),
	)


func _build_gradient_dict_for_custom() -> Dictionary:
	return {
		"mode": "gradient",
		"high_threshold_pct": float(_g_hi_pct.value),
		"mid_threshold_pct": float(_g_mid_pct.value),
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
		"spacing_px": float(_stat_spacing.value),
		"scale_pct": float(_stat_scale.value),
		"visible_threshold_pct": float(_stat_threshold.value),
		"gradient_mode": gmode,
	}
	if gmode == "custom":
		stat_dict["gradient"] = _build_gradient_dict_for_custom()

	if _stat_pick.selected == 0:
		mm.apply_stat_settings_to_all_from_ui(stat_dict)
	else:
		var idx := _stat_pick.selected - 1
		var sid: StringName = STAT_ROWS[idx][0]
		mm.apply_stat_settings_from_ui(sid, stat_dict)


func _on_auto_hide_toggled(_on: bool) -> void:
	_apply_status_from_ui()


func _on_anchor_selected(_idx: int) -> void:
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


func _on_stat_pick_changed(_idx: int) -> void:
	_ui_sync = true
	_batch_hint.visible = _stat_pick.selected == 0
	_sync_stat_editor_panel()
	_ui_sync = false


func _on_stat_field_changed(_idx: int) -> void:
	_apply_stat_from_ui()


func _on_stat_field_changed_val(_v: float) -> void:
	_apply_stat_from_ui()


func _on_grad_mode_changed(_idx: int) -> void:
	_grad_custom.visible = _grad_mode.selected == 2
	_apply_stat_from_ui()

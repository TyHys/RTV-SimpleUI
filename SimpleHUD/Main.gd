extends Node

## Native `Node` lifecycle + `super()` is a parse error in this game's GDScript build; omit `super()` here.

## Same pattern as BikeMod: path from scene tree root, not "/root/Map/..." (that breaks when resolved from root).
const SimpleHUDConfigScript := preload("res://SimpleHUD/Config.gd")
const SimpleHudOverlay := preload("res://SimpleHUD/HudOverlay.gd")
const UserPreferencesScript := preload("res://SimpleHUD/UserPreferences.gd")
const SimpleHUDSettingsPanelScript := preload("res://SimpleHUD/SimpleHUDSettingsPanel.gd")
const SimpleHUDPresetsReg := preload("res://SimpleHUD/PresetsRegistry.gd")

## Set true to enable verbose console diagnostics during development.
const SIMPLEHUD_DIAG_LOG := false

## Verbose diagnostics for main-menu SimpleHUD overlay (sizes, visibility, deferred layout).
const SIMPLEHUD_MENU_PANEL_DIAG := false

var game_data: Resource = preload("res://Resources/GameData.tres")

var _cfg: RefCounted
var _hud: Control
var _canvas_layer: CanvasLayer
var _overlay: SimpleHudOverlay

## Runtime `GameData` the game mutates (often not the same object identity as preload if the scene holds a live ref).
var _live_game_data: Resource = null
var _prefs_cache: Resource = null
var _prefs_cache_frame: int = -10000
const _PREFS_CACHE_TTL_FRAMES := 30

var _logged_overlay_missing_refresh: bool = false

## Main menu (`Menu.tscn`) SimpleHUD overlay; used to close on Escape and from Return.
var _simplehud_main_menu_scene: Control = null
var _simplehud_main_menu_panel_layer: Control = null
var _simplehud_menu_inner: Control = null
var _fps_info_node: Control = null
var _next_menu_install_probe_frame: int = 0
const _MENU_INSTALL_PROBE_INTERVAL_FRAMES := 10

## Menu card: was fixed 512×704 px so the dark fill was narrower than long label rows (~674 px). Size from viewport instead.
const SIMPLEHUD_MENU_WIDTH_FRAC := 0.52
const SIMPLEHUD_MENU_MIN_WIDTH := 700.0
const SIMPLEHUD_MENU_MAX_WIDTH := 980.0
const SIMPLEHUD_MENU_HEIGHT_FRAC := 0.72
const SIMPLEHUD_MENU_MIN_HEIGHT := 520.0
const SIMPLEHUD_MENU_MAX_HEIGHT := 920.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cfg = SimpleHUDConfigScript.new()
	_cfg.load_all()
	UserPreferencesScript.merge_into(_cfg)
	log_diag(
		"Ready: preset numeric_only=%s health_radial_cfg=%s get_radial(health)=%s"
		% [_cfg.numeric_only, _cfg.radial.get(SimpleHUDConfigScript.STAT_HEALTH, false), _cfg.get_radial(SimpleHUDConfigScript.STAT_HEALTH)]
	)
	Engine.set_meta(&"SimpleHUDMain", self)


func _unhandled_input(ev: InputEvent) -> void:
	if !ev.is_action_pressed(&"ui_cancel"):
		return
	var p: Control = _simplehud_main_menu_panel_layer
	if p == null || !is_instance_valid(p) || !p.visible:
		return
	close_simplehud_menu_panel()
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()


func _layout_simplehud_menu_inner(inner: Control, content_min_width: float = -1.0) -> void:
	if inner == null || !is_instance_valid(inner):
		return
	var sz := Vector2(1920, 1080)
	var vp := inner.get_viewport()
	if vp != null:
		sz = vp.get_visible_rect().size
	var w := clampf(sz.x * SIMPLEHUD_MENU_WIDTH_FRAC, SIMPLEHUD_MENU_MIN_WIDTH, SIMPLEHUD_MENU_MAX_WIDTH)
	if content_min_width > 0.0:
		## Margins (32) + scrollbar / rounding so the dark card is at least as wide as the row labels + controls.
		w = clampf(
			maxf(w, content_min_width + 40.0),
			SIMPLEHUD_MENU_MIN_WIDTH,
			SIMPLEHUD_MENU_MAX_WIDTH,
		)
	var h := clampf(sz.y * SIMPLEHUD_MENU_HEIGHT_FRAC, SIMPLEHUD_MENU_MIN_HEIGHT, SIMPLEHUD_MENU_MAX_HEIGHT)
	var hw := w * 0.5
	var hh := h * 0.5
	inner.set_anchors_preset(Control.PRESET_CENTER)
	inner.offset_left = -hw
	inner.offset_right = hw
	inner.offset_top = -hh
	inner.offset_bottom = hh


## Game build uses `call_deferred(StringName, ...)` only — Callable form is a parse error on some exports.
func _deferred_relayout_simplehud_menu_inner() -> void:
	var sc := _simplehud_main_menu_scene
	if sc == null:
		return
	var vb: Variant = sc.get_meta(&"_simplehud_settings_vbox", null)
	if vb == null || !is_instance_valid(vb) || !(vb is VBoxContainer):
		return
	if !is_instance_valid(_simplehud_menu_inner):
		return
	var mw := (vb as VBoxContainer).get_combined_minimum_size().x
	_layout_simplehud_menu_inner(_simplehud_menu_inner, mw)


## Called by Return, Escape (`ui_cancel`), and clicking the dim backdrop.
func close_simplehud_menu_panel() -> void:
	var panel: Control = _simplehud_main_menu_panel_layer
	if panel != null && is_instance_valid(panel):
		panel.hide()
	var menu_root: Control = _simplehud_main_menu_scene
	if menu_root != null && is_instance_valid(menu_root):
		var main_blk: Node = menu_root.get_node_or_null("Main")
		if main_blk != null:
			main_blk.show()
	if menu_root != null && menu_root.has_method(&"PlayClick"):
		menu_root.call(&"PlayClick")


func log_diag(msg: String) -> void:
	if SIMPLEHUD_DIAG_LOG:
		print("[SimpleHUD] ", msg)


func log_menu_panel_diag(msg: String) -> void:
	if !(SIMPLEHUD_DIAG_LOG && SIMPLEHUD_MENU_PANEL_DIAG):
		return
	print("[SimpleHUD][MenuPanel] ", msg)


func _menu_panel_control_line(tag: String, c: Control) -> void:
	if c == null || !is_instance_valid(c):
		log_menu_panel_diag("%s <null>" % tag)
		return
	var gr: Rect2 = c.get_global_rect()
	log_menu_panel_diag(
		"%s name=\"%s\" visible=%s in_tree=%s size=%s global_rect=[%s … %s] min_size=%s modulate=%s z=%s clip=%s mouse_filter=%s"
		% [
			tag,
			c.name,
			c.visible,
			c.is_visible_in_tree(),
			c.size,
			gr.position,
			gr.position + gr.size,
			c.custom_minimum_size,
			c.modulate,
			c.z_index,
			c.clip_contents,
			c.mouse_filter,
		]
	)


func _dump_simplehud_menu_panel_layout(stage: String) -> void:
	if !(SIMPLEHUD_DIAG_LOG && SIMPLEHUD_MENU_PANEL_DIAG):
		return
	var vp := get_viewport()
	var vp_sz: Vector2 = vp.get_visible_rect().size if vp != null else Vector2.ZERO
	log_menu_panel_diag("layout_dump stage=\"%s\" viewport_size=%s" % [stage, vp_sz])
	var panel: Control = _simplehud_main_menu_panel_layer
	if panel == null || !is_instance_valid(panel):
		log_menu_panel_diag("layout_dump: _simplehud_main_menu_panel_layer invalid")
		return
	_menu_panel_control_line("  panel", panel)
	var inner := panel.get_node_or_null("SimpleHUDInner") as Control
	_menu_panel_control_line("  inner", inner)
	if inner != null:
		for i in inner.get_child_count():
			var ch: Node = inner.get_child(i)
			if ch is Control:
				_menu_panel_control_line("    inner[%d]" % i, ch as Control)
	var margin: MarginContainer = null
	if inner != null:
		for i in inner.get_child_count():
			var ich: Node = inner.get_child(i)
			if ich is MarginContainer:
				margin = ich as MarginContainer
				break
	var scroll: ScrollContainer = null
	if margin != null && margin.get_child_count() > 0:
		var mch: Node = margin.get_child(0)
		if mch is ScrollContainer:
			scroll = mch as ScrollContainer
	if scroll != null:
		log_menu_panel_diag(
			"  scroll follow_focus=%s h_mode=%s v_mode=%s child_count=%s"
			% [
				scroll.follow_focus,
				scroll.horizontal_scroll_mode,
				scroll.vertical_scroll_mode,
				scroll.get_child_count(),
			]
		)
		if scroll.get_child_count() > 0:
			var vbox: Control = scroll.get_child(0) as Control
			_menu_panel_control_line("  scroll→child[0] (vbox)", vbox)
			log_menu_panel_diag("  vbox children=%d" % vbox.get_child_count())
			if vbox.get_child_count() > 0:
				_menu_panel_control_line("    vbox[0]", vbox.get_child(0) as Control)
			if vbox.get_child_count() > 1:
				_menu_panel_control_line("    vbox[1]", vbox.get_child(1) as Control)
	else:
		log_menu_panel_diag("  scroll/margin chain missing (expected MarginContainer→ScrollContainer)")
	var dim: Control = panel.get_child(0) as Control if panel.get_child_count() > 0 else null
	if dim != null && str(dim.name) != "SimpleHUDInner":
		_menu_panel_control_line("  dim[0]", dim)
	log_menu_panel_diag("  panel node path: %s" % str(panel.get_path()))


func _menu_panel_open_diag_async() -> void:
	if !(SIMPLEHUD_DIAG_LOG && SIMPLEHUD_MENU_PANEL_DIAG):
		return
	## Two frames after open so Controls have had a chance to layout.
	await get_tree().process_frame
	_dump_simplehud_menu_panel_layout("open+1frame")
	await get_tree().process_frame
	_dump_simplehud_menu_panel_layout("open+2frame")


func _game_data_menu_open(gd: Resource) -> bool:
	if gd == null || !is_instance_valid(gd):
		return false
	var v: Variant = gd.get("menu")
	if v == null:
		return false
	return bool(v)


## Injects a "SimpleHUD" `res://Scenes/Menu.tscn` — `Main/Buttons` (sibling to "New", "Load game", …) and a full-screen settings layer. See `Auxillary/References/.../Scripts/Menu.gd` + `Scenes/Menu.tscn`.
func _try_install_simplehud_main_menu() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var sc: Node = tree.current_scene
	if sc == null or str(sc.name) != "Menu":
		return
	if sc.get_meta("_simplehud_main_menu_installed", false):
		return
	var buttons: Node = sc.get_node_or_null("Main/Buttons")
	if buttons == null:
		return
	var quit_btn: Node = buttons.get_node_or_null("Quit")
	var insert_idx: int = quit_btn.get_index() if quit_btn != null else buttons.get_child_count()
	var simple_btn := Button.new()
	simple_btn.name = "SimpleHUD"
	simple_btn.text = "SimpleHUD"
	simple_btn.custom_minimum_size = Vector2(0, 40)
	simple_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(simple_btn)
	buttons.move_child(simple_btn, insert_idx)
	var panel := Control.new()
	panel.name = "SimpleHUDPanel"
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 100
	sc.add_child(panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(dim)
	dim.gui_input.connect(
		func (ev: InputEvent) -> void:
			if ev is InputEventMouseButton && ev.pressed && ev.button_index == MOUSE_BUTTON_LEFT:
				close_simplehud_menu_panel()
	)
	var inner := Control.new()
	inner.name = "SimpleHUDInner"
	inner.mouse_filter = Control.MOUSE_FILTER_STOP
	inner.clip_contents = true
	inner.set_anchors_preset(Control.PRESET_CENTER)
	_simplehud_menu_inner = inner
	_layout_simplehud_menu_inner(inner)
	panel.add_child(inner)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.08, 0.08, 0.95)
	inner.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	inner.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	margin.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	var panel_ui = SimpleHUDSettingsPanelScript.new(sc as Control, panel)
	_simplehud_main_menu_scene = sc as Control
	_simplehud_main_menu_panel_layer = panel
	panel_ui.build(vbox)
	call_deferred("_deferred_relayout_simplehud_menu_inner")
	var vp_resize: Viewport = sc.get_viewport()
	if vp_resize != null && !bool(sc.get_meta(&"_simplehud_menu_vp_resize_connected", false)):
		sc.set_meta(&"_simplehud_menu_vp_resize_connected", true)
		vp_resize.size_changed.connect(
			func () -> void:
				var mw := -1.0
				var vb: Variant = sc.get_meta(&"_simplehud_settings_vbox", null)
				if vb is VBoxContainer && is_instance_valid(vb):
					mw = (vb as VBoxContainer).get_combined_minimum_size().x
				_layout_simplehud_menu_inner(_simplehud_menu_inner, mw)
		)
	if SIMPLEHUD_DIAG_LOG && SIMPLEHUD_MENU_PANEL_DIAG:
		log_menu_panel_diag(
			"installed: menu_scene=%s panel_index_in_scene=%s vbox_children=%s"
			% [str(sc.name), panel.get_index(), vbox.get_child_count()]
		)
		_dump_simplehud_menu_panel_layout("install_immediate")
	sc.set_meta(&"_simplehud_main_menu_installed", true)
	sc.set_meta(&"_simplehud_panel_controller", panel_ui)
	sc.set_meta(&"_simplehud_settings_vbox", vbox)
	simple_btn.pressed.connect(
		func () -> void:
			if sc.has_method(&"PlayClick"):
				sc.call(&"PlayClick")
			_layout_simplehud_menu_inner(_simplehud_menu_inner)
			call_deferred("_deferred_relayout_simplehud_menu_inner")
			panel.show()
			var main_blk: Node = sc.get_node_or_null("Main")
			if main_blk != null:
				main_blk.hide()
			if panel_ui.has_method(&"on_menu_opened"):
				panel_ui.call(&"on_menu_opened")
			elif panel_ui.has_method(&"sync_from_main"):
				panel_ui.call(&"sync_from_main")
			log_menu_panel_diag("button pressed: panel.visible=%s" % panel.visible)
			if SIMPLEHUD_DIAG_LOG && SIMPLEHUD_MENU_PANEL_DIAG:
				_menu_panel_open_diag_async()
	)
	log_diag("Main menu (Menu.tscn): SimpleHUD button + panel installed.")


func get_status_tray_settings_for_ui() -> Dictionary:
	return {
		"auto_hide": bool(_cfg.status_auto_hide_when_none),
		"fill_empty_space": bool(_cfg.status_fill_empty_space),
		"anchor": str(_cfg.status_anchor),
		"padding_px": float(_cfg.status_padding_px),
		"spacing_px": float(_cfg.status_spacing_px),
		"scale_pct": float(_cfg.status_scale_pct),
		"inactive_alpha_pct": clampf(float(_cfg.status_inactive_alpha), 0.0, 1.0) * 100.0,
		"mode": str(_cfg.status_mode),
		"stack_direction": str(_cfg.status_stack_direction),
		"strip_alignment": str(_cfg.status_strip_alignment),
		"r": int(_cfg.status_color_r),
		"g": int(_cfg.status_color_g),
		"b": int(_cfg.status_color_b),
		"inactive_r": int(_cfg.status_inactive_r),
		"inactive_g": int(_cfg.status_inactive_g),
		"inactive_b": int(_cfg.status_inactive_b),
	}


func apply_status_tray_settings_from_ui(
	auto_hide_empty_tray: bool,
	fill_empty_space: bool,
	anchor_key: String,
	padding_px: float,
	spacing_px: float,
	scale_pct: float,
	inactive_alpha_pct: float,
	r: int,
	g: int,
	b: int,
	strip_align_key: String,
	inactive_r: int,
	inactive_g: int,
	inactive_b: int,
) -> void:
	_cfg.status_auto_hide_when_none = auto_hide_empty_tray
	_cfg.status_fill_empty_space = fill_empty_space
	if auto_hide_empty_tray:
		_cfg.status_mode = "inflicted_only"
	else:
		_cfg.status_mode = "always"
	var ax := UserPreferencesScript.normalize_anchor(anchor_key)
	_cfg.status_anchor = ax
	## Top/Bottom tray = horizontal row; Left/Right = vertical column (no separate “stack mode” control).
	match ax:
		"left", "right":
			_cfg.status_stack_direction = "vertical_up"
		_:
			_cfg.status_stack_direction = "horizontal_left"
	_cfg.status_padding_px = clampf(padding_px, 0.0, 512.0)
	_cfg.status_spacing_px = clampf(spacing_px, 0.0, 64.0)
	_cfg.status_scale_pct = clampf(scale_pct, 25.0, 400.0)
	_cfg.status_inactive_alpha = clampf(float(inactive_alpha_pct) / 100.0, 0.0, 1.0)
	_cfg.status_color_r = clampi(r, 0, 255)
	_cfg.status_color_g = clampi(g, 0, 255)
	_cfg.status_color_b = clampi(b, 0, 255)
	_cfg.status_inactive_r = clampi(inactive_r, 0, 255)
	_cfg.status_inactive_g = clampi(inactive_g, 0, 255)
	_cfg.status_inactive_b = clampi(inactive_b, 0, 255)
	_cfg.status_strip_alignment = UserPreferencesScript.normalize_status_strip_alignment(strip_align_key)
	UserPreferencesScript.persist_preferences_json(_cfg)
	log_diag(
		"Status tray: mode=%s stack=%s align=%s auto_hide_empty=%s inactive_alpha=%.0f%% active_rgb=(%d,%d,%d) inactive_rgb=(%d,%d,%d)"
		% [
			_cfg.status_mode,
			_cfg.status_stack_direction,
			_cfg.status_strip_alignment,
			auto_hide_empty_tray,
			inactive_alpha_pct,
			r,
			g,
			b,
			inactive_r,
			inactive_g,
			inactive_b,
		]
	)
	refresh_hud_layout()


func get_vitals_strip_settings_for_ui() -> Dictionary:
	return {
		"spacing_px": float(_cfg.vitals_spacing_default_px),
		"strip_alignment": str(_cfg.vitals_strip_alignment),
		"fill_empty_space": bool(_cfg.vitals_fill_empty_space),
		"vitals_transparency_mode": _cfg.get_vitals_transparency_mode(),
		"vitals_static_opacity_pct": clampf(float(_cfg.vitals_static_opacity), 0.0, 1.0) * 100.0,
	}


func apply_vitals_transparency_from_ui(mode_key: String, static_opacity_pct: float) -> void:
	match mode_key:
		"opaque":
			_cfg.vitals_transparency_mode = "opaque"
			_cfg.min_stat_alpha_floor = 1.0
		"static":
			_cfg.vitals_transparency_mode = "static"
			_cfg.min_stat_alpha_floor = 0.0
			_cfg.vitals_static_opacity = clampf(static_opacity_pct / 100.0, 0.01, 1.0)
		_:
			_cfg.vitals_transparency_mode = "dynamic"
			_cfg.min_stat_alpha_floor = 0.0
	UserPreferencesScript.persist_preferences_json(_cfg)
	log_diag(
		"vitals transparency mode=%s static_opacity=%.2f floor=%.2f"
		% [_cfg.get_vitals_transparency_mode(), _cfg.vitals_static_opacity, _cfg.min_stat_alpha_floor]
	)
	refresh_hud_layout()


func apply_vitals_strip_settings_from_ui(
	spacing_px: float,
	strip_alignment_key: String = "",
	fill_empty_space: bool = false,
) -> void:
	_cfg.vitals_spacing_default_px = clampf(spacing_px, 0.0, 256.0)
	if strip_alignment_key != "":
		_cfg.vitals_strip_alignment = UserPreferencesScript.normalize_strip_alignment(strip_alignment_key)
	_cfg.vitals_fill_empty_space = fill_empty_space
	UserPreferencesScript.persist_preferences_json(_cfg)
	refresh_hud_layout()


func get_simplehud_active_preset_id() -> String:
	if _cfg == null:
		return ""
	return str(_cfg.get_meta(&"simplehud_active_preset", ""))


func _stable_json(value: Variant) -> String:
	return JSON.stringify(value, "", true)


func _cfg_signature(cfg: RefCounted) -> Dictionary:
	var vitals: Dictionary = {}
	for sid in SimpleHUDConfigScript.STAT_IDS:
		var grad: Dictionary = {}
		if cfg.stat_gradient_overrides.has(sid):
			var gv: Variant = cfg.stat_gradient_overrides[sid]
			if gv is Dictionary:
				grad = (gv as Dictionary).duplicate(true)
		vitals[String(sid)] = {
			"radial": bool(cfg.radial.get(sid, true)),
			"anchor": str(cfg.get_vitals_anchor(sid)),
			"padding_px": float(cfg.get_vitals_padding_px(sid)),
			"spacing_px": float(cfg.get_spacing_after_stat(sid)),
			"scale_pct": float(cfg.get_vitals_scale_pct(sid)),
			"visible_threshold_pct": float(cfg.get_threshold(sid)),
			"gradient": grad,
		}
	return {
		"general": {
			"numeric_only": bool(cfg.numeric_only),
			"min_stat_alpha_floor": float(cfg.min_stat_alpha_floor),
			"vitals_transparency_mode": str(cfg.get_vitals_transparency_mode()),
			"vitals_static_opacity": float(cfg.vitals_static_opacity),
			"stamina_fatigue_near_zero_cutoff": float(cfg.stamina_fatigue_near_zero_cutoff),
		},
		"vitals_layout": {
			"spacing_px": float(cfg.vitals_spacing_default_px),
			"strip_alignment": str(cfg.vitals_strip_alignment),
			"fill_empty_space": bool(cfg.vitals_fill_empty_space),
		},
		"vitals": vitals,
		"status": {
			"mode": str(cfg.status_mode),
			"anchor": str(cfg.status_anchor),
			"padding_px": float(cfg.status_padding_px),
			"spacing_px": float(cfg.status_spacing_px),
			"scale_pct": float(cfg.status_scale_pct),
			"strip_alignment": str(cfg.status_strip_alignment),
			"stack_direction": str(cfg.status_stack_direction),
			"inactive_alpha": float(cfg.status_inactive_alpha),
			"auto_hide_when_none": bool(cfg.status_auto_hide_when_none),
			"fill_empty_space": bool(cfg.status_fill_empty_space),
			"rgb": [int(cfg.status_color_r), int(cfg.status_color_g), int(cfg.status_color_b)],
			"inactive_rgb": [int(cfg.status_inactive_r), int(cfg.status_inactive_g), int(cfg.status_inactive_b)],
		},
		"stat_text_colors": {
			"mode": str(cfg.stat_text_color_mode),
			"high_start_pct": float(cfg.stat_text_high_start_pct),
			"mid_pct": float(cfg.stat_text_mid_pct),
			"high_rgb": [int(cfg.stat_text_high_r), int(cfg.stat_text_high_g), int(cfg.stat_text_high_b)],
			"mid_rgb": [int(cfg.stat_text_mid_r), int(cfg.stat_text_mid_g), int(cfg.stat_text_mid_b)],
			"low_rgb": [int(cfg.stat_text_low_r), int(cfg.stat_text_low_g), int(cfg.stat_text_low_b)],
		},
	}


func get_simplehud_current_preset_state_for_ui() -> Dictionary:
	if _cfg == null:
		return {"id": "", "label": "User Customized", "matched": false}
	var cur_sig := _stable_json(_cfg_signature(_cfg))
	for d in SimpleHUDPresetsReg.PRESETS:
		var pid := str(d.get("id", ""))
		var ppath := str(d.get("script", ""))
		if pid == "" || ppath == "":
			continue
		var scr: GDScript = load(ppath) as GDScript
		if scr == null:
			continue
		var nu: RefCounted = scr.new() as RefCounted
		if nu == null || !(nu as Object).has_method(&"apply_full_preset_defaults"):
			continue
		(nu as RefCounted).call(&"apply_full_preset_defaults")
		if _stable_json(_cfg_signature(nu)) == cur_sig:
			return {"id": pid, "label": str(d.get("label", pid)), "matched": true}
	return {"id": "", "label": "User Customized", "matched": false}


func get_simplehud_preset_dropdown_index_for_active() -> int:
	var st := get_simplehud_current_preset_state_for_ui()
	var id := str(st.get("id", ""))
	if id == "":
		return 0
	for i in range(SimpleHUDPresetsReg.PRESETS.size()):
		if str(SimpleHUDPresetsReg.PRESETS[i].get("id", "")) == id:
			return i + 1
	return 0


func get_simplehud_preset_id_at_dropdown_index(idx: int) -> String:
	if idx <= 0:
		return ""
	var list: Array = SimpleHUDPresetsReg.PRESETS
	var j := idx - 1
	if j < 0 || j >= list.size():
		return ""
	return str(list[j].get("id", ""))


func apply_simplehud_preset(preset_id: String) -> bool:
	var path := ""
	for d in SimpleHUDPresetsReg.PRESETS:
		if str(d.get("id", "")) == preset_id:
			path = str(d.get("script", ""))
			break
	if path == "":
		log_diag("apply_simplehud_preset: unknown preset id %s" % preset_id)
		return false
	var scr: GDScript = load(path) as GDScript
	if scr == null:
		push_warning("SimpleHUD: could not load preset script %s" % path)
		return false
	var nu: RefCounted = scr.new() as RefCounted
	if nu == null || !(nu as Object).has_method(&"apply_full_preset_defaults"):
		push_warning("SimpleHUD: preset script missing apply_full_preset_defaults: %s" % path)
		return false
	(nu as RefCounted).call(&"apply_full_preset_defaults")
	_cfg = nu
	_cfg.set_meta(&"simplehud_active_preset", preset_id)
	## Skipping merge_into(): saved preferences would overwrite the preset; persist this as the new baseline instead.
	UserPreferencesScript.persist_preferences_json(_cfg)
	if is_instance_valid(_overlay):
		_overlay.apply_live_config(_cfg)
	log_diag("Applied SimpleHUD preset id=%s" % preset_id)
	refresh_hud_layout()
	return true


func get_stat_settings_for_ui(stat_id: StringName) -> Dictionary:
	var gradient_mode := "preset"
	var grad_copy: Dictionary = {}
	if _cfg.stat_gradient_overrides.has(stat_id):
		var gv: Variant = _cfg.stat_gradient_overrides[stat_id]
		if gv is Dictionary:
			grad_copy = (gv as Dictionary).duplicate(true)
			var gm := str(grad_copy.get("mode", "gradient")).to_lower()
			if gm == "white_only" || gm == "white":
				gradient_mode = "white"
			else:
				gradient_mode = "custom"
	return {
		"radial": bool(_cfg.radial.get(stat_id, true)),
		"anchor": _cfg.get_vitals_anchor(stat_id),
		"padding_px": float(_cfg.get_vitals_padding_px(stat_id)),
		"spacing_px": float(_cfg.get_spacing_after_stat(stat_id)),
		"scale_pct": float(_cfg.get_vitals_scale_pct(stat_id)),
		"visible_threshold_pct": float(_cfg.get_threshold(stat_id)),
		"numeric_only_global": bool(_cfg.numeric_only),
		"gradient_mode": gradient_mode,
		"gradient": grad_copy,
	}


func get_vitals_common_settings_for_ui() -> Dictionary:
	var d := get_stat_settings_for_ui(SimpleHUDConfigScript.STAT_HEALTH)
	var min_t := 101.0
	var all_same := true
	var first_t := 0.0
	var first := true
	for sid in SimpleHUDConfigScript.STAT_IDS:
		var t := float(_cfg.get_threshold(sid))
		min_t = minf(min_t, t)
		if first:
			first_t = t
			first = false
		elif !is_equal_approx(t, first_t):
			all_same = false
	# Surface the strictest per-stat threshold so mixed legacy values are visible in UI.
	d["visible_threshold_pct"] = min_t
	d["thresholds_uniform"] = all_same
	return d


func _apply_stat_dict_to_cfg(sid: StringName, stat_dict: Dictionary) -> void:
	if stat_dict.has("radial"):
		_cfg.radial[sid] = bool(stat_dict["radial"])
	if stat_dict.has("anchor"):
		_cfg.vitals_anchor[sid] = UserPreferencesScript.normalize_anchor(str(stat_dict["anchor"]))
	if stat_dict.has("padding_px"):
		_cfg.vitals_padding_px[sid] = clampf(float(stat_dict["padding_px"]), 0.0, 512.0)
	if stat_dict.has("spacing_px"):
		_cfg.vitals_spacing_px[sid] = clampf(float(stat_dict["spacing_px"]), 0.0, 256.0)
	if stat_dict.has("scale_pct"):
		_cfg.vitals_scale_pct[sid] = clampf(float(stat_dict["scale_pct"]), 25.0, 400.0)
	if stat_dict.has("visible_threshold_pct"):
		_cfg.visible_threshold[sid] = float(stat_dict["visible_threshold_pct"])
	if stat_dict.has("gradient_mode"):
		match String(stat_dict["gradient_mode"]):
			"preset":
				_cfg.stat_gradient_overrides.erase(sid)
			"white":
				_cfg.stat_gradient_overrides[sid] = {"mode": "white_only"}
			"custom":
				var gv: Variant = stat_dict.get("gradient", {})
				if gv is Dictionary:
					_cfg.stat_gradient_overrides[sid] = (gv as Dictionary).duplicate(true)


func _maybe_disable_numeric_only_for_radial(stat_dict: Dictionary) -> void:
	if bool(stat_dict.get("radial", false)) && _cfg.numeric_only:
		_cfg.numeric_only = false
		log_diag(
			"general.numeric_only was true (e.g. TextNumeric preset); cleared so radial vitals can render."
		)


func apply_stat_settings_to_all_from_ui(stat_dict: Dictionary) -> void:
	for sid in SimpleHUDConfigScript.STAT_IDS:
		_apply_stat_dict_to_cfg(sid, stat_dict.duplicate(true))
	_maybe_disable_numeric_only_for_radial(stat_dict)
	UserPreferencesScript.persist_preferences_json(_cfg)
	log_diag(
		"Batch vitals: numeric_only=%s sample get_radial(health)=%s"
		% [_cfg.numeric_only, _cfg.get_radial(SimpleHUDConfigScript.STAT_HEALTH)]
	)
	refresh_hud_layout()


func refresh_hud_layout() -> void:
	## Run next frame so OptionButton/SpinBox/etc. have committed values and GameData refs are stable.
	call_deferred("_refresh_hud_layout_impl")


func _refresh_hud_layout_impl() -> void:
	if !is_instance_valid(_overlay):
		if !_logged_overlay_missing_refresh:
			log_diag("_refresh_hud_layout_impl: overlay not bound yet (settings saved; applies when HUD loads).")
			_logged_overlay_missing_refresh = true
		return
	_logged_overlay_missing_refresh = false
	var hud: Control = _resolve_hud()
	var prefs := _load_preferences(false)
	var vitals_on: bool = _prefs_bool(prefs, &"vitals", true)
	var medical_on: bool = _prefs_bool(prefs, &"medical", true)
	_overlay.configure_hud_prefs(vitals_on, medical_on)
	if hud != null:
		_sync_vanilla_hud_overrides(hud, vitals_on, medical_on)
	var live := _resolve_live_game_data(hud)
	if live != null && is_instance_valid(live):
		_overlay.set_live_game_data(live)
	else:
		_overlay.set_live_game_data(game_data)
	var gd_menu: Resource = live if live != null && is_instance_valid(live) else game_data
	var menu_hide := _game_data_menu_open(gd_menu)
	var show_layer: bool = !menu_hide
	_overlay.tick(0.0, true)
	_overlay.notify_config_changed()
	var vp_sz: Vector2 = (
		get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(1920, 1080)
	)
	_overlay.layout_for_viewport(vp_sz, show_layer)


func _process(delta: float) -> void:
	var frame := Engine.get_process_frames()
	if frame >= _next_menu_install_probe_frame:
		_next_menu_install_probe_frame = frame + _MENU_INSTALL_PROBE_INTERVAL_FRAMES
		_try_install_simplehud_main_menu()
	if !_cfg.enabled:
		_clear_binding(true)
		return

	var hud: Control = _resolve_hud()
	if hud == null:
		_clear_binding()
		return

	if _hud == hud && is_instance_valid(_overlay):
		_apply_overlay(hud, delta)
		return

	_bind_hud(hud)


func _bind_hud(hud: Control) -> void:
	_clear_binding()
	_hud = hud

	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "SimpleHUDCanvas"
	_canvas_layer.layer = 128
	_canvas_layer.follow_viewport_enabled = true
	get_tree().root.add_child(_canvas_layer)

	_overlay = SimpleHudOverlay.new()
	_overlay.setup(game_data, _cfg)
	_overlay.visible = true
	_canvas_layer.add_child(_overlay)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_info_node = null

	_apply_overlay(hud, 0.0)


func _apply_overlay(hud: Control, delta: float) -> void:
	if !is_instance_valid(_overlay):
		return

	var prefs := _load_preferences(false)

	var vitals_on: bool = _prefs_bool(prefs, &"vitals", true)
	var medical_on: bool = _prefs_bool(prefs, &"medical", true)

	_overlay.configure_hud_prefs(vitals_on, medical_on)

	_sync_vanilla_hud_overrides(hud, vitals_on, medical_on)

	var live := _resolve_live_game_data(hud)
	if live != null && is_instance_valid(live):
		_overlay.set_live_game_data(live)
	else:
		_overlay.set_live_game_data(game_data)

	var gd_menu: Resource = live if live != null && is_instance_valid(live) else game_data
	var menu_hide := _game_data_menu_open(gd_menu)

	# Drive our vitals strip only from pause/menu — not from HUD/Stats.visible. The game may hide the
	# Stats node while gameplay values are still meaningful; tying show_layer to it skipped tick()
	# and left the overlay blank (no updates, widgets never filled in).
	var show_layer: bool = !menu_hide

	if show_layer:
		_overlay.tick(delta)

	var vp_sz: Vector2 = (
		get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(1920, 1080)
	)
	_overlay.layout_for_viewport(vp_sz, show_layer)

	_apply_fps_map(hud, prefs)


## Escape menu / Settings toggles (Preferences.tres). When true, we hide vanilla rows and draw replacements.
func _sync_vanilla_hud_overrides(hud: Control, vitals_on: bool, medical_on: bool) -> void:
	var vn := hud.get_node_or_null("Stats/Vitals") as Control
	if vn != null && vitals_on:
		vn.visible = false

	var mn := hud.get_node_or_null("Stats/Medical") as Control
	if mn != null && medical_on:
		mn.visible = false


func _load_preferences(force_refresh: bool = false) -> Resource:
	var frame := Engine.get_process_frames()
	var expired := frame - _prefs_cache_frame >= _PREFS_CACHE_TTL_FRAMES
	if force_refresh || _prefs_cache == null || !is_instance_valid(_prefs_cache) || expired:
		_prefs_cache = load("user://Preferences.tres") as Resource
		_prefs_cache_frame = frame
	return _prefs_cache


func _prefs_bool(prefs: Resource, key: StringName, fallback: bool) -> bool:
	if prefs == null:
		return fallback
	var v: Variant = prefs.get(key)
	if v == null:
		return fallback
	return bool(v)


## Targets HUD/Info (same nodes Settings → HUD.ShowMap / ShowFPS affect). Visibility is driven by vanilla + prefs.map / prefs.FPS.
func _apply_fps_map(hud: Control, prefs: Resource) -> void:
	var info := hud.get_node_or_null("Info") as Control
	if info == null:
		return

	_ensure_fps_label_style(info)
	info.scale = Vector2(_cfg.fps_map_scale, _cfg.fps_map_scale)
	info.position = Vector2(_cfg.fps_map_offset_x, _cfg.fps_map_offset_y)
	var a: float = clampf(float(_cfg.fps_map_alpha), 0.0, 1.0)
	info.modulate = Color(1.0, 1.0, 1.0, a)

func _ensure_fps_label_style(info: Control) -> void:
	if info == null:
		return
	if _fps_info_node == info:
		return
	_fps_info_node = info
	# Keep only the numeric FPS readout and force it white for readability.
	var fps_label := info.get_node_or_null("FPS") as Label
	if fps_label != null:
		var fps_text := fps_label.text.strip_edges()
		if fps_text.begins_with("FPS"):
			fps_text = fps_text.trim_prefix("FPS")
			if fps_text.begins_with(":"):
				fps_text = fps_text.trim_prefix(":")
			fps_text = fps_text.strip_edges()
		fps_label.text = fps_text
		fps_label.add_theme_color_override("font_color", Color.WHITE)

	var fps_value := info.get_node_or_null("FPS/Frames") as Label
	if fps_value != null:
		var val_text := fps_value.text.strip_edges()
		if val_text.begins_with("FPS"):
			val_text = val_text.trim_prefix("FPS")
			if val_text.begins_with(":"):
				val_text = val_text.trim_prefix(":")
			val_text = val_text.strip_edges()
		fps_value.text = val_text
		fps_value.add_theme_color_override("font_color", Color.WHITE)
		fps_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Vanilla scene offsets Frames by +36 to clear "FPS:"; collapse that gap.
		fps_value.offset_left = 0.0
		fps_value.offset_right = 40.0


func _clear_binding(restore_vanilla: bool = false) -> void:
	var bound_hud := _hud
	if is_instance_valid(_canvas_layer):
		_canvas_layer.queue_free()
	elif is_instance_valid(_overlay):
		_overlay.queue_free()
	_canvas_layer = null
	_overlay = null
	_fps_info_node = null
	if restore_vanilla && is_instance_valid(bound_hud):
		_restore_vanilla_hud_visibility(bound_hud)
	_hud = null
	_live_game_data = null


func _restore_vanilla_hud_visibility(hud: Control) -> void:
	if hud == null || !is_instance_valid(hud):
		return
	var prefs := _load_preferences(true)
	var vitals_on: bool = _prefs_bool(prefs, &"vitals", true)
	var medical_on: bool = _prefs_bool(prefs, &"medical", true)
	var vn := hud.get_node_or_null("Stats/Vitals") as Control
	if vn != null:
		vn.visible = vitals_on
	var mn := hud.get_node_or_null("Stats/Medical") as Control
	if mn != null:
		mn.visible = medical_on


func _resolve_live_game_data(for_hud: Control) -> Resource:
	if _live_game_data != null && is_instance_valid(_live_game_data):
		return _live_game_data

	var f := Engine.get_process_frames()
	if for_hud == null && f >= 180 && f % 60 != 0:
		return game_data

	var found: Resource = null

	if for_hud != null:
		for kn in ["game_data", "gameData", "GameData", "data", "playerData", "player_data", "state"]:
			var v: Variant = for_hud.get(kn)
			if v is Resource && _resource_is_game_data(v as Resource):
				found = v as Resource
				break
		if found == null:
			found = _extract_game_data_from_object(for_hud)
		if found == null:
			found = _scan_parents_for_game_data(for_hud)
		if found == null:
			found = _scan_node_for_game_data(for_hud, 0, 14)

	var tree := get_tree()
	if tree == null:
		return game_data

	if found == null:
		var root := tree.root
		for nm in [&"GameData", &"game_data", &"Game", &"World", &"UI", &"UIManager", &"Interface"]:
			var qn := root.get_node_or_null(NodePath(str(nm)))
			if qn != null:
				found = _extract_game_data_from_object(qn)
				if found != null:
					break

	if found == null:
		found = _scan_tree_for_game_data(tree.current_scene)
	if found == null:
		found = _scan_tree_for_game_data(tree.root)

	if found != null && _resource_is_game_data(found):
		_live_game_data = found
		return _live_game_data

	return game_data


func _scan_parents_for_game_data(hud: Control) -> Resource:
	var n: Node = hud.get_parent()
	var depth := 0
	while n != null && depth < 32:
		var r := _extract_game_data_from_object(n)
		if r != null:
			return r
		for kn in ["game_data", "gameData", "GameData", "data", "playerData", "player_state"]:
			var v: Variant = n.get(kn)
			if v is Resource && _resource_is_game_data(v as Resource):
				return v as Resource
		n = n.get_parent()
		depth += 1
	return null


func _scan_tree_for_game_data(from: Node) -> Resource:
	if from == null:
		return null
	return _scan_node_for_game_data(from, 0, 24)


func _scan_node_for_game_data(n: Node, depth: int, max_depth: int) -> Resource:
	if depth > max_depth:
		return null
	var r := _extract_game_data_from_object(n)
	if r != null:
		return r
	for c in n.get_children():
		var rr := _scan_node_for_game_data(c, depth + 1, max_depth)
		if rr != null:
			return rr
	return null


func _extract_game_data_from_object(o: Object) -> Resource:
	if o is Resource && _resource_is_game_data(o as Resource):
		return o as Resource
	if o is Node:
		var node := o as Node
		for pi in node.get_property_list():
			if pi is not Dictionary:
				continue
			var key := String(pi.get("name", ""))
			if key.is_empty():
				continue
			var v: Variant = node.get(key)
			if v is Resource:
				var res := v as Resource
				if _resource_is_game_data(res):
					return res
	return null


func _resource_is_game_data(res: Resource) -> bool:
	var has_h := false
	var has_hy := false
	for p in res.get_property_list():
		match String(p.name):
			"health":
				has_h = true
			"hydration":
				has_hy = true
			_:
				pass
	return has_h && has_hy


func _resolve_hud() -> Control:
	var tree := get_tree()
	var r := tree.root
	var cs := tree.current_scene

	if cs != null:
		var abs_hud := cs.get_node_or_null("/root/Map/Core/UI/HUD") as Control
		if abs_hud != null:
			return abs_hud
		var core_hud := cs.get_node_or_null("Core/UI/HUD") as Control
		if core_hud != null:
			return core_hud
		var map_hud := cs.get_node_or_null("Map/Core/UI/HUD") as Control
		if map_hud != null:
			return map_hud

	var rel := r.get_node_or_null("Map/Core/UI/HUD") as Control
	if rel != null:
		return rel

	return _find_hud_control(r)


func _find_hud_control(from: Node) -> Control:
	for n in from.get_children():
		var h := _find_hud_control(n)
		if h != null:
			return h
	if from is Control && str(from.name) == "HUD":
		var c := from as Control
		if c.has_node("Stats") && c.has_node("Info"):
			return c
	return null

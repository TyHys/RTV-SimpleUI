extends Node

## Native `Node` lifecycle + `super()` is a parse error in this game's GDScript build; omit `super()` here.

## Same pattern as BikeMod: path from scene tree root, not "/root/Map/..." (that breaks when resolved from root).
const SimpleHUDConfigScript := preload("res://SimpleHUD/Config.gd")
const SimpleHudOverlay := preload("res://SimpleHUD/HudOverlay.gd")
const UserPreferencesScript := preload("res://SimpleHUD/UserPreferences.gd")
const SimpleHUDSettingsPanelScript := preload("res://SimpleHUD/SimpleHUDSettingsPanel.gd")
const SimpleHUDPresetsReg := preload("res://SimpleHUD/PresetsRegistry.gd")
const _HUD_TEXT_FONT := preload("res://Fonts/Lora-Regular.ttf")
const _HUD_EXTRA_TEXT_FONT := preload("res://Fonts/Lora-SemiBold.ttf")
const _HUD_WEIGHT_ICON_PATHS := [
	"res://SimpleHUD/icons/weight_icon.png",
	"res://SimpleHUD/SimpleHUD/icons/weight_icon.png",
	"res://UI/Sprites/Icon_Overweight.png",
]

## Set true to enable verbose console diagnostics during development.
const SIMPLEHUD_DIAG_LOG := false
## Exhaustive FPS/Map diagnostics for runtime troubleshooting.
const SIMPLEHUD_FPSMAP_DIAG_LOG := false

## Verbose diagnostics for main-menu SimpleHUD overlay (sizes, visibility, deferred layout).
const SIMPLEHUD_MENU_PANEL_DIAG := false

var game_data: Resource = preload("res://Resources/GameData.tres")

var _cfg: RefCounted
var _hud: Control
var _overlay: SimpleHudOverlay

## Runtime `GameData` the game mutates (often not the same object identity as preload if the scene holds a live ref).
var _live_game_data: Resource = null
var _prefs_cache: Resource = null
## mtime of user://Preferences.tres at last successful load; -1 = never loaded.
var _prefs_cache_mtime: int = -1
## Frame at which we next check the mtime (rate-limits the stat() syscall to ~30 fps).
var _prefs_mtime_next_check_frame: int = 0
const _PREFS_MTIME_CHECK_INTERVAL_FRAMES := 30

var _logged_overlay_missing_refresh: bool = false
var _hud_force_hidden: bool = false
var _next_toggle_hud_bind_probe_frame: int = 0
const _TOGGLE_HUD_BIND_PROBE_INTERVAL_FRAMES := 90

## Main menu (`Menu.tscn`) SimpleHUD overlay; used to close on Escape and from Return.
var _simplehud_main_menu_scene: Control = null
var _simplehud_main_menu_panel_layer: Control = null
var _simplehud_menu_inner: Control = null
var _fps_info_node: Control = null
var _fps_hide_prefix_last: bool = true
var _map_label_mode_last: String = "default"
var _map_label_full_cache: String = ""
var _last_map_label_src_styled: String = ""
var _has_applied_map_label_style: bool = false
var _fps_map_cache_ok: bool = false
var _fps_map_cached_info: Control = null
var _fps_map_c_scale: float = 0.0
var _fps_map_c_ox: float = 0.0
var _fps_map_c_oy: float = 0.0
var _fps_map_c_alpha: float = -1.0
var _fps_map_extra_label: Label = null
var _fps_map_extra_weight_icon: TextureRect = null
var _fps_map_weight_icon_texture: Texture2D = null
var _fps_map_weight_icon_resolved: bool = false
var _fps_map_extra_show_weight_icon: bool = false
var _fps_map_prev_menu_open: bool = false
var _fps_map_prev_show_fps: bool = true
var _fps_map_prev_show_map: bool = true
var _fps_map_prev_iface_ok: bool = false
var _ui_interface_node: Node = null
var _ui_next_probe_frame: int = 0
const _UI_PROBE_INTERVAL_FRAMES := 30
var _fps_extra_next_update_frame: int = 0
const _FPS_EXTRA_UPDATE_INTERVAL_FRAMES := 15
var _fps_extra_last_text: String = ""
## Fixed pixel gap between the core Info block and the extra encumbrance/value lines.
const _FPS_MAP_EXTRA_SEP_PX := 4.0
const _FPS_MAP_ICON_GAP_PX := 2.0
const _FPS_MAP_ICON_SIDE_PX := 12.0

## Cached once the toggle_hud / show_all_vitals actions are confirmed registered.
var _toggle_hud_action_ready: bool = false
var _show_all_vitals_action_ready: bool = false
## Cached after binding to avoid get_node_or_null calls on every frame tick.
var _hud_vitals_node: Control = null
var _hud_medical_node: Control = null
var _hud_info_node: Control = null
var _hud_map_label: Label = null
## Cached after the first successful keybinding-UI tree scan — avoids full DFS every 90 frames once found.
var _binding_ui_node: Node = null
## Prevent repeated CreateActions() rebuilds from wiping custom binds.
var _binding_ui_actions_injected: bool = false

var _next_menu_install_probe_frame: int = 0
const _MENU_INSTALL_PROBE_INTERVAL_FRAMES := 30

## Menu card: was fixed 512×704 px so the dark fill was narrower than long label rows (~674 px). Size from viewport instead.
const SIMPLEHUD_MENU_WIDTH_FRAC := 0.52
const SIMPLEHUD_MENU_MIN_WIDTH := 700.0
const SIMPLEHUD_MENU_MAX_WIDTH := 980.0
const SIMPLEHUD_MENU_HEIGHT_FRAC := 0.72
const SIMPLEHUD_MENU_MIN_HEIGHT := 520.0
const SIMPLEHUD_MENU_MAX_HEIGHT := 920.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if !_uses_mcm_config_surface():
		_ensure_toggle_hud_action()
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


func log_fpsmap_diag(msg: String) -> void:
	if SIMPLEHUD_FPSMAP_DIAG_LOG:
		print("[SimpleHUD][FPSMAP] ", msg)


func _fpsmap_label_style_diag(lb: Label) -> String:
	if lb == null || !is_instance_valid(lb):
		return "<null>"
	var fnt: Font = lb.get_theme_font("font")
	var fsz: int = lb.get_theme_font_size("font_size")
	if fsz <= 0:
		fsz = 16
	var line_h := -1.0
	if fnt != null:
		line_h = fnt.get_height(fsz)
	return "name=%s vis=%s in_tree=%s pos=%s size=%s min=%s mod=%s font=%s fsz=%d line_h=%.2f text=\"%s\"" % [
		lb.name,
		lb.visible,
		lb.is_visible_in_tree(),
		lb.position,
		lb.size,
		lb.get_combined_minimum_size(),
		lb.modulate,
		"<null>" if fnt == null else str(fnt),
		fsz,
		line_h,
		lb.text,
	]


func _fpsmap_dump_cluster_snapshot(stage: String, info: Control, hud: Control, show_fps: bool, show_map: bool, ox: float, oy: float, sc: float, alpha: float) -> void:
	if !SIMPLEHUD_FPSMAP_DIAG_LOG:
		return
	if info == null || !is_instance_valid(info):
		log_fpsmap_diag("snapshot stage=%s info=<null>" % [stage])
		return
	var vp := get_viewport()
	var vp_size := vp.get_visible_rect().size if vp != null else Vector2.ZERO
	var core_sz := _fps_map_info_only_size(info)
	var visual_sz := _fps_map_cluster_visual_size(info)
	var info_gr := info.get_global_rect()
	var extra_gr := Rect2()
	if _fps_map_extra_label != null && is_instance_valid(_fps_map_extra_label):
		extra_gr = _fps_map_extra_label.get_global_rect()
	var icon_gr := Rect2()
	if _fps_map_extra_weight_icon != null && is_instance_valid(_fps_map_extra_weight_icon):
		icon_gr = _fps_map_extra_weight_icon.get_global_rect()
	log_fpsmap_diag(
		"snapshot stage=%s menu_open=%s show_fps=%s show_map=%s hud_ok=%s iface_ok=%s edge=%s align=%s cfg_off=(%.1f,%.1f) cfg_scale=%.3f cfg_alpha=%.3f vp=%s info_pos=%s info_scale=%s core_sz=%s visual_sz=%s info_gr=[%s..%s] extra_gr=[%s..%s] icon_gr=[%s..%s] extra_vis=%s icon_vis=%s extra_text=\"%s\""
		% [
			stage,
			_game_data_menu_open(_live_game_data),
			show_fps,
			show_map,
			hud != null && is_instance_valid(hud),
			_ui_interface_node != null && is_instance_valid(_ui_interface_node),
			_normalize_cluster_edge(str(_cfg.fps_map_cluster_justify)),
			_normalize_cluster_alignment(str(_cfg.fps_map_cluster_alignment)),
			ox,
			oy,
			sc,
			alpha,
			vp_size,
			info.position,
			info.scale,
			core_sz,
			visual_sz,
			info_gr.position,
			info_gr.position + info_gr.size,
			extra_gr.position,
			extra_gr.position + extra_gr.size,
			icon_gr.position,
			icon_gr.position + icon_gr.size,
			_fps_map_extra_label != null && is_instance_valid(_fps_map_extra_label) && _fps_map_extra_label.visible,
			_fps_map_extra_weight_icon != null && is_instance_valid(_fps_map_extra_weight_icon) && _fps_map_extra_weight_icon.visible,
			_fps_extra_last_text,
		]
	)


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
	return bool(gd.menu)


## Whether the SimpleHUD canvas should update/draw. Preloaded GameData may keep `menu=true`; live `menu` can be wrong — if the vanilla HUD node exists (see `_resolve_hud`), we are in gameplay and must show the overlay (compass, crosshair, tray).
func _show_simplehud_layer(gameplay_hud: Control = null) -> bool:
	if _hud_force_hidden:
		return false
	var tree := get_tree()
	if tree == null:
		return false
	var cs: Node = tree.current_scene
	if cs != null && str(cs.name) == "Menu":
		return false
	var hud_ctrl := gameplay_hud
	if hud_ctrl == null || !is_instance_valid(hud_ctrl):
		hud_ctrl = _resolve_hud()
	if hud_ctrl != null && is_instance_valid(hud_ctrl):
		return true
	if _live_game_data != null && is_instance_valid(_live_game_data):
		return !_game_data_menu_open(_live_game_data)
	if cs != null && str(cs.name) != "Menu":
		return true
	return !_game_data_menu_open(game_data)


## Layout/tick use the vanilla HUD control size when parented under `HUD` (matches game canvas); fall back to the viewport if not laid out yet.
func _overlay_layout_size_px(gameplay_hud: Control) -> Vector2:
	if gameplay_hud != null && is_instance_valid(gameplay_hud):
		var sz: Vector2 = gameplay_hud.size
		if sz.x > 1.0 && sz.y > 1.0:
			return sz
	return get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(1920, 1080)


## Injects a "SimpleHUD" `res://Scenes/Menu.tscn` — `Main/Buttons` (sibling to "New", "Load game", …) and a full-screen settings layer. See `Auxillary/References/.../Scripts/Menu.gd` + `Scenes/Menu.tscn`.
func _try_install_simplehud_main_menu() -> void:
	if Engine.has_meta(&"SimpleHUD_UsesMCM"):
		return
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


func get_misc_settings_for_ui() -> Dictionary:
	return {
		"compass_enabled": bool(_cfg.compass_enabled),
		"compass_anchor": str(_cfg.compass_anchor),
		"compass_alpha_pct": clampf(float(_cfg.compass_color_a), 0.0, 1.0) * 100.0,
		"compass_r": int(_cfg.compass_color_r),
		"compass_g": int(_cfg.compass_color_g),
		"compass_b": int(_cfg.compass_color_b),
		"crosshair_enabled": bool(_cfg.crosshair_enabled),
		"crosshair_alpha_pct": clampf(float(_cfg.crosshair_color_a), 0.0, 1.0) * 100.0,
		"crosshair_r": int(_cfg.crosshair_color_r),
		"crosshair_g": int(_cfg.crosshair_color_g),
		"crosshair_b": int(_cfg.crosshair_color_b),
		"crosshair_shape": str(_cfg.crosshair_shape),
		"crosshair_scale_pct": float(_cfg.crosshair_scale_pct),
		"crosshair_bloom_enabled": bool(_cfg.crosshair_bloom_enabled),
		"crosshair_hide_during_aiming": bool(_cfg.crosshair_hide_during_aiming),
		"crosshair_hide_while_stowed": bool(_cfg.crosshair_hide_while_stowed),
		"fps_hide_label_prefix": bool(_cfg.fps_hide_label_prefix),
		"map_label_mode": str(_cfg.map_label_mode),
		"vital_helmet_enabled": bool(_cfg.misc_vital_helmet_enabled),
		"vital_cat_enabled": bool(_cfg.misc_vital_cat_enabled),
		"vital_plate_enabled": bool(_cfg.misc_vital_plate_enabled),
		"show_encumbrance_pct": bool(_cfg.fps_map_show_encumbrance_pct),
		"show_inventory_value": bool(_cfg.fps_map_show_inventory_value),
		"fps_map_cluster_justify": str(_cfg.fps_map_cluster_justify),
		"fps_map_cluster_alignment": str(_cfg.fps_map_cluster_alignment),
	}


func apply_misc_settings_from_ui(
	compass_enabled: bool,
	compass_anchor: String,
	compass_alpha_pct: float,
	compass_r: int,
	compass_g: int,
	compass_b: int,
	crosshair_enabled: bool,
	crosshair_alpha_pct: float,
	crosshair_r: int,
	crosshair_g: int,
	crosshair_b: int,
	crosshair_shape: String,
	crosshair_scale_pct: float,
	crosshair_bloom_enabled: bool,
	crosshair_hide_during_aiming: bool,
	crosshair_hide_while_stowed: bool,
	fps_hide_label_prefix: bool,
	map_label_mode: String,
	vital_helmet_enabled: bool = false,
	vital_cat_enabled: bool = false,
	vital_plate_enabled: bool = false,
	show_encumbrance_pct: bool = false,
	show_inventory_value: bool = false,
	fps_map_cluster_justify: String = "top",
	fps_map_cluster_alignment: String = "leading",
) -> void:
	_cfg.compass_enabled = compass_enabled
	_cfg.compass_anchor = "bottom" if str(compass_anchor).to_lower() == "bottom" else "top"
	_cfg.compass_color_a = clampf(float(compass_alpha_pct) / 100.0, 0.0, 1.0)
	_cfg.compass_color_r = clampi(compass_r, 0, 255)
	_cfg.compass_color_g = clampi(compass_g, 0, 255)
	_cfg.compass_color_b = clampi(compass_b, 0, 255)
	_cfg.crosshair_enabled = crosshair_enabled
	_cfg.crosshair_color_a = clampf(float(crosshair_alpha_pct) / 100.0, 0.0, 1.0)
	_cfg.crosshair_color_r = clampi(crosshair_r, 0, 255)
	_cfg.crosshair_color_g = clampi(crosshair_g, 0, 255)
	_cfg.crosshair_color_b = clampi(crosshair_b, 0, 255)
	var sh := str(crosshair_shape).to_lower()
	_cfg.crosshair_shape = "dot" if sh == "dot" else "crosshair"
	_cfg.crosshair_scale_pct = clampf(crosshair_scale_pct, 25.0, 300.0)
	_cfg.crosshair_bloom_enabled = crosshair_bloom_enabled
	_cfg.crosshair_hide_during_aiming = crosshair_hide_during_aiming
	_cfg.crosshair_hide_while_stowed = crosshair_hide_while_stowed
	_cfg.fps_hide_label_prefix = fps_hide_label_prefix
	_cfg.misc_vital_helmet_enabled = vital_helmet_enabled
	_cfg.misc_vital_cat_enabled = vital_cat_enabled
	_cfg.misc_vital_plate_enabled = vital_plate_enabled
	_cfg.fps_map_show_encumbrance_pct = show_encumbrance_pct
	_cfg.fps_map_show_inventory_value = show_inventory_value
	_cfg.fps_map_cluster_justify = _normalize_cluster_edge(fps_map_cluster_justify)
	_cfg.fps_map_cluster_alignment = _normalize_cluster_alignment(fps_map_cluster_alignment)
	var mm := str(map_label_mode).to_lower()
	match mm:
		"map_only", "region_only":
			_cfg.map_label_mode = mm
		_:
			_cfg.map_label_mode = "default"
	_fps_info_node = null
	_fps_map_cached_info = null
	UserPreferencesScript.persist_preferences_json(_cfg)
	refresh_hud_layout()


func _normalize_cluster_edge(s: String) -> String:
	match s.strip_edges().to_lower():
		"top", "t":
			return "top"
		"bottom", "b":
			return "bottom"
		"left", "l":
			return "left"
		"right", "r":
			return "right"
		_:
			return "top"


func _normalize_cluster_alignment(s: String) -> String:
	match s.strip_edges().to_lower():
		"center", "centre", "middle":
			return "center"
		"trailing", "trail", "end", "right", "bottom":
			return "trailing"
		"top", "left", "leading", "lead", "start":
			return "leading"
		_:
			return "leading"


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
		"misc": {
			"compass_enabled": bool(cfg.compass_enabled),
			"compass_anchor": str(cfg.compass_anchor),
			"compass_alpha": float(cfg.compass_color_a),
			"compass_rgb": [int(cfg.compass_color_r), int(cfg.compass_color_g), int(cfg.compass_color_b)],
			"crosshair_enabled": bool(cfg.crosshair_enabled),
			"crosshair_alpha": float(cfg.crosshair_color_a),
			"crosshair_rgb": [int(cfg.crosshair_color_r), int(cfg.crosshair_color_g), int(cfg.crosshair_color_b)],
			"crosshair_shape": str(cfg.crosshair_shape),
			"crosshair_scale_pct": float(cfg.crosshair_scale_pct),
			"crosshair_bloom_enabled": bool(cfg.crosshair_bloom_enabled),
			"crosshair_hide_during_aiming": bool(cfg.crosshair_hide_during_aiming),
			"crosshair_hide_while_stowed": bool(cfg.crosshair_hide_while_stowed),
			"fps_hide_label_prefix": bool(cfg.fps_hide_label_prefix),
			"map_label_mode": str(cfg.map_label_mode),
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
		hud.modulate.a = 0.0 if _hud_force_hidden else 1.0
	var live := _resolve_live_game_data(hud)
	if live != null && is_instance_valid(live):
		_overlay.set_live_game_data(live)
	else:
		_overlay.set_live_game_data(game_data)
	var show_layer: bool = _show_simplehud_layer(hud)
	var vp_sz: Vector2 = _overlay_layout_size_px(hud)
	_overlay.tick(0.0, true, show_layer, vp_sz)
	_overlay.notify_config_changed()
	_overlay.layout_for_viewport(vp_sz, show_layer)


func _process(delta: float) -> void:
	if !_uses_mcm_config_surface():
		_ensure_toggle_hud_action()
		_ensure_show_all_vitals_action()
	if InputMap.has_action("toggle_hud") && Input.is_action_just_pressed("toggle_hud"):
		_hud_force_hidden = !_hud_force_hidden
		refresh_hud_layout()

	var frame := Engine.get_process_frames()
	if frame >= _next_menu_install_probe_frame:
		_next_menu_install_probe_frame = frame + _MENU_INSTALL_PROBE_INTERVAL_FRAMES
		_try_install_simplehud_main_menu()
	if frame >= _next_toggle_hud_bind_probe_frame:
		_next_toggle_hud_bind_probe_frame = frame + _TOGGLE_HUD_BIND_PROBE_INTERVAL_FRAMES
		if !_uses_mcm_config_surface():
			_try_patch_toggle_hud_binding_ui()
	if !_cfg.enabled:
		_clear_binding(true)
		return

	## Fast path: already bound and HUD still in the tree — skip the expensive scene-tree scan every frame.
	if _hud != null && is_instance_valid(_hud) && _hud.is_inside_tree() && is_instance_valid(_overlay):
		_apply_overlay(_hud, delta)
		return

	var hud: Control = _resolve_hud()
	if hud == null:
		_clear_binding()
		return

	_bind_hud(hud)


func _bind_hud(hud: Control) -> void:
	_clear_binding()
	_hud = hud
	_hud_vitals_node = hud.get_node_or_null("Stats/Vitals") as Control
	_hud_medical_node = hud.get_node_or_null("Stats/Medical") as Control
	_hud_info_node = hud.get_node_or_null("Info") as Control
	if _hud_info_node != null:
		_hud_map_label = _hud_info_node.get_node_or_null("Map") as Label

	## Parent into the vanilla HUD (`HUD.gd` subtree per game layout) instead of a root `CanvasLayer`.
	## Same canvas as native vitals/crosshair — avoids an extra viewport layer compositing the full-screen overlay every frame.
	_overlay = SimpleHudOverlay.new()
	_overlay.name = "SimpleHUD"
	_overlay.setup(game_data, _cfg)
	_overlay.visible = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.offset_left = 0.0
	_overlay.offset_top = 0.0
	_overlay.offset_right = 0.0
	_overlay.offset_bottom = 0.0
	_overlay.z_index = 128
	_overlay.z_as_relative = false
	hud.add_child(_overlay)
	_fps_info_node = null

	_apply_overlay(hud, 0.0)


func _apply_overlay(hud: Control, delta: float) -> void:
	if !is_instance_valid(_overlay):
		return

	var prefs := _load_preferences(false)

	var vitals_on: bool = _prefs_bool(prefs, &"vitals", true)
	var medical_on: bool = _prefs_bool(prefs, &"medical", true)

	_overlay.configure_hud_prefs(vitals_on, medical_on)
	var force_show_all := false
	if InputMap.has_action("show_all_vitals"):
		force_show_all = Input.is_action_pressed("show_all_vitals")
	_overlay.set_force_show_all(force_show_all)

	_sync_vanilla_hud_overrides(hud, vitals_on, medical_on)
	hud.modulate.a = 0.0 if _hud_force_hidden else 1.0

	var live := _resolve_live_game_data(hud)
	if live != null && is_instance_valid(live):
		_overlay.set_live_game_data(live)
	else:
		_overlay.set_live_game_data(game_data)

	# Drive our vitals strip only from pause/menu — not from HUD/Stats.visible. The game may hide the
	# Stats node while gameplay values are still meaningful; tying show_layer to it skipped tick()
	# and left the overlay blank (no updates, widgets never filled in).
	var show_layer: bool = _show_simplehud_layer(hud)

	var vp_sz: Vector2 = _overlay_layout_size_px(hud)
	if show_layer:
		_overlay.tick(delta, false, show_layer, vp_sz)

	_overlay.layout_for_viewport(vp_sz, show_layer)

	_apply_fps_map(hud, prefs)


## Escape menu / Settings toggles (Preferences.tres). When true, we hide vanilla rows and draw replacements.
func _sync_vanilla_hud_overrides(hud: Control, vitals_on: bool, medical_on: bool) -> void:
	var vn := _hud_vitals_node
	if vn == null || !is_instance_valid(vn):
		vn = hud.get_node_or_null("Stats/Vitals") as Control
		_hud_vitals_node = vn
	if vn != null && vitals_on && vn.visible:
		vn.visible = false

	var mn := _hud_medical_node
	if mn == null || !is_instance_valid(mn):
		mn = hud.get_node_or_null("Stats/Medical") as Control
		_hud_medical_node = mn
	if mn != null && medical_on && mn.visible:
		mn.visible = false


func _load_preferences(force_refresh: bool = false) -> Resource:
	var frame := Engine.get_process_frames()
	## Fast return: cache is warm and the mtime check interval hasn't elapsed.
	if !force_refresh && _prefs_cache != null && is_instance_valid(_prefs_cache) && frame < _prefs_mtime_next_check_frame:
		return _prefs_cache
	_prefs_mtime_next_check_frame = frame + _PREFS_MTIME_CHECK_INTERVAL_FRAMES
	## Cheap OS stat() — only deserialize the full .tres when the file actually changed.
	var mtime: int = int(FileAccess.get_modified_time("user://Preferences.tres"))
	if !force_refresh && _prefs_cache != null && is_instance_valid(_prefs_cache) && mtime == _prefs_cache_mtime:
		return _prefs_cache
	_prefs_cache = load("user://Preferences.tres") as Resource
	_prefs_cache_mtime = mtime
	return _prefs_cache


func _prefs_bool(prefs: Resource, key: StringName, fallback: bool) -> bool:
	if prefs == null:
		return fallback
	var v: Variant = prefs.get(key)
	if v == null:
		return fallback
	return bool(v)


func _toggle_hud_key_default_event() -> InputEvent:
	return null


func _preferred_toggle_hud_event() -> InputEvent:
	var prefs := _load_preferences(false)
	if prefs != null && is_instance_valid(prefs):
		var action_events: Variant = prefs.get("actionEvents")
		if action_events is Dictionary:
			var d := action_events as Dictionary
			if d.has("toggle_hud") && d["toggle_hud"] is InputEvent:
				return d["toggle_hud"] as InputEvent
	return _toggle_hud_key_default_event()


func _preferred_show_all_vitals_event() -> InputEvent:
	var prefs := _load_preferences(false)
	if prefs != null && is_instance_valid(prefs):
		var action_events: Variant = prefs.get("actionEvents")
		if action_events is Dictionary:
			var d := action_events as Dictionary
			if d.has("show_all_vitals") && d["show_all_vitals"] is InputEvent:
				return d["show_all_vitals"] as InputEvent
	return null


func _ensure_toggle_hud_action() -> void:
	var action_name := "toggle_hud"
	if _toggle_hud_action_ready && InputMap.has_action(action_name):
		if !InputMap.action_get_events(action_name).is_empty():
			return
	_toggle_hud_action_ready = false
	if !InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if !InputMap.has_action(action_name):
		return
	if InputMap.action_get_events(action_name).is_empty():
		var ev := _preferred_toggle_hud_event()
		if ev != null:
			InputMap.action_add_event(action_name, ev)
	if !InputMap.action_get_events(action_name).is_empty():
		_toggle_hud_action_ready = true


func _ensure_show_all_vitals_action() -> void:
	var action_name := "show_all_vitals"
	if _show_all_vitals_action_ready && InputMap.has_action(action_name):
		if !InputMap.action_get_events(action_name).is_empty():
			return
	_show_all_vitals_action_ready = false
	if !InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if !InputMap.has_action(action_name):
		return
	if InputMap.action_get_events(action_name).is_empty():
		var ev := _preferred_show_all_vitals_event()
		if ev != null:
			InputMap.action_add_event(action_name, ev)
	if !InputMap.action_get_events(action_name).is_empty():
		_show_all_vitals_action_ready = true


func _try_patch_toggle_hud_binding_ui() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var root := tree.root
	if root == null:
		return
	## Use the cached node when still valid — avoids a full scene-tree DFS every 90 frames.
	if _binding_ui_node != null && is_instance_valid(_binding_ui_node):
		_patch_binding_node(_binding_ui_node)
		return
	_binding_ui_node = null
	_binding_ui_actions_injected = false
	var stack: Array = [root]
	while !stack.is_empty():
		var n := stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if !(n as Object).has_method(&"CreateActions"):
			continue
		var inputs_v: Variant = n.get("inputs")
		if !(inputs_v is Dictionary):
			continue
		_binding_ui_node = n
		_binding_ui_actions_injected = false
		_patch_binding_node(n)
		return


func _patch_binding_node(n: Node) -> void:
	var inputs_v: Variant = n.get("inputs")
	if !(inputs_v is Dictionary):
		return
	var inputs := (inputs_v as Dictionary).duplicate(true)
	var needs_recreate := false
	if !inputs.has("toggle_hud"):
		inputs["toggle_hud"] = "Toggle HUD"
		needs_recreate = true
	if !inputs.has("show_all_vitals"):
		inputs["show_all_vitals"] = "Show All Vitals"
		needs_recreate = true

	var actions_v: Variant = n.get("actions")
	var has_toggle_row := false
	var has_show_all_row := false
	if actions_v is Node:
		var actions_node := actions_v as Node
		for btn in actions_node.get_children():
			var action_label := btn.find_child("LabelAction")
			if action_label is Label:
				match String((action_label as Label).text):
					"Toggle HUD":
						has_toggle_row = true
					"Show All Vitals":
						has_show_all_row = true

	# Only rebuild when rows are missing; rebuilding every probe can clear in-progress/user keybinds.
	if needs_recreate && (!_binding_ui_actions_injected || !has_toggle_row || !has_show_all_row):
		n.set("inputs", inputs)
		n.call(&"CreateActions")
		_binding_ui_actions_injected = true
	_ensure_toggle_hud_action()
	_ensure_show_all_vitals_action()
	actions_v = n.get("actions")
	if actions_v is Node:
		var actions_node := actions_v as Node
		for btn in actions_node.get_children():
			var action_label := btn.find_child("LabelAction")
			var input_label := btn.find_child("LabelInput")
			if action_label is Label && input_label is Label:
				match (action_label as Label).text:
					"Toggle HUD":
						var evs := InputMap.action_get_events("toggle_hud")
						(input_label as Label).text = evs[0].as_text().trim_suffix("- Physical") if !evs.is_empty() else ""
					"Show All Vitals":
						var evs := InputMap.action_get_events("show_all_vitals")
						(input_label as Label).text = evs[0].as_text().trim_suffix("- Physical") if !evs.is_empty() else ""


## Targets HUD/Info (same nodes Settings → HUD.ShowMap / ShowFPS affect). Visibility is driven by vanilla + prefs.map / prefs.FPS.
func _apply_fps_map(hud: Control, prefs: Resource) -> void:
	if _hud_info_node == null || !is_instance_valid(_hud_info_node):
		_hud_info_node = hud.get_node_or_null("Info") as Control
		if _hud_info_node == null:
			return
		_fps_map_cache_ok = false
	var info := _hud_info_node
	if info != _fps_map_cached_info:
		_fps_map_cached_info = info
		_fps_map_cache_ok = false

	var show_fps := _prefs_bool(prefs, &"FPS", true)
	var show_map := _prefs_bool(prefs, &"map", true)
	var menu_open_now := _game_data_menu_open(_live_game_data)
	var iface := _resolve_interface_node()
	var iface_ok_now := iface != null
	if menu_open_now != _fps_map_prev_menu_open:
		log_fpsmap_diag("menu state changed open=%s (prev=%s)" % [menu_open_now, _fps_map_prev_menu_open])
		_fps_map_prev_menu_open = menu_open_now
	if show_fps != _fps_map_prev_show_fps || show_map != _fps_map_prev_show_map:
		log_fpsmap_diag("pref visibility changed fps=%s map=%s (prev fps=%s map=%s)" % [show_fps, show_map, _fps_map_prev_show_fps, _fps_map_prev_show_map])
		_fps_map_prev_show_fps = show_fps
		_fps_map_prev_show_map = show_map
	if iface_ok_now != _fps_map_prev_iface_ok:
		log_fpsmap_diag("interface availability changed iface_ok=%s (prev=%s)" % [iface_ok_now, _fps_map_prev_iface_ok])
		_fps_map_prev_iface_ok = iface_ok_now
	var fps_prefix := info.get_node_or_null(NodePath("FPS")) as CanvasItem
	if fps_prefix != null:
		fps_prefix.visible = show_fps
	var map_node := info.get_node_or_null(NodePath("Map")) as CanvasItem
	if map_node != null:
		map_node.visible = show_map

	_ensure_fps_label_style(info)
	_apply_map_label_style(info)
	var sc := float(_cfg.fps_map_scale)
	var ox := float(_cfg.fps_map_offset_x)
	var oy := float(_cfg.fps_map_offset_y)
	var a: float = clampf(float(_cfg.fps_map_alpha), 0.0, 1.0)
	if (
		_fps_map_cache_ok
		&& is_equal_approx(sc, _fps_map_c_scale)
		&& is_equal_approx(ox, _fps_map_c_ox)
		&& is_equal_approx(oy, _fps_map_c_oy)
		&& is_equal_approx(a, _fps_map_c_alpha)
	):
		var layout_changed := _update_fps_map_extra_lines(info, hud, iface)
		if layout_changed:
			info.position = _fps_map_cluster_position(info, hud, ox, oy)
		_position_fps_map_extras(info)
		if _fps_map_extra_label != null && is_instance_valid(_fps_map_extra_label):
			_fps_map_extra_label.modulate = Color(1.0, 1.0, 1.0, a)
		if _fps_map_extra_weight_icon != null && is_instance_valid(_fps_map_extra_weight_icon):
			_fps_map_extra_weight_icon.modulate = Color(1.0, 1.0, 1.0, a)
		log_fpsmap_diag(
			"cached apply pos=%s scale=%.3f alpha=%.3f map=%s fps=%s extra_vis=%s extra_text=\"%s\""
			% [info.position, sc, a, show_map, show_fps, _fps_map_extra_label != null && _fps_map_extra_label.visible, _fps_extra_last_text]
		)
		_fpsmap_dump_cluster_snapshot("cached", info, hud, show_fps, show_map, ox, oy, sc, a)
		return
	info.scale = Vector2(sc, sc)
	var changed_now := _update_fps_map_extra_lines(info, hud, iface)
	info.position = _fps_map_cluster_position(info, hud, ox, oy)
	if changed_now:
		info.position = _fps_map_cluster_position(info, hud, ox, oy)
	_position_fps_map_extras(info)
	info.modulate = Color(1.0, 1.0, 1.0, a)
	if _fps_map_extra_label != null && is_instance_valid(_fps_map_extra_label):
		_fps_map_extra_label.modulate = Color(1.0, 1.0, 1.0, a)
	if _fps_map_extra_weight_icon != null && is_instance_valid(_fps_map_extra_weight_icon):
		_fps_map_extra_weight_icon.modulate = Color(1.0, 1.0, 1.0, a)
	log_fpsmap_diag(
		"full apply pos=%s scale=%.3f alpha=%.3f map=%s fps=%s changed=%s extra_vis=%s extra_text=\"%s\""
		% [info.position, sc, a, show_map, show_fps, changed_now, _fps_map_extra_label != null && _fps_map_extra_label.visible, _fps_extra_last_text]
	)
	_fpsmap_dump_cluster_snapshot("full", info, hud, show_fps, show_map, ox, oy, sc, a)
	_fps_map_cache_ok = true
	_fps_map_c_scale = sc
	_fps_map_c_ox = ox
	_fps_map_c_oy = oy
	_fps_map_c_alpha = a


func _fps_map_cluster_position(info: Control, hud: Control, ox: float, oy: float) -> Vector2:
	var vp := get_viewport()
	var vp_size := vp.get_visible_rect().size if vp != null else Vector2(1920, 1080)
	var sz := _fps_map_cluster_visual_size(info)
	var edge := _normalize_cluster_edge(str(_cfg.fps_map_cluster_justify))
	var align := _normalize_cluster_alignment(str(_cfg.fps_map_cluster_alignment))
	var p := Vector2.ZERO
	match edge:
		"bottom":
			p.y = vp_size.y - sz.y - oy
			match align:
				"center":
					p.x = (vp_size.x - sz.x) * 0.5
				"trailing":
					p.x = vp_size.x - sz.x - ox
				_:
					p.x = ox
		"left":
			p.x = ox
			match align:
				"center":
					p.y = (vp_size.y - sz.y) * 0.5
				"trailing":
					p.y = vp_size.y - sz.y - oy
				_:
					p.y = oy
		"right":
			p.x = vp_size.x - sz.x - ox
			match align:
				"center":
					p.y = (vp_size.y - sz.y) * 0.5
				"trailing":
					p.y = vp_size.y - sz.y - oy
				_:
					p.y = oy
		_:
			p.y = oy
			match align:
				"center":
					p.x = (vp_size.x - sz.x) * 0.5
				"trailing":
					p.x = vp_size.x - sz.x - ox
				_:
					p.x = ox
	var out := Vector2(clampf(p.x, 0.0, maxf(0.0, vp_size.x - sz.x)), clampf(p.y, 0.0, maxf(0.0, vp_size.y - sz.y)))
	log_fpsmap_diag("cluster position edge=%s align=%s vp=%s sz=%s in=(%.1f,%.1f) out=%s" % [edge, align, vp_size, sz, ox, oy, out])
	return out


func _fps_map_cluster_visual_size(info: Control) -> Vector2:
	var core_sz := _fps_map_info_only_size(info)
	var core_h := _fps_map_core_text_bottom_offset_px(info)
	if _fps_map_extra_label != null && is_instance_valid(_fps_map_extra_label) && _fps_map_extra_label.visible:
		## extra label is an unscaled sibling of info; its font_size is already pre-multiplied by
		## info.scale in _sync_fps_map_extra_style, so _measure returns true screen pixels directly.
		var extra_sz := _measure_multiline_label_size(_fps_map_extra_label)
		var indent := ((_FPS_MAP_ICON_SIDE_PX + _FPS_MAP_ICON_GAP_PX) * info.scale.x) if _fps_map_extra_show_weight_icon else 0.0
		var out := Vector2(maxf(core_sz.x, extra_sz.x + indent), core_h + _FPS_MAP_EXTRA_SEP_PX + extra_sz.y)
		log_fpsmap_diag("cluster size core=%s core_h=%.2f extra=%s indent=%.1f sep=%.1f out=%s" % [core_sz, core_h, extra_sz, indent, _FPS_MAP_EXTRA_SEP_PX, out])
		return out
	var out_core := Vector2(core_sz.x, core_h)
	log_fpsmap_diag("cluster size core-only=%s core_h=%.2f out=%s" % [core_sz, core_h, out_core])
	return out_core


func _fps_map_info_only_size(info: Control) -> Vector2:
	var base := info.get_combined_minimum_size()
	if base.x <= 1.0 || base.y <= 1.0:
		base = info.size
	# Children can report late/partial mins while FPS/Map values mutate;
	# include current control size so trailing-edge placement never underestimates.
	base = Vector2(maxf(base.x, info.size.x), maxf(base.y, info.size.y))
	return base * info.scale


func _fps_map_core_text_bottom_offset_px(info: Control) -> float:
	if info == null || !is_instance_valid(info):
		return 0.0
	var info_gr := info.get_global_rect()
	var info_top := info_gr.position.y
	var best_bottom := -1.0
	for p in ["Map", "FPS/Frames", "FPS"]:
		var ci := info.get_node_or_null(NodePath(p)) as CanvasItem
		if ci == null || !ci.visible:
			continue
		if ci is Control:
			var cr := (ci as Control).get_global_rect()
			best_bottom = maxf(best_bottom, cr.position.y + cr.size.y)
	if best_bottom < 0.0:
		return _fps_map_info_only_size(info).y
	var off := best_bottom - info_top
	return clampf(off, 0.0, _fps_map_info_only_size(info).y)


func _update_fps_map_extra_lines(info: Control, hud: Control, iface: Node = null) -> bool:
	var want_extra := bool(_cfg.fps_map_show_encumbrance_pct) || bool(_cfg.fps_map_show_inventory_value)
	if !want_extra:
		var was_visible := false
		if _fps_map_extra_label != null && is_instance_valid(_fps_map_extra_label):
			was_visible = _fps_map_extra_label.visible
			_fps_map_extra_label.visible = false
		if _fps_map_extra_weight_icon != null && is_instance_valid(_fps_map_extra_weight_icon):
			_fps_map_extra_weight_icon.visible = false
		_fps_extra_last_text = ""
		log_fpsmap_diag("extras disabled")
		return was_visible
	if _fps_map_extra_label == null || !is_instance_valid(_fps_map_extra_label):
		var lb := Label.new()
		lb.name = "SimpleHUDFPSMapExtra"
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hud.add_child(lb)
		_fps_map_extra_label = lb
	elif _fps_map_extra_label.get_parent() != hud:
		var p := _fps_map_extra_label.get_parent()
		if p != null:
			p.remove_child(_fps_map_extra_label)
		hud.add_child(_fps_map_extra_label)
	if _fps_map_extra_weight_icon == null || !is_instance_valid(_fps_map_extra_weight_icon):
		var tr := TextureRect.new()
		tr.name = "SimpleHUDFPSMapWeightIcon"
		tr.texture = _resolve_weight_icon_texture()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hud.add_child(tr)
		_fps_map_extra_weight_icon = tr
	elif _fps_map_extra_weight_icon.get_parent() != hud:
		var p := _fps_map_extra_weight_icon.get_parent()
		if p != null:
			p.remove_child(_fps_map_extra_weight_icon)
		hud.add_child(_fps_map_extra_weight_icon)
	_sync_fps_map_extra_style(info)
	var frame := Engine.get_process_frames()
	_fps_extra_next_update_frame = frame + _FPS_EXTRA_UPDATE_INTERVAL_FRAMES
	if _game_data_menu_open(_live_game_data):
		if _fps_extra_last_text != "":
			_fps_map_extra_label.visible = true
			log_fpsmap_diag("extras paused/menu-open retain text=\"%s\"" % [_fps_extra_last_text])
		return false
	var lines: Array[String] = []
	var show_weight_icon := false
	if iface == null:
		iface = _resolve_interface_node()
	if iface == null:
		log_fpsmap_diag("extras iface unresolved; retain last text=\"%s\"" % [_fps_extra_last_text])
		return false
	if bool(_cfg.fps_map_show_encumbrance_pct):
		var w := float(iface.get("currentInventoryWeight"))
		var cap := float(iface.get("currentInventoryCapacity"))
		var pct := (w / cap) * 100.0 if cap > 0.001 else 0.0
		lines.append("%.0f%%" % [clampf(pct, 0.0, 999.0)])
		show_weight_icon = true
		log_fpsmap_diag("extras enc raw weight=%.3f cap=%.3f pct=%.3f clamped=%.3f" % [w, cap, pct, clampf(pct, 0.0, 999.0)])
	if bool(_cfg.fps_map_show_inventory_value):
		var val := float(iface.get("currentInventoryValue"))
		var val_rounded := int(round(val))
		var val_fmt := _format_int_with_commas(val_rounded)
		lines.append("%s€" % [val_fmt])
		log_fpsmap_diag("extras value raw=%.3f rounded=%d formatted=%s€" % [val, val_rounded, val_fmt])
	_fps_map_extra_show_weight_icon = show_weight_icon
	if _fps_map_extra_weight_icon != null && is_instance_valid(_fps_map_extra_weight_icon):
		_fps_map_extra_weight_icon.visible = show_weight_icon && !lines.is_empty()
	if lines.is_empty():
		var was_visible_now := _fps_map_extra_label.visible
		_fps_map_extra_label.visible = false
		_fps_extra_last_text = ""
		log_fpsmap_diag("extras no lines produced")
		return was_visible_now
	var new_text := "\n".join(lines)
	var changed := new_text != _fps_extra_last_text || !_fps_map_extra_label.visible
	if new_text != _fps_extra_last_text:
		_fps_extra_last_text = new_text
		_fps_map_extra_label.text = new_text
	_fps_map_extra_label.visible = true
	log_fpsmap_diag("extras updated changed=%s icon=%s text=\"%s\"" % [changed, show_weight_icon, new_text])
	return changed


func _position_fps_map_extras(info: Control) -> void:
	if _fps_map_extra_label == null || !is_instance_valid(_fps_map_extra_label):
		return
	if !_fps_map_extra_label.visible:
		if _fps_map_extra_weight_icon != null && is_instance_valid(_fps_map_extra_weight_icon):
			_fps_map_extra_weight_icon.visible = false
		return
	var sc := info.scale
	var core_sz := _fps_map_info_only_size(info)
	var core_h := _fps_map_core_text_bottom_offset_px(info)
	var base := info.position + Vector2(0.0, core_h + _FPS_MAP_EXTRA_SEP_PX)
	var icon_span := ((_FPS_MAP_ICON_SIDE_PX + _FPS_MAP_ICON_GAP_PX) * sc.x) if _fps_map_extra_show_weight_icon else 0.0
	var label_sz := _measure_multiline_label_size(_fps_map_extra_label)
	var right_x := info.position.x + core_sz.x
	var left_x := info.position.x
	var right_mode := _fps_map_use_right_text_edge()
	if right_mode:
		_fps_map_extra_label.position = Vector2(right_x - label_sz.x, base.y)
	else:
		_fps_map_extra_label.position = Vector2(left_x, base.y)
	var vp := get_viewport()
	if vp != null:
		var vp_size := vp.get_visible_rect().size
		## label_sz is already in screen pixels (font was pre-scaled); do NOT multiply by sc again.
		_fps_map_extra_label.position = Vector2(
			clampf(_fps_map_extra_label.position.x, icon_span, maxf(icon_span, vp_size.x - label_sz.x)),
			clampf(_fps_map_extra_label.position.y, 0.0, maxf(0.0, vp_size.y - label_sz.y))
		)
		log_fpsmap_diag("extras clamp vp=%s label_sz=%s clamped_pos=%s" % [vp_size, label_sz, _fps_map_extra_label.position])
	_refresh_fps_map_weight_icon_transform(_fps_map_extra_label.position, sc)
	log_fpsmap_diag("extras positioned base=%s left_x=%.2f right_x=%.2f right_mode=%s core_h=%.2f icon_span=%.2f label_pos=%s icon=%s" % [base, left_x, right_x, right_mode, core_h, icon_span, _fps_map_extra_label.position, _fps_map_extra_show_weight_icon])


func _refresh_fps_map_weight_icon_transform(label_pos: Vector2, scale_vec: Vector2) -> void:
	if _fps_map_extra_weight_icon == null || !is_instance_valid(_fps_map_extra_weight_icon):
		return
	if _fps_map_extra_label == null || !is_instance_valid(_fps_map_extra_label):
		_fps_map_extra_weight_icon.visible = false
		return
	var sc := scale_vec.x
	var side := _FPS_MAP_ICON_SIDE_PX * sc
	_fps_map_extra_weight_icon.custom_minimum_size = Vector2(side, side)
	_fps_map_extra_weight_icon.size = Vector2(side, side)
	_fps_map_extra_weight_icon.modulate = Color(1.0, 1.0, 1.0, clampf(float(_cfg.fps_map_alpha), 0.0, 1.0))
	## Vertically center the icon with the first text line using actual font metrics.
	var line_h := side
	var fnt := _fps_map_extra_label.get_theme_font("font")
	var fsz := _fps_map_extra_label.get_theme_font_size("font_size")
	if fsz <= 0:
		fsz = maxi(8, int(16 * sc))
	if fnt != null:
		line_h = fnt.get_height(fsz)
	var icon_offset_y := maxf(0.0, (line_h - side) * 0.5)
	var icon_gap := _FPS_MAP_ICON_GAP_PX * sc
	_fps_map_extra_weight_icon.position = Vector2(label_pos.x - side - icon_gap, label_pos.y + icon_offset_y)
	var vp := get_viewport()
	if vp != null:
		var vp_size := vp.get_visible_rect().size
		_fps_map_extra_weight_icon.position = Vector2(
			clampf(_fps_map_extra_weight_icon.position.x, 0.0, maxf(0.0, vp_size.x - side)),
			clampf(_fps_map_extra_weight_icon.position.y, 0.0, maxf(0.0, vp_size.y - side))
		)
	log_fpsmap_diag("icon transform side=%.2f gap=%.2f line_h=%.2f offset_y=%.2f label_pos=%s pos=%s tex=%s mod=%s" % [side, icon_gap, line_h, icon_offset_y, label_pos, _fps_map_extra_weight_icon.position, _fps_map_extra_weight_icon.texture, _fps_map_extra_weight_icon.modulate])


func _measure_multiline_label_size(lb: Label) -> Vector2:
	if lb == null:
		return Vector2.ZERO
	var fnt := lb.get_theme_font("font")
	var sz := lb.get_theme_font_size("font_size")
	if sz <= 0:
		sz = 16
	if fnt == null:
		return lb.get_combined_minimum_size()
	var text := lb.text
	if text == "":
		return Vector2.ZERO
	var parts := text.split("\n", false)
	var width := 0.0
	for p in parts:
		var sample := p if p != "" else " "
		width = maxf(width, fnt.get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x)
	var height := fnt.get_height(sz) * float(parts.size())
	return Vector2(width, height)


func _resolve_weight_icon_texture() -> Texture2D:
	if _fps_map_weight_icon_resolved:
		return _fps_map_weight_icon_texture
	_fps_map_weight_icon_resolved = true
	for p in _HUD_WEIGHT_ICON_PATHS:
		if !ResourceLoader.exists(p):
			continue
		var tex := load(p) as Texture2D
		if tex != null:
			_fps_map_weight_icon_texture = tex
			log_fpsmap_diag("weight icon resolved path=%s" % [p])
			return _fps_map_weight_icon_texture
	log_fpsmap_diag("weight icon unresolved; no valid path")
	return null


func _sync_fps_map_extra_style(info: Control) -> void:
	if _fps_map_extra_label == null || !is_instance_valid(_fps_map_extra_label):
		return
	_fps_map_extra_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if _fps_map_use_right_text_edge() else HORIZONTAL_ALIGNMENT_LEFT
	## Prefer FPS/Frames (the numeric value label) as the style reference — it's the primary element.
	## Fall back to Map label if FPS/Frames isn't found.
	var fps_value := info.get_node_or_null("FPS/Frames") as Label
	var map_label := info.get_node_or_null("Map") as Label
	var style_ref: Label = fps_value if fps_value != null else map_label
	if style_ref != null:
		var chosen_font: Font = style_ref.get_theme_font("font")
		if chosen_font == null:
			chosen_font = _HUD_TEXT_FONT
		if chosen_font != null:
			_fps_map_extra_label.add_theme_font_override("font", chosen_font)
		## info is scaled by fps_map_scale; this label is an unscaled sibling, so pre-scale the
		## font size so it renders at the same visual size as the text inside info.
		var ref_font_size := style_ref.get_theme_font_size("font_size")
		if ref_font_size <= 0:
			ref_font_size = 16
		var scaled_size := maxi(8, int(ref_font_size * info.scale.x))
		_fps_map_extra_label.add_theme_font_size_override("font_size", scaled_size)
		## Force white — same explicit override applied to Info/FPS/Frames in _ensure_fps_label_style.
		_fps_map_extra_label.add_theme_color_override("font_color", Color.WHITE)
		_fps_map_extra_label.add_theme_color_override("font_shadow_color", style_ref.get_theme_color("font_shadow_color"))
		log_fpsmap_diag("style synced from %s ref_size=%d scaled=%d info_scale=%.3f ref_style={%s} extra_style={%s}" % [style_ref.name, ref_font_size, scaled_size, info.scale.x, _fpsmap_label_style_diag(style_ref), _fpsmap_label_style_diag(_fps_map_extra_label)])
	else:
		var fb_size := maxi(8, int(16 * info.scale.x))
		_fps_map_extra_label.add_theme_font_override("font", _HUD_TEXT_FONT)
		_fps_map_extra_label.add_theme_font_size_override("font_size", fb_size)
		_fps_map_extra_label.add_theme_color_override("font_color", Color.WHITE)
		_fps_map_extra_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		log_fpsmap_diag("style fallback size=%d info_scale=%.3f extra_style={%s}" % [fb_size, info.scale.x, _fpsmap_label_style_diag(_fps_map_extra_label)])

func _format_int_with_commas(n: int) -> String:
	var s := str(abs(n))
	var out := ""
	var i := s.length()
	while i > 3:
		out = "," + s.substr(i - 3, 3) + out
		i -= 3
	out = s.substr(0, i) + out
	return ("-" if n < 0 else "") + out


func _resolve_interface_node() -> Node:
	if _ui_interface_node != null && is_instance_valid(_ui_interface_node):
		return _ui_interface_node
	var frame := Engine.get_process_frames()
	if frame < _ui_next_probe_frame:
		return null
	_ui_next_probe_frame = frame + _UI_PROBE_INTERVAL_FRAMES
	log_fpsmap_diag("iface probe frame=%d next=%d" % [frame, _ui_next_probe_frame])
	var tree := get_tree()
	if tree == null || tree.root == null:
		log_fpsmap_diag("iface probe aborted: tree/root unavailable")
		return null
	var stack: Array = [tree.root]
	while !stack.is_empty():
		var n: Node = stack.pop_back()
		if n != null && str(n.name) == "Interface" && n.get("equipmentUI") != null:
			_ui_interface_node = n
			log_fpsmap_diag("iface resolved path=%s" % [str(_ui_interface_node.get_path())])
			return _ui_interface_node
		for c in n.get_children():
			stack.append(c)
	log_fpsmap_diag("iface probe miss")
	return null


func _uses_mcm_config_surface() -> bool:
	return bool(Engine.get_meta(&"SimpleHUD_UsesMCM", false))


func _fps_map_use_right_text_edge() -> bool:
	var edge := _normalize_cluster_edge(str(_cfg.fps_map_cluster_justify))
	var align := _normalize_cluster_alignment(str(_cfg.fps_map_cluster_alignment))
	if edge == "right":
		return true
	return (edge == "top" || edge == "bottom") && align == "trailing"


func _fps_map_use_left_text_edge() -> bool:
	var edge := _normalize_cluster_edge(str(_cfg.fps_map_cluster_justify))
	var align := _normalize_cluster_alignment(str(_cfg.fps_map_cluster_alignment))
	if edge == "left":
		return true
	return (edge == "top" || edge == "bottom") && align == "leading"

func _ensure_fps_label_style(info: Control) -> void:
	if info == null:
		return
	var hide_prefix: bool = bool(_cfg.fps_hide_label_prefix)
	if _fps_info_node == info && _fps_hide_prefix_last == hide_prefix:
		return
	_fps_info_node = info
	_fps_hide_prefix_last = hide_prefix
	# Vanilla HUD: `Info/FPS` is a Label with text "FPS:", and `Info/FPS/Frames` is the numeric child.
	# Do not toggle visibility on the FPS Label — that hides the nested Frames label too when it works,
	# and strict `as Label` casts can fail while `FPS/Frames` resolves, producing overlap. Clear prefix text instead.
	var fps_prefix: Node = info.get_node_or_null(NodePath("FPS"))
	var fps_prefix_label: Label = null
	if fps_prefix != null && (fps_prefix is Label):
		fps_prefix_label = fps_prefix as Label
	var right_edge_text := _fps_map_use_right_text_edge()
	if fps_prefix_label != null:
		if hide_prefix:
			fps_prefix_label.text = ""
		else:
			fps_prefix_label.text = "FPS:"
		## Respect vanilla ShowFPS preference (set in _apply_fps_map).
		fps_prefix_label.add_theme_color_override("font_color", Color.WHITE)
		fps_prefix_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right_edge_text else HORIZONTAL_ALIGNMENT_LEFT
		if right_edge_text:
			fps_prefix_label.offset_left = 0.0
			fps_prefix_label.offset_right = maxf(fps_prefix_label.offset_right, info.size.x)

	var fps_value := info.get_node_or_null(NodePath("FPS/Frames")) as Label
	if fps_value != null:
		fps_value.add_theme_color_override("font_color", Color.WHITE)
		if right_edge_text:
			fps_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			var parent_w := fps_prefix_label.size.x if fps_prefix_label != null else info.size.x
			if parent_w <= 1.0:
				parent_w = maxf(80.0, info.size.x)
			var fnt := fps_value.get_theme_font("font")
			var fsz := fps_value.get_theme_font_size("font_size")
			if fsz <= 0:
				fsz = 16
			var fps_text := fps_value.text if fps_value.text != "" else "000.0"
			var txt_w := 40.0
			if fnt != null:
				txt_w = maxf(txt_w, fnt.get_string_size(fps_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x + 2.0)
			fps_value.offset_right = parent_w
			fps_value.offset_left = parent_w - txt_w
		else:
			fps_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			if hide_prefix:
				# Collapse vanilla +36 gap when "FPS:" prefix is hidden.
				fps_value.offset_left = 0.0
				fps_value.offset_right = 40.0
			else:
				# Restore vanilla spacing with visible "FPS:" prefix.
				fps_value.offset_left = 36.0
				fps_value.offset_right = 76.0
		var min_h := maxf(22.0, fps_value.offset_bottom)
		if fps_prefix_label != null:
			fps_prefix_label.custom_minimum_size = Vector2(fps_prefix_label.custom_minimum_size.x, min_h)


func _apply_map_label_style(info: Control) -> void:
	if info == null:
		return
	if _hud_map_label == null || !is_instance_valid(_hud_map_label):
		_hud_map_label = info.get_node_or_null("Map") as Label
	var map_label := _hud_map_label
	if map_label == null:
		return
	if _fps_map_use_right_text_edge():
		map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		map_label.offset_left = 0.0
		map_label.offset_right = maxf(map_label.offset_right, info.size.x)
	else:
		map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var mode := str(_cfg.map_label_mode).strip_edges().to_lower()
	if mode != "default" && mode != "map_only" && mode != "region_only":
		mode = "default"
	var txt := map_label.text.strip_edges()
	if _has_applied_map_label_style && txt == _last_map_label_src_styled && mode == _map_label_mode_last:
		return
	if txt.find("(") != -1 && txt.find(")") != -1:
		_map_label_full_cache = txt
	var full := _map_label_full_cache if _map_label_full_cache != "" else txt
	var map_name := full
	var region_name := ""
	var open := full.find("(")
	var close := full.rfind(")")
	if open != -1 && close > open:
		map_name = full.substr(0, open).strip_edges()
		region_name = full.substr(open + 1, close - open - 1).strip_edges()
	var out := full
	match mode:
		"map_only":
			out = map_name if map_name != "" else full
		"region_only":
			out = region_name if region_name != "" else full
		_:
			out = full
	if _map_label_mode_last != mode || map_label.text != out:
		map_label.text = out
	_map_label_mode_last = mode
	_last_map_label_src_styled = txt
	_has_applied_map_label_style = true


func _clear_binding(restore_vanilla: bool = false) -> void:
	var bound_hud := _hud
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_fps_info_node = null
	if _fps_map_extra_weight_icon != null && is_instance_valid(_fps_map_extra_weight_icon):
		_fps_map_extra_weight_icon.queue_free()
	_fps_map_extra_weight_icon = null
	if _fps_map_extra_label != null && is_instance_valid(_fps_map_extra_label):
		_fps_map_extra_label.queue_free()
	_fps_map_extra_label = null
	_fps_map_cache_ok = false
	_fps_map_cached_info = null
	_hud_vitals_node = null
	_hud_medical_node = null
	_hud_info_node = null
	_hud_map_label = null
	if restore_vanilla && is_instance_valid(bound_hud):
		_restore_vanilla_hud_visibility(bound_hud)
	_hud = null
	_live_game_data = null


func _restore_vanilla_hud_visibility(hud: Control) -> void:
	if hud == null || !is_instance_valid(hud):
		return
	hud.modulate.a = 1.0
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
	## Direct property probe — O(1) vs iterating the full property list.
	return res.get(&"health") != null && res.get(&"hydration") != null


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

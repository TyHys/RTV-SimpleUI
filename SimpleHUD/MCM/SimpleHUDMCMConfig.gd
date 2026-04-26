extends Node

## MCM (Mod Configuration Menu by Doink Oink) integration autoload for SimpleHUD.
## Only included in SimpleUI-MCM.vmz. Suppresses the main-menu SimpleHUD button so MCM
## is the single configuration surface (Engine.has_meta("SimpleHUD_UsesMCM") checked in Main.gd).

const MOD_ID := "simple-hud"
const SimpleHUDConfigScript := preload("res://SimpleHUD/SimpleHUDConfigCore.gd")
const UserPreferencesScript := preload("res://SimpleHUD/UserPreferences.gd")
const SimpleHUDPresetsReg := preload("res://SimpleHUD/PresetsRegistry.gd")

## MCM writes player config here when settings change.
const MCM_CONFIG_DIR := "user://MCM/" + MOD_ID
const MCM_CONFIG_PATH := MCM_CONFIG_DIR + "/config.ini"
const _KEYBIND_SELF_HEAL_INTERVAL_FRAMES := 30

var _next_keybind_heal_frame: int = 0

## MCM helper resource — possible install paths tried in order.
const _MCM_HELPER_PATHS := [
	"res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres",
	"res://ModConfigurationMenu/MCM_Helpers.tres",
	"res://MCM/MCM_Helpers.tres",
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	## Tells Main.gd to skip injecting the main-menu button — MCM is the config surface.
	Engine.set_meta(&"SimpleHUD_UsesMCM", true)
	## Ensure keybind actions exist early so MCM keycode update path has stable targets.
	_ensure_keybind_actions_exist()
	## Deferred so SimpleHUDMain has been added to the tree and registered its Engine meta.
	call_deferred("_register_with_mcm")


func _process(_delta: float) -> void:
	var frame := Engine.get_process_frames()
	if frame < _next_keybind_heal_frame:
		return
	_next_keybind_heal_frame = frame + _KEYBIND_SELF_HEAL_INTERVAL_FRAMES
	_ensure_keybind_actions_exist()


func _register_with_mcm() -> void:
	var helpers: Object = _load_mcm_helpers()
	if helpers == null:
		push_warning("SimpleHUD MCM: MCM_Helpers resource not found — MCM integration disabled. Install Mod Configuration Menu by Doink Oink alongside SimpleUI-MCM.vmz.")
		return

	_ensure_mcm_config_file(helpers, _simplehud_main())

	if helpers.has_method("RegisterConfiguration"):
		helpers.call(
			"RegisterConfiguration",
			MOD_ID,
			"Simple HUD",
			MCM_CONFIG_DIR,
			"Customize Simple HUD behavior, keybinds, and visibility.",
			Callable(self, "_on_config_updated"),
			self
		)
	else:
		push_warning("SimpleHUD MCM: MCM_Helpers does not expose RegisterConfiguration — API mismatch.")
		return

	## Apply any config that was already saved (previous session or initial MCM defaults).
	_apply_mcm_config_file()


## MCM calls this whenever the player changes a setting.
func _on_config_updated(config: ConfigFile) -> void:
	_ensure_keybind_actions_exist()
	_apply_mcm_config(config)


func _apply_mcm_config_file() -> void:
	var config := ConfigFile.new()
	if config.load(MCM_CONFIG_PATH) != OK:
		## No saved config yet — defaults already baked into the preset Config.gd.
		return
	_ensure_keybind_actions_exist()
	_apply_mcm_config(config)


func _apply_mcm_config(config: ConfigFile) -> void:
	var main := _simplehud_main()
	if main == null:
		return

	if main.has_method(&"apply_status_tray_settings_from_ui"):
		main.call(
			&"apply_status_tray_settings_from_ui",
			bool(_config_value(config, "Bool", "status_auto_hide", false)),
			bool(_config_value(config, "Bool", "status_fill_empty_space", false)),
			str(_config_value(config, "Dropdown", "status_anchor", "right")),
			float(_config_value(config, "Float", "status_padding_px", 5.0)),
			float(_config_value(config, "Float", "status_spacing_px", 2.0)),
			float(_config_value(config, "Float", "status_scale_pct", 100.0)),
			float(_config_value(config, "Float", "status_inactive_alpha_pct", 25.0)),
			int(_config_value(config, "Int", "status_color_r", 120)),
			int(_config_value(config, "Int", "status_color_g", 0)),
			int(_config_value(config, "Int", "status_color_b", 0)),
			str(_config_value(config, "Dropdown", "status_strip_alignment", "trailing")),
			int(_config_value(config, "Int", "status_inactive_r", 120)),
			int(_config_value(config, "Int", "status_inactive_g", 0)),
			int(_config_value(config, "Int", "status_inactive_b", 0))
		)

	if main.has_method(&"apply_vitals_strip_settings_from_ui"):
		main.call(
			&"apply_vitals_strip_settings_from_ui",
			float(_config_value(config, "Float", "vitals_spacing_px", 12.0)),
			str(_config_value(config, "Dropdown", "vitals_strip_alignment", "leading")),
			bool(_config_value(config, "Bool", "vitals_fill_empty_space", false))
		)

	if main.has_method(&"apply_vitals_transparency_from_ui"):
		main.call(
			&"apply_vitals_transparency_from_ui",
			str(_config_value(config, "Dropdown", "vitals_transparency_mode", "dynamic")),
			float(_config_value(config, "Float", "vitals_static_opacity_pct", 75.0))
		)

	if main.has_method(&"apply_stat_settings_to_all_from_ui"):
		var gradient_mode := str(_config_value(config, "Dropdown", "stat_gradient_mode", "preset"))
		var stat_dict: Dictionary = {
			"radial": str(_config_value(config, "Dropdown", "stat_display_mode", "radial")) != "numeric",
			"anchor": str(_config_value(config, "Dropdown", "stat_anchor", "bottom")),
			"padding_px": float(_config_value(config, "Float", "stat_padding_px", 8.0)),
			"scale_pct": float(_config_value(config, "Float", "stat_scale_pct", 100.0)),
			"visible_threshold_pct": float(_config_value(config, "Float", "stat_visible_threshold_pct", 79.0)),
			"gradient_mode": gradient_mode,
		}
		if gradient_mode == "custom":
			stat_dict["gradient"] = {
				"mode": "gradient",
				"high_threshold_pct": float(_config_value(config, "Float", "stat_gradient_high_pct", 75.0)),
				"mid_threshold_pct": float(_config_value(config, "Float", "stat_gradient_mid_pct", 50.0)),
				"low_threshold_pct": float(_config_value(config, "Float", "stat_gradient_low_pct", 0.0)),
				"high_rgb": [
					int(_config_value(config, "Int", "stat_gradient_high_r", 255)),
					int(_config_value(config, "Int", "stat_gradient_high_g", 255)),
					int(_config_value(config, "Int", "stat_gradient_high_b", 255)),
				],
				"mid_rgb": [
					int(_config_value(config, "Int", "stat_gradient_mid_r", 190)),
					int(_config_value(config, "Int", "stat_gradient_mid_g", 190)),
					int(_config_value(config, "Int", "stat_gradient_mid_b", 15)),
				],
				"low_rgb": [
					int(_config_value(config, "Int", "stat_gradient_low_r", 200)),
					int(_config_value(config, "Int", "stat_gradient_low_g", 25)),
					int(_config_value(config, "Int", "stat_gradient_low_b", 15)),
				],
			}
		main.call(&"apply_stat_settings_to_all_from_ui", stat_dict)

	if main.has_method(&"apply_misc_settings_from_ui"):
		main.call(
			&"apply_misc_settings_from_ui",
			bool(_config_value(config, "Bool", "compass_enabled", false)),
			str(_config_value(config, "Dropdown", "compass_anchor", "top")),
			float(_config_value(config, "Float", "compass_alpha_pct", 95.0)),
			int(_config_value(config, "Int", "compass_r", 220)),
			int(_config_value(config, "Int", "compass_g", 220)),
			int(_config_value(config, "Int", "compass_b", 220)),
			bool(_config_value(config, "Bool", "crosshair_enabled", false)),
			float(_config_value(config, "Float", "crosshair_alpha_pct", 95.0)),
			int(_config_value(config, "Int", "crosshair_r", 220)),
			int(_config_value(config, "Int", "crosshair_g", 220)),
			int(_config_value(config, "Int", "crosshair_b", 220)),
			str(_config_value(config, "Dropdown", "crosshair_shape", "crosshair")),
			float(_config_value(config, "Float", "crosshair_scale_pct", 100.0)),
			bool(_config_value(config, "Bool", "crosshair_bloom_enabled", true)),
			bool(_config_value(config, "Bool", "crosshair_hide_during_aiming", false)),
			bool(_config_value(config, "Bool", "crosshair_hide_while_stowed", false)),
			bool(_config_value(config, "Bool", "fps_hide_label_prefix", true)),
			str(_config_value(config, "Dropdown", "map_label_mode", "default")),
			bool(_config_value(config, "Bool", "vital_helmet_enabled", false)),
			bool(_config_value(config, "Bool", "vital_cat_enabled", false)),
			bool(_config_value(config, "Bool", "vital_plate_enabled", false)),
			bool(_config_value(config, "Bool", "show_encumbrance_pct", false)),
			bool(_config_value(config, "Bool", "show_inventory_value", false)),
			str(_config_value(config, "Dropdown", "fps_map_cluster_justify", "top")),
			str(_config_value(config, "Dropdown", "fps_map_cluster_alignment", "leading"))
		)

	## Keybind actions are managed by MCM_Helpers (LoadInput/UpdateInputs). Avoid mutating InputMap
	## here to prevent racey erase/add calls while MCM updates actions.


func _config_value(config: ConfigFile, section: String, key: String, fallback: Variant) -> Variant:
	var entry: Variant = config.get_value(section, key, null)
	if entry is Dictionary:
		var d := entry as Dictionary
		if d.has("value"):
			return d["value"]
	return fallback


func _ensure_keybind_actions_exist() -> void:
	for action_name in ["toggle_hud", "show_all_vitals"]:
		if !InputMap.has_action(action_name):
			InputMap.add_action(action_name)


func _ensure_mcm_config_file(helpers: Object, main: Node) -> void:
	var cfg := _build_default_mcm_config(main)
	if !FileAccess.file_exists(MCM_CONFIG_PATH):
		var dir := DirAccess.open("user://")
		if dir != null:
			dir.make_dir_recursive("MCM/" + MOD_ID)
		cfg.save(MCM_CONFIG_PATH)
		return
	if helpers.has_method("CheckConfigurationHasUpdated"):
		helpers.call("CheckConfigurationHasUpdated", MOD_ID, cfg, MCM_CONFIG_PATH)


func _build_default_mcm_config(main: Node) -> ConfigFile:
	var cfg := ConfigFile.new()
	var status: Dictionary = {}
	var strip: Dictionary = {}
	var stat: Dictionary = {}
	var misc: Dictionary = {}
	var active_preset := ""
	if main != null:
		if main.has_method(&"get_status_tray_settings_for_ui"):
			status = main.call(&"get_status_tray_settings_for_ui")
		if main.has_method(&"get_vitals_strip_settings_for_ui"):
			strip = main.call(&"get_vitals_strip_settings_for_ui")
		if main.has_method(&"get_vitals_common_settings_for_ui"):
			stat = main.call(&"get_vitals_common_settings_for_ui")
		if main.has_method(&"get_misc_settings_for_ui"):
			misc = main.call(&"get_misc_settings_for_ui")
		if main.has_method(&"get_simplehud_active_preset_id"):
			active_preset = str(main.call(&"get_simplehud_active_preset_id"))

	## ── Presets ──────────────────────────────────────────────────────────────
	cfg.set_value("Dropdown", "active_preset_id", {
		"name": "Preset",
		"tooltip": "Select a preset, then use Apply Preset.",
		"default": active_preset,
		"value": active_preset,
		"options": _preset_options_dict(),
		"category": "Presets",
		"menu_pos": 1,
	})
	cfg.set_value("Bool", "preset_apply_now", {
		"name": "Apply Preset",
		"tooltip": "Set to On to apply the selected preset now.",
		"default": false,
		"value": false,
		"category": "Presets",
		"menu_pos": 2,
		"on_value_changed": "_on_preset_apply_requested",
	})

	## ── Vitals ───────────────────────────────────────────────────────────────
	## Order: Display Mode → Edge → Edge Margin → Alignment → Spacing →
	##        Fill Empty Space → Scale → Threshold → Transparency → Opacity →
	##        Gradient mode + custom gradient
	cfg.set_value("Dropdown", "stat_display_mode", {
		"name": "Display Mode",
		"default": "radial" if bool(stat.get("radial", true)) else "numeric",
		"value": "radial" if bool(stat.get("radial", true)) else "numeric",
		"options": {"numeric": "Numeric", "radial": "Radial"},
		"category": "Vitals",
	})
	cfg.set_value("Dropdown", "stat_anchor", {
		"name": "Edge",
		"default": str(stat.get("anchor", "bottom")),
		"value": str(stat.get("anchor", "bottom")),
		"options": {"top": "Top", "bottom": "Bottom", "left": "Left", "right": "Right"},
		"category": "Vitals",
	})
	cfg.set_value("Float", "stat_padding_px", {
		"name": "Edge Margin (px)",
		"default": float(stat.get("padding_px", 8.0)),
		"value": float(stat.get("padding_px", 8.0)),
		"minRange": 0.0,
		"maxRange": 512.0,
		"step": 1.0,
		"category": "Vitals",
	})
	cfg.set_value("Dropdown", "vitals_strip_alignment", {
		"name": "Alignment",
		"default": str(strip.get("strip_alignment", "leading")),
		"value": str(strip.get("strip_alignment", "leading")),
		"options": {"leading": "Leading", "center": "Centered", "trailing": "Trailing"},
		"category": "Vitals",
	})
	cfg.set_value("Float", "vitals_spacing_px", {
		"name": "Spacing (px)",
		"default": float(strip.get("spacing_px", 12.0)),
		"value": float(strip.get("spacing_px", 12.0)),
		"minRange": 0.0,
		"maxRange": 256.0,
		"step": 1.0,
		"category": "Vitals",
	})
	cfg.set_value("Bool", "vitals_fill_empty_space", {
		"name": "Fill Empty Space",
		"default": bool(strip.get("fill_empty_space", false)),
		"value": bool(strip.get("fill_empty_space", false)),
		"category": "Vitals",
	})
	cfg.set_value("Float", "stat_scale_pct", {
		"name": "Scale (%)",
		"default": float(stat.get("scale_pct", 100.0)),
		"value": float(stat.get("scale_pct", 100.0)),
		"minRange": 25.0,
		"maxRange": 400.0,
		"step": 1.0,
		"category": "Vitals",
	})
	cfg.set_value("Float", "stat_visible_threshold_pct", {
		"name": "Minimum Display Threshold (%)",
		"default": float(stat.get("visible_threshold_pct", 79.0)),
		"value": float(stat.get("visible_threshold_pct", 79.0)),
		"minRange": 0.0,
		"maxRange": 101.0,
		"step": 1.0,
		"category": "Vitals",
	})
	cfg.set_value("Dropdown", "vitals_transparency_mode", {
		"name": "Transparency Mode",
		"default": str(strip.get("vitals_transparency_mode", "dynamic")),
		"value": str(strip.get("vitals_transparency_mode", "dynamic")),
		"options": {"dynamic": "Dynamic", "static": "Static"},
		"category": "Vitals",
	})
	cfg.set_value("Float", "vitals_static_opacity_pct", {
		"name": "Static Opacity (%)",
		"default": float(strip.get("vitals_static_opacity_pct", 75.0)),
		"value": float(strip.get("vitals_static_opacity_pct", 75.0)),
		"minRange": 1.0,
		"maxRange": 100.0,
		"step": 1.0,
		"category": "Vitals",
	})
	var grad_mode := str(stat.get("gradient_mode", "preset"))
	var gradient: Dictionary = stat.get("gradient", {})
	cfg.set_value("Dropdown", "stat_gradient_mode", {
		"name": "Gradient Mode",
		"default": grad_mode,
		"value": grad_mode,
		"options": {"preset": "Preset Default", "white": "White Only", "custom": "Custom Gradient"},
		"category": "Vitals",
	})
	cfg.set_value("Float", "stat_gradient_high_pct", {
		"name": "Gradient High Threshold (%)",
		"default": float(gradient.get("high_threshold_pct", 75.0)),
		"value": float(gradient.get("high_threshold_pct", 75.0)),
		"minRange": 0.0,
		"maxRange": 101.0,
		"step": 1.0,
		"category": "Vitals",
	})
	cfg.set_value("Float", "stat_gradient_mid_pct", {
		"name": "Gradient Mid Threshold (%)",
		"default": float(gradient.get("mid_threshold_pct", 50.0)),
		"value": float(gradient.get("mid_threshold_pct", 50.0)),
		"minRange": 0.0,
		"maxRange": 101.0,
		"step": 1.0,
		"category": "Vitals",
	})
	cfg.set_value("Float", "stat_gradient_low_pct", {
		"name": "Gradient Low Threshold (%)",
		"default": float(gradient.get("low_threshold_pct", 0.0)),
		"value": float(gradient.get("low_threshold_pct", 0.0)),
		"minRange": 0.0,
		"maxRange": 101.0,
		"step": 1.0,
		"category": "Vitals",
	})
	var hi: Array = gradient.get("high_rgb", [255, 255, 255])
	var mi: Array = gradient.get("mid_rgb", [190, 190, 15])
	var lo: Array = gradient.get("low_rgb", [200, 25, 15])
	_add_rgb_int(cfg, "Gradient High RGB", "stat_gradient_high", int(hi[0]), int(hi[1]), int(hi[2]), "Vitals")
	_add_rgb_int(cfg, "Gradient Mid RGB", "stat_gradient_mid", int(mi[0]), int(mi[1]), int(mi[2]), "Vitals")
	_add_rgb_int(cfg, "Gradient Low RGB", "stat_gradient_low", int(lo[0]), int(lo[1]), int(lo[2]), "Vitals")

	## ── Ailments ─────────────────────────────────────────────────────────────
	## Order: Auto-hide → Edge → Edge Margin → Alignment → Spacing →
	##        Fill Empty Space → Scale → Inactive Opacity → Active Color → Inactive Color
	cfg.set_value("Bool", "status_auto_hide", {
		"name": "Auto-hide when empty",
		"default": bool(status.get("auto_hide", false)),
		"value": bool(status.get("auto_hide", false)),
		"category": "Ailments",
	})
	cfg.set_value("Dropdown", "status_anchor", {
		"name": "Edge",
		"default": str(status.get("anchor", "right")),
		"value": str(status.get("anchor", "right")),
		"options": {"top": "Top", "bottom": "Bottom", "left": "Left", "right": "Right"},
		"category": "Ailments",
	})
	cfg.set_value("Float", "status_padding_px", {
		"name": "Edge Margin (px)",
		"default": float(status.get("padding_px", 5.0)),
		"value": float(status.get("padding_px", 5.0)),
		"minRange": 0.0,
		"maxRange": 512.0,
		"step": 1.0,
		"category": "Ailments",
	})
	cfg.set_value("Dropdown", "status_strip_alignment", {
		"name": "Alignment",
		"default": str(status.get("strip_alignment", "trailing")),
		"value": str(status.get("strip_alignment", "trailing")),
		"options": {"leading": "Leading", "center": "Centered", "trailing": "Trailing"},
		"category": "Ailments",
	})
	cfg.set_value("Float", "status_spacing_px", {
		"name": "Spacing (px)",
		"default": float(status.get("spacing_px", 2.0)),
		"value": float(status.get("spacing_px", 2.0)),
		"minRange": 0.0,
		"maxRange": 64.0,
		"step": 1.0,
		"category": "Ailments",
	})
	cfg.set_value("Bool", "status_fill_empty_space", {
		"name": "Fill Empty Space",
		"default": bool(status.get("fill_empty_space", false)),
		"value": bool(status.get("fill_empty_space", false)),
		"category": "Ailments",
	})
	cfg.set_value("Float", "status_scale_pct", {
		"name": "Scale (%)",
		"default": float(status.get("scale_pct", 100.0)),
		"value": float(status.get("scale_pct", 100.0)),
		"minRange": 25.0,
		"maxRange": 400.0,
		"step": 1.0,
		"category": "Ailments",
	})
	cfg.set_value("Float", "status_inactive_alpha_pct", {
		"name": "Inactive Opacity (%)",
		"default": float(status.get("inactive_alpha_pct", 25.0)),
		"value": float(status.get("inactive_alpha_pct", 25.0)),
		"minRange": 0.0,
		"maxRange": 100.0,
		"step": 1.0,
		"category": "Ailments",
	})
	_add_rgb_int(cfg, "Ailments Active Color", "status_color", int(status.get("r", 120)), int(status.get("g", 0)), int(status.get("b", 0)), "Ailments")
	_add_rgb_int(cfg, "Ailments Inactive Color", "status_inactive", int(status.get("inactive_r", 120)), int(status.get("inactive_g", 0)), int(status.get("inactive_b", 0)), "Ailments")

	## ── FPS / Map ─────────────────────────────────────────────────────────────
	## Order: FPS Label → Map Label → Edge → Alignment → Encumbrance → Value
	cfg.set_value("Bool", "fps_hide_label_prefix", {
		"name": "Hide FPS Label Prefix",
		"default": bool(misc.get("fps_hide_label_prefix", true)),
		"value": bool(misc.get("fps_hide_label_prefix", true)),
		"category": "FPS / Map",
	})
	cfg.set_value("Dropdown", "map_label_mode", {
		"name": "Map Label Mode",
		"default": str(misc.get("map_label_mode", "default")),
		"value": str(misc.get("map_label_mode", "default")),
		"options": {"default": "Map (Region)", "map_only": "Map Only", "region_only": "Region Only"},
		"category": "FPS / Map",
	})
	cfg.set_value("Dropdown", "fps_map_cluster_justify", {
		"name": "Edge",
		"default": str(misc.get("fps_map_cluster_justify", "top")),
		"value": str(misc.get("fps_map_cluster_justify", "top")),
		"options": {"top": "Top", "bottom": "Bottom", "left": "Left", "right": "Right"},
		"category": "FPS / Map",
	})
	cfg.set_value("Dropdown", "fps_map_cluster_alignment", {
		"name": "Alignment",
		"default": str(misc.get("fps_map_cluster_alignment", "leading")),
		"value": str(misc.get("fps_map_cluster_alignment", "leading")),
		"options": {"leading": "Leading", "center": "Centered on edge", "trailing": "Trailing"},
		"category": "FPS / Map",
	})
	cfg.set_value("Bool", "show_encumbrance_pct", {
		"name": "Show Encumbrance %",
		"default": bool(misc.get("show_encumbrance_pct", false)),
		"value": bool(misc.get("show_encumbrance_pct", false)),
		"category": "FPS / Map",
	})
	cfg.set_value("Bool", "show_inventory_value", {
		"name": "Show Backpack Value",
		"default": bool(misc.get("show_inventory_value", false)),
		"value": bool(misc.get("show_inventory_value", false)),
		"category": "FPS / Map",
	})

	## ── Equipment ─────────────────────────────────────────────────────────────
	cfg.set_value("Bool", "vital_helmet_enabled", {
		"name": "Show Helmet Vital",
		"default": bool(misc.get("vital_helmet_enabled", false)),
		"value": bool(misc.get("vital_helmet_enabled", false)),
		"category": "Equipment",
	})
	cfg.set_value("Bool", "vital_cat_enabled", {
		"name": "Show Cat Vital",
		"default": bool(misc.get("vital_cat_enabled", false)),
		"value": bool(misc.get("vital_cat_enabled", false)),
		"category": "Equipment",
	})
	cfg.set_value("Bool", "vital_plate_enabled", {
		"name": "Show Plate Vital",
		"default": bool(misc.get("vital_plate_enabled", false)),
		"value": bool(misc.get("vital_plate_enabled", false)),
		"category": "Equipment",
	})

	## ── Misc (Compass + Crosshair) ────────────────────────────────────────────
	## Crosshair color RGB kept adjacent to other crosshair settings (not dangling at the end).
	cfg.set_value("Bool", "compass_enabled", {
		"name": "Compass (Beta)",
		"default": bool(misc.get("compass_enabled", false)),
		"value": bool(misc.get("compass_enabled", false)),
		"category": "Misc",
	})
	cfg.set_value("Dropdown", "compass_anchor", {
		"name": "Compass Edge",
		"default": str(misc.get("compass_anchor", "top")),
		"value": str(misc.get("compass_anchor", "top")),
		"options": {"top": "Top", "bottom": "Bottom"},
		"category": "Misc",
	})
	cfg.set_value("Float", "compass_alpha_pct", {
		"name": "Compass Transparency (%)",
		"default": float(misc.get("compass_alpha_pct", 95.0)),
		"value": float(misc.get("compass_alpha_pct", 95.0)),
		"minRange": 0.0,
		"maxRange": 100.0,
		"step": 1.0,
		"category": "Misc",
	})
	_add_rgb_int(cfg, "Compass Color", "compass", int(misc.get("compass_r", 220)), int(misc.get("compass_g", 220)), int(misc.get("compass_b", 220)), "Misc")
	cfg.set_value("Bool", "crosshair_enabled", {
		"name": "Dynamic Crosshair (Beta)",
		"default": bool(misc.get("crosshair_enabled", false)),
		"value": bool(misc.get("crosshair_enabled", false)),
		"category": "Misc",
	})
	cfg.set_value("Dropdown", "crosshair_shape", {
		"name": "Crosshair Shape",
		"default": str(misc.get("crosshair_shape", "crosshair")),
		"value": str(misc.get("crosshair_shape", "crosshair")),
		"options": {"crosshair": "Crosshair", "dot": "Dot"},
		"category": "Misc",
	})
	cfg.set_value("Float", "crosshair_alpha_pct", {
		"name": "Crosshair Transparency (%)",
		"default": float(misc.get("crosshair_alpha_pct", 95.0)),
		"value": float(misc.get("crosshair_alpha_pct", 95.0)),
		"minRange": 0.0,
		"maxRange": 100.0,
		"step": 1.0,
		"category": "Misc",
	})
	cfg.set_value("Float", "crosshair_scale_pct", {
		"name": "Crosshair Scale (%)",
		"default": float(misc.get("crosshair_scale_pct", 100.0)),
		"value": float(misc.get("crosshair_scale_pct", 100.0)),
		"minRange": 25.0,
		"maxRange": 300.0,
		"step": 1.0,
		"category": "Misc",
	})
	cfg.set_value("Bool", "crosshair_bloom_enabled", {
		"name": "Crosshair Bloom",
		"default": bool(misc.get("crosshair_bloom_enabled", true)),
		"value": bool(misc.get("crosshair_bloom_enabled", true)),
		"category": "Misc",
	})
	cfg.set_value("Bool", "crosshair_hide_during_aiming", {
		"name": "Crosshair Hide During Aiming",
		"default": bool(misc.get("crosshair_hide_during_aiming", false)),
		"value": bool(misc.get("crosshair_hide_during_aiming", false)),
		"category": "Misc",
	})
	cfg.set_value("Bool", "crosshair_hide_while_stowed", {
		"name": "Crosshair Hide While Stowed",
		"default": bool(misc.get("crosshair_hide_while_stowed", false)),
		"value": bool(misc.get("crosshair_hide_while_stowed", false)),
		"category": "Misc",
	})
	_add_rgb_int(cfg, "Crosshair Color", "crosshair", int(misc.get("crosshair_r", 220)), int(misc.get("crosshair_g", 220)), int(misc.get("crosshair_b", 220)), "Misc")

	## ── Keybinds ──────────────────────────────────────────────────────────────
	cfg.set_value("Keycode", "toggle_hud", {
		"name": "Toggle HUD Key",
		"default": KEY_EQUAL,
		"default_type": "Key",
		"value": KEY_EQUAL,
		"type": "Key",
		"category": "Keybinds",
	})
	cfg.set_value("Keycode", "show_all_vitals", {
		"name": "Show All Vitals Key",
		"tooltip": "Hold to show all vitals at full visibility.",
		"default": KEY_MINUS,
		"default_type": "Key",
		"value": KEY_MINUS,
		"type": "Key",
		"category": "Keybinds",
	})

	cfg.set_value("Category", "Presets",    {"menu_pos": 0})
	cfg.set_value("Category", "Vitals",     {"menu_pos": 1})
	cfg.set_value("Category", "Ailments",   {"menu_pos": 2})
	cfg.set_value("Category", "FPS / Map",  {"menu_pos": 3})
	cfg.set_value("Category", "Equipment",  {"menu_pos": 4})
	cfg.set_value("Category", "Misc",       {"menu_pos": 5})
	cfg.set_value("Category", "Keybinds",   {"menu_pos": 6})
	_apply_menu_order(cfg)
	return cfg


func _apply_menu_order(cfg: ConfigFile) -> void:
	var pos := 10
	## Presets → Vitals → Ailments → FPS/Map → Equipment → Misc → Keybinds.
	## Within Vitals/Ailments/FPS-Map: Display/Mode → Edge → Edge Margin → Alignment →
	##   Spacing → Fill Empty Space → Scale → [section-specific] → Colors.
	for entry in [
		## Presets
		["Dropdown", "active_preset_id"],
		["Bool",     "preset_apply_now"],
		## Vitals
		["Dropdown", "stat_display_mode"],
		["Dropdown", "stat_anchor"],
		["Float",    "stat_padding_px"],
		["Dropdown", "vitals_strip_alignment"],
		["Float",    "vitals_spacing_px"],
		["Bool",     "vitals_fill_empty_space"],
		["Float",    "stat_scale_pct"],
		["Float",    "stat_visible_threshold_pct"],
		["Dropdown", "vitals_transparency_mode"],
		["Float",    "vitals_static_opacity_pct"],
		["Dropdown", "stat_gradient_mode"],
		["Float",    "stat_gradient_high_pct"],
		["Float",    "stat_gradient_mid_pct"],
		["Float",    "stat_gradient_low_pct"],
		["Int",      "stat_gradient_high_r"],
		["Int",      "stat_gradient_high_g"],
		["Int",      "stat_gradient_high_b"],
		["Int",      "stat_gradient_mid_r"],
		["Int",      "stat_gradient_mid_g"],
		["Int",      "stat_gradient_mid_b"],
		["Int",      "stat_gradient_low_r"],
		["Int",      "stat_gradient_low_g"],
		["Int",      "stat_gradient_low_b"],
		## Ailments
		["Bool",     "status_auto_hide"],
		["Dropdown", "status_anchor"],
		["Float",    "status_padding_px"],
		["Dropdown", "status_strip_alignment"],
		["Float",    "status_spacing_px"],
		["Bool",     "status_fill_empty_space"],
		["Float",    "status_scale_pct"],
		["Float",    "status_inactive_alpha_pct"],
		["Int",      "status_color_r"],
		["Int",      "status_color_g"],
		["Int",      "status_color_b"],
		["Int",      "status_inactive_r"],
		["Int",      "status_inactive_g"],
		["Int",      "status_inactive_b"],
		## FPS / Map
		["Bool",     "fps_hide_label_prefix"],
		["Dropdown", "map_label_mode"],
		["Dropdown", "fps_map_cluster_justify"],
		["Dropdown", "fps_map_cluster_alignment"],
		["Bool",     "show_encumbrance_pct"],
		["Bool",     "show_inventory_value"],
		## Equipment
		["Bool",     "vital_helmet_enabled"],
		["Bool",     "vital_cat_enabled"],
		["Bool",     "vital_plate_enabled"],
		## Misc — compass then crosshair (color RGB kept with its group)
		["Bool",     "compass_enabled"],
		["Dropdown", "compass_anchor"],
		["Float",    "compass_alpha_pct"],
		["Int",      "compass_r"],
		["Int",      "compass_g"],
		["Int",      "compass_b"],
		["Bool",     "crosshair_enabled"],
		["Dropdown", "crosshair_shape"],
		["Float",    "crosshair_alpha_pct"],
		["Float",    "crosshair_scale_pct"],
		["Bool",     "crosshair_bloom_enabled"],
		["Bool",     "crosshair_hide_during_aiming"],
		["Bool",     "crosshair_hide_while_stowed"],
		["Int",      "crosshair_r"],
		["Int",      "crosshair_g"],
		["Int",      "crosshair_b"],
		## Keybinds
		["Keycode",  "toggle_hud"],
		["Keycode",  "show_all_vitals"],
	]:
		_set_menu_pos(cfg, str(entry[0]), str(entry[1]), pos)
		pos += 10


func _set_menu_pos(cfg: ConfigFile, section: String, key: String, menu_pos: int) -> void:
	var entry: Variant = cfg.get_value(section, key, null)
	if !(entry is Dictionary):
		return
	var d := (entry as Dictionary).duplicate(true)
	d["menu_pos"] = menu_pos
	cfg.set_value(section, key, d)


func _add_rgb_int(
	cfg: ConfigFile,
	label_prefix: String,
	key_prefix: String,
	r: int,
	g: int,
	b: int,
	category: String
) -> void:
	cfg.set_value("Int", key_prefix + "_r", {
		"name": label_prefix + " R",
		"default": r,
		"value": r,
		"minRange": 0,
		"maxRange": 255,
		"category": category,
	})
	cfg.set_value("Int", key_prefix + "_g", {
		"name": label_prefix + " G",
		"default": g,
		"value": g,
		"minRange": 0,
		"maxRange": 255,
		"category": category,
	})
	cfg.set_value("Int", key_prefix + "_b", {
		"name": label_prefix + " B",
		"default": b,
		"value": b,
		"minRange": 0,
		"maxRange": 255,
		"category": category,
	})


func _preset_options_dict() -> Dictionary:
	var d := {}
	for p in SimpleHUDPresetsReg.PRESETS:
		var pid := str(p.get("id", ""))
		if pid == "":
			continue
		d[pid] = str(p.get("label", pid))
	return d


func _on_preset_apply_requested(_value_id: String, new_value: Variant, menu: Node) -> void:
	if !bool(new_value):
		return
	var main := _simplehud_main()
	if main == null || !main.has_method(&"apply_simplehud_preset"):
		return
	if menu == null || !menu.has_method(&"GetElements"):
		return
	var elements: Dictionary = menu.call(&"GetElements")
	if !elements.has("active_preset_id"):
		return
	var preset_element: Variant = elements["active_preset_id"]
	if !(preset_element as Object).has_method(&"GetValue"):
		return
	var preset_id := str((preset_element as Object).call(&"GetValue")).strip_edges()
	if preset_id == "":
		_set_apply_toggle_off(elements)
		return
	var ok: bool = bool(main.call(&"apply_simplehud_preset", preset_id))
	if ok:
		_sync_menu_from_main(elements)
	_set_apply_toggle_off(elements)


func _set_apply_toggle_off(elements: Dictionary) -> void:
	var apply_el: Variant = elements.get("preset_apply_now", null)
	if apply_el != null && (apply_el as Object).has_method(&"SetValue"):
		(apply_el as Object).call(&"SetValue", false)


func _sync_menu_from_main(elements: Dictionary) -> void:
	var main := _simplehud_main()
	if main == null:
		return
	var snapshot := _build_default_mcm_config(main)
	for section in snapshot.get_sections():
		if section == "Category":
			continue
		for key in snapshot.get_section_keys(section):
			if !elements.has(key):
				continue
			var entry: Variant = snapshot.get_value(section, key, null)
			if !(entry is Dictionary):
				continue
			var d := entry as Dictionary
			if !d.has("value"):
				continue
			_set_element_value(elements[key], d["value"])


func _set_element_value(element: Variant, value: Variant) -> void:
	if element == null || !(element as Object).has_method(&"SetValue"):
		return
	var value_data: Variant = (element as Object).get("valueData")
	if value_data is Dictionary:
		var vd := value_data as Dictionary
		if vd.has("options") && vd["options"] is Dictionary:
			var keys := (vd["options"] as Dictionary).keys()
			var idx := keys.find(value)
			if idx >= 0:
				(element as Object).call(&"SetValue", idx)
				return
	(element as Object).call(&"SetValue", value)


func _simplehud_main() -> Node:
	var v: Variant = Engine.get_meta(&"SimpleHUDMain", null)
	if v is Node && is_instance_valid(v):
		return v as Node
	return null


func _load_mcm_helpers() -> Object:
	for p in _MCM_HELPER_PATHS:
		var obj: Object = load(p) as Object
		if obj != null:
			return obj
	return null

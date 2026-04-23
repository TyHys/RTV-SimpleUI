extends RefCounted

## Parses `user://simplehud_preferences.json` (optional) and merges into SimpleHUD Config.
## Intended to give players one file instead of swapping preset Config.gd.

const USER_PATH := "user://simplehud_preferences.json"


## Alias for UI / external callers (same rules as `_normalize_edge`).
static func normalize_anchor(s: String) -> String:
	return _normalize_edge(s)


## Vitals: how widgets pack along a shared edge (horizontal strip: LTR / centered / RTL; vertical: top→down / centered / bottom→up).
static func normalize_strip_alignment(s: String) -> String:
	match str(s).strip_edges().to_lower():
		"c", "center", "centre", "middle":
			return "center"
		"t", "trail", "trailing", "end":
			return "trailing"
		"l", "lead", "leading", "begin", "start":
			return "leading"
		_:
			return "leading"


## Ailment tray: packing along the strip (HBox/VBox main axis).
static func normalize_status_strip_alignment(s: String) -> String:
	match str(s).strip_edges().to_lower():
		"c", "center", "centre", "middle":
			return "center"
		"l", "lead", "leading", "begin", "start":
			return "leading"
		"t", "trail", "trailing", "end":
			return "trailing"
		_:
			return "trailing"


## Writes only the `status` object into `user://simplehud_preferences.json`, preserving other top-level keys if the file exists.
static func persist_status_section(cfg: RefCounted) -> void:
	persist_all(cfg)


## Writes general, vitals_layout, vitals (all stats), status, and fps_map. Preserves unrelated top-level keys from an existing file.
static func persist_all(cfg: RefCounted) -> void:
	persist_preferences_json(cfg)


static func persist_preferences_json(cfg: RefCounted) -> void:
	if cfg == null:
		return
	var merged: Dictionary = {}
	if FileAccess.file_exists(USER_PATH):
		var rf := FileAccess.open(USER_PATH, FileAccess.READ)
		if rf:
			var parsed: Variant = JSON.parse_string(rf.get_as_text())
			if parsed is Dictionary:
				merged = (parsed as Dictionary).duplicate(true)
	merged["general"] = _build_general(cfg)
	merged["vitals_layout"] = _build_vitals_layout(cfg)
	merged["vitals"] = _build_vitals_stats(cfg)
	merged["status"] = _build_status(cfg)
	merged["misc"] = _build_misc(cfg)
	merged["fps_map"] = _build_fps_map(cfg)
	var out := JSON.stringify(merged, "\t")
	var wf := FileAccess.open(USER_PATH, FileAccess.WRITE)
	if wf == null:
		push_warning("SimpleHUD: could not write %s" % USER_PATH)
		return
	wf.store_string(out)


static func _build_general(cfg: RefCounted) -> Dictionary:
	return {
		"enabled": bool(cfg.enabled),
		"min_stat_alpha_floor": float(cfg.min_stat_alpha_floor),
		"vitals_transparency_mode": str(cfg.vitals_transparency_mode),
		"vitals_static_opacity": float(cfg.vitals_static_opacity),
		"numeric_only": bool(cfg.numeric_only),
		"stamina_fatigue_near_zero_cutoff": float(cfg.stamina_fatigue_near_zero_cutoff),
		"active_preset": str(cfg.get_meta(&"simplehud_active_preset", "")),
	}


static func _build_vitals_layout(cfg: RefCounted) -> Dictionary:
	return {
		"spacing_px": float(cfg.vitals_spacing_default_px),
		"strip_alignment": str(cfg.vitals_strip_alignment),
		"fill_empty_space": bool(cfg.vitals_fill_empty_space),
		"margin_top": float(cfg.vitals_margin_top),
		"margin_bottom": float(cfg.vitals_margin_bottom),
		"margin_left": float(cfg.vitals_margin_left),
		"margin_right": float(cfg.vitals_margin_right),
		"strip_width_px": float(cfg.vitals_strip_width_px),
		"row_height_px": float(cfg.vitals_row_height_px),
	}


static func _build_vitals_stats(cfg: RefCounted) -> Dictionary:
	var out := {}
	for sid in cfg.STAT_IDS:
		out[String(sid)] = _serialize_stat(cfg, sid)
	return out


static func _serialize_stat(cfg: RefCounted, sid: StringName) -> Dictionary:
	var d := {}
	var use_radial := bool(cfg.radial.get(sid, true))
	d["mode"] = "radial" if use_radial else "numeric"
	d["anchor"] = str(cfg.get_vitals_anchor(sid))
	d["padding_px"] = float(cfg.get_vitals_padding_px(sid))
	d["spacing_px"] = float(cfg.get_spacing_after_stat(sid))
	d["scale_pct"] = float(cfg.get_vitals_scale_pct(sid))
	d["visible_threshold_pct"] = float(cfg.get_threshold(sid))
	if cfg.stat_gradient_overrides.has(sid):
		var gd: Variant = cfg.stat_gradient_overrides[sid]
		if gd is Dictionary:
			d["gradient"] = (gd as Dictionary).duplicate(true)
	return d


static func _build_status(cfg: RefCounted) -> Dictionary:
	return {
		"mode": str(cfg.status_mode),
		"auto_hide_when_none": bool(cfg.status_auto_hide_when_none),
		"fill_empty_space": bool(cfg.status_fill_empty_space),
		"anchor": str(cfg.status_anchor),
		"spacing_px": float(cfg.status_spacing_px),
		"padding_px": float(cfg.status_padding_px),
		"scale_pct": float(cfg.status_scale_pct),
		"stack_direction": str(cfg.status_stack_direction),
		"strip_alignment": str(cfg.status_strip_alignment),
		"inactive_alpha": float(cfg.status_inactive_alpha),
		"rgb": [int(cfg.status_color_r), int(cfg.status_color_g), int(cfg.status_color_b)],
		"inactive_rgb": [int(cfg.status_inactive_r), int(cfg.status_inactive_g), int(cfg.status_inactive_b)],
	}


static func _build_misc(cfg: RefCounted) -> Dictionary:
	return {
		"compass_enabled": bool(cfg.compass_enabled),
		"compass_anchor": str(cfg.compass_anchor),
		"compass_rgb": [int(cfg.compass_color_r), int(cfg.compass_color_g), int(cfg.compass_color_b)],
		"compass_alpha": float(cfg.compass_color_a),
	}


static func _build_fps_map(cfg: RefCounted) -> Dictionary:
	return {
		"alpha": float(cfg.fps_map_alpha),
		"scale": float(cfg.fps_map_scale),
		"anchor": str(cfg.fps_map_anchor),
		"offset_x": float(cfg.fps_map_offset_x),
		"offset_y": float(cfg.fps_map_offset_y),
	}


static func merge_into(cfg: RefCounted) -> void:
	var path := USER_PATH
	if !FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("SimpleHUD: could not open %s" % path)
		return
	var txt := f.get_as_text()
	var data: Variant = JSON.parse_string(txt)
	if data == null || typeof(data) != TYPE_DICTIONARY:
		push_warning("SimpleHUD: invalid JSON in %s" % path)
		return
	var d := data as Dictionary
	_merge_root(cfg, d)


static func _merge_root(cfg: RefCounted, d: Dictionary) -> void:
	if !cfg:
		return
	if d.has("general"):
		var g := _as_dict(d["general"])
		var had_vitals_mode := g.has("vitals_transparency_mode")
		if g.has("enabled"):
			cfg.enabled = bool(g["enabled"])
		if g.has("min_stat_alpha_floor"):
			cfg.min_stat_alpha_floor = clampf(float(g["min_stat_alpha_floor"]), 0.0, 1.0)
		if g.has("vitals_transparency_mode"):
			cfg.vitals_transparency_mode = str(g["vitals_transparency_mode"])
		if g.has("vitals_static_opacity"):
			cfg.vitals_static_opacity = clampf(float(g["vitals_static_opacity"]), 0.0, 1.0)
		if !had_vitals_mode && g.has("min_stat_alpha_floor"):
			cfg.vitals_transparency_mode = "opaque" if cfg.min_stat_alpha_floor >= 0.999 else "dynamic"
		if g.has("numeric_only"):
			cfg.numeric_only = bool(g["numeric_only"])
		if g.has("stamina_fatigue_near_zero_cutoff"):
			cfg.stamina_fatigue_near_zero_cutoff = clampf(float(g["stamina_fatigue_near_zero_cutoff"]), 0.0, 5.0)
		if g.has("active_preset"):
			cfg.set_meta(&"simplehud_active_preset", str(g["active_preset"]))

	if d.has("vitals_layout"):
		var vl := _as_dict(d["vitals_layout"])
		if vl.has("spacing_px"):
			cfg.vitals_spacing_default_px = clampf(float(vl["spacing_px"]), 0.0, 256.0)
		if vl.has("strip_alignment"):
			cfg.vitals_strip_alignment = normalize_strip_alignment(str(vl["strip_alignment"]))
		if vl.has("fill_empty_space"):
			cfg.vitals_fill_empty_space = bool(vl["fill_empty_space"])
		if vl.has("margin_top"):
			cfg.vitals_margin_top = clampf(float(vl["margin_top"]), 0.0, 512.0)
		if vl.has("margin_bottom"):
			cfg.vitals_margin_bottom = clampf(float(vl["margin_bottom"]), 0.0, 512.0)
		if vl.has("margin_left"):
			cfg.vitals_margin_left = clampf(float(vl["margin_left"]), 0.0, 512.0)
		if vl.has("margin_right"):
			cfg.vitals_margin_right = clampf(float(vl["margin_right"]), 0.0, 512.0)
		if vl.has("strip_width_px"):
			cfg.vitals_strip_width_px = clampf(float(vl["strip_width_px"]), 120.0, 4096.0)
		if vl.has("row_height_px"):
			cfg.vitals_row_height_px = clampf(float(vl["row_height_px"]), 16.0, 256.0)

	if d.has("vitals"):
		var stats := _as_dict(d["vitals"])
		for sid in cfg.STAT_IDS:
			var key := String(sid)
			if !stats.has(key):
				continue
			var sd := _as_dict(stats[key])
			_merge_one_stat(cfg, sid, sd)

	if d.has("status"):
		var st := _as_dict(d["status"])
		if st.has("mode"):
			cfg.status_mode = str(st["mode"])
		if st.has("auto_hide_when_none"):
			cfg.status_auto_hide_when_none = bool(st["auto_hide_when_none"])
		if st.has("fill_empty_space"):
			cfg.status_fill_empty_space = bool(st["fill_empty_space"])
		if st.has("anchor"):
			cfg.status_anchor = _normalize_edge(str(st["anchor"]))
		if st.has("spacing_px"):
			cfg.status_spacing_px = clampf(float(st["spacing_px"]), 0.0, 64.0)
		if st.has("padding_px"):
			cfg.status_padding_px = clampf(float(st["padding_px"]), 0.0, 512.0)
		if st.has("scale_pct"):
			cfg.status_scale_pct = clampf(float(st["scale_pct"]), 25.0, 400.0)
		if st.has("stack_direction"):
			cfg.status_stack_direction = str(st["stack_direction"])
		if st.has("strip_alignment"):
			cfg.status_strip_alignment = normalize_status_strip_alignment(str(st["strip_alignment"]))
		if st.has("inactive_alpha"):
			cfg.status_inactive_alpha = clampf(float(st["inactive_alpha"]), 0.0, 1.0)
		var rgb := _optional_rgb_arr(st, "rgb")
		if rgb.size() >= 3:
			cfg.status_color_r = clampi(int(rgb[0]), 0, 255)
			cfg.status_color_g = clampi(int(rgb[1]), 0, 255)
			cfg.status_color_b = clampi(int(rgb[2]), 0, 255)
		var irgb := _optional_rgb_arr(st, "inactive_rgb")
		if irgb.size() >= 3:
			cfg.status_inactive_r = clampi(int(irgb[0]), 0, 255)
			cfg.status_inactive_g = clampi(int(irgb[1]), 0, 255)
			cfg.status_inactive_b = clampi(int(irgb[2]), 0, 255)
		elif rgb.size() >= 3:
			cfg.status_inactive_r = cfg.status_color_r
			cfg.status_inactive_g = cfg.status_color_g
			cfg.status_inactive_b = cfg.status_color_b
		## Row vs column follows tray edge (ignore legacy stack_direction conflicts).
		var sax := str(cfg.status_anchor).to_lower()
		if sax == "left" || sax == "right":
			cfg.status_stack_direction = "vertical_up"
		else:
			cfg.status_stack_direction = "horizontal_left"

	if d.has("misc"):
		var mx := _as_dict(d["misc"])
		if mx.has("compass_enabled"):
			cfg.compass_enabled = bool(mx["compass_enabled"])
		if mx.has("compass_anchor"):
			var ax := str(mx["compass_anchor"]).strip_edges().to_lower()
			cfg.compass_anchor = "bottom" if ax == "bottom" else "top"
		var crgb := _optional_rgb_arr(mx, "compass_rgb")
		if crgb.size() >= 3:
			cfg.compass_color_r = clampi(int(crgb[0]), 0, 255)
			cfg.compass_color_g = clampi(int(crgb[1]), 0, 255)
			cfg.compass_color_b = clampi(int(crgb[2]), 0, 255)
		if mx.has("compass_alpha"):
			cfg.compass_color_a = clampf(float(mx["compass_alpha"]), 0.0, 1.0)

	if d.has("fps_map"):
		var fm := _as_dict(d["fps_map"])
		if fm.has("alpha"):
			cfg.fps_map_alpha = clampf(float(fm["alpha"]), 0.0, 1.0)
		if fm.has("scale"):
			cfg.fps_map_scale = clampf(float(fm["scale"]), 0.1, 3.0)
		if fm.has("anchor"):
			cfg.fps_map_anchor = str(fm["anchor"])
		if fm.has("offset_x"):
			cfg.fps_map_offset_x = clampf(float(fm["offset_x"]), 0.0, 256.0)
		if fm.has("offset_y"):
			cfg.fps_map_offset_y = clampf(float(fm["offset_y"]), 0.0, 256.0)


static func _merge_one_stat(cfg: RefCounted, sid: StringName, sd: Dictionary) -> void:
	if sd.has("mode"):
		var m := str(sd["mode"]).to_lower()
		cfg.radial[sid] = m == "radial"
	if sd.has("anchor"):
		cfg.vitals_anchor[sid] = _normalize_edge(str(sd["anchor"]))
	if sd.has("padding_px"):
		cfg.vitals_padding_px[sid] = clampf(float(sd["padding_px"]), 0.0, 512.0)
	if sd.has("spacing_px"):
		cfg.vitals_spacing_px[sid] = clampf(float(sd["spacing_px"]), 0.0, 256.0)
	if sd.has("scale_pct"):
		cfg.vitals_scale_pct[sid] = clampf(float(sd["scale_pct"]), 25.0, 400.0)
	if sd.has("visible_threshold_pct"):
		cfg.visible_threshold[sid] = float(sd["visible_threshold_pct"])

	if sd.has("gradient"):
		var gd := _as_dict(sd["gradient"])
		var entry: Dictionary = {}
		if gd.has("mode"):
			entry["mode"] = str(gd["mode"]).to_lower()
		if gd.has("high_threshold_pct"):
			entry["high_threshold_pct"] = clampf(float(gd["high_threshold_pct"]), 0.0, 100.0)
		if gd.has("mid_threshold_pct"):
			entry["mid_threshold_pct"] = clampf(float(gd["mid_threshold_pct"]), 0.0, 100.0)
		if gd.has("low_threshold_pct"):
			entry["low_threshold_pct"] = clampf(float(gd["low_threshold_pct"]), 0.0, 100.0)
		var hi := _optional_rgb_arr(gd, "high_rgb")
		var mid := _optional_rgb_arr(gd, "mid_rgb")
		var lo := _optional_rgb_arr(gd, "low_rgb")
		if hi.size() >= 3:
			entry["high_rgb"] = hi
		if mid.size() >= 3:
			entry["mid_rgb"] = mid
		if lo.size() >= 3:
			entry["low_rgb"] = lo
		cfg.stat_gradient_overrides[sid] = entry
	else:
		cfg.stat_gradient_overrides.erase(sid)


static func _normalize_edge(s: String) -> String:
	match s.strip_edges().to_lower():
		"t", "top":
			return "top"
		"b", "bottom":
			return "bottom"
		"l", "left":
			return "left"
		"r", "right":
			return "right"
		_:
			return "bottom"


static func _as_dict(v: Variant) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}


static func _optional_rgb_arr(d: Dictionary, key: String) -> Array:
	if !d.has(key):
		return []
	var v: Variant = d[key]
	if v is Array && (v as Array).size() >= 3:
		var a := v as Array
		return [clampi(int(a[0]), 0, 255), clampi(int(a[1]), 0, 255), clampi(int(a[2]), 0, 255)]
	return []

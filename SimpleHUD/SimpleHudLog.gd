extends RefCounted

## Writes to %APPDATA%/Road to Vostok/logs/SimpleHUD.log on Windows (never the Roaming folder root).

static var _enabled: bool = true


static func configure(p_enabled: bool) -> void:
	_enabled = p_enabled


static func is_enabled() -> bool:
	return _enabled


static func resolve_log_path() -> String:
	if OS.has_feature("windows"):
		var appdata := OS.get_environment("APPDATA")
		if appdata != "":
			return appdata.path_join("Road to Vostok").path_join("logs").path_join("SimpleHUD.log")
	return OS.get_user_data_dir().path_join("logs").path_join("SimpleHUD.log")


static func info(msg: String) -> void:
	if !_enabled:
		return
	var path := resolve_log_path()
	var dir_path := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)

	var fa := FileAccess.open(path, FileAccess.READ_WRITE)
	if fa == null:
		var tmp := FileAccess.open(path, FileAccess.WRITE)
		if tmp != null:
			tmp.close()
		fa = FileAccess.open(path, FileAccess.READ_WRITE)
	if fa == null:
		return
	fa.seek_end()
	var stamp: String = Time.get_datetime_string_from_system()
	fa.store_line("[%s] %s" % [stamp, msg])
	fa.close()

extends Node

## Handles saving and loading player progression and game settings via JSON
## Attached as Autoload singleton: SaveManager

const SAVE_PATH: String = "user://savegame.json"
const SETTINGS_PATH: String = "user://settings.json"

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_progress(level: int) -> bool:
	var prev_highest: int = 0
	if has_save_file():
		var old_data: Dictionary = load_progress()
		prev_highest = int(old_data.get("highest_level", 0))
	var highest: int = maxi(level, prev_highest)
	var save_data: Dictionary = {
		"current_level": level,
		"highest_level": highest,
		"saved_at": Time.get_datetime_string_from_system()
	}
	var json_string: String = JSON.stringify(save_data, "\t")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Failed to open save file for writing: %s" % FileAccess.get_open_error())
		return false
	file.store_string(json_string)
	file.close()
	EventBus.checkpoint_saved.emit()
	return true

func load_progress() -> Dictionary:
	var default_res: Dictionary = {"current_level": 0, "highest_level": 0}
	if not FileAccess.file_exists(SAVE_PATH):
		return default_res
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return default_res
	var content: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(content)
	if parse_result != OK:
		push_error("SaveManager: JSON parse error in save file.")
		return default_res
	if json.data is Dictionary:
		return json.data as Dictionary
	return default_res

func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

func save_settings(settings: Dictionary) -> bool:
	var json_string: String = JSON.stringify(settings, "\t")
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Failed to open settings file for writing: %s" % FileAccess.get_open_error())
		return false
	file.store_string(json_string)
	file.close()
	return true

func load_settings() -> Dictionary:
	var default_settings: Dictionary = {
		"master_volume": 1.0,
		"music_volume": 0.8,
		"sfx_volume": 0.9,
		"fullscreen": false,
		"vsync": true
	}
	if not FileAccess.file_exists(SETTINGS_PATH):
		return default_settings
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return default_settings
	var content: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(content) != OK:
		return default_settings
	if json.data is Dictionary:
		var loaded: Dictionary = json.data as Dictionary
		for key in default_settings.keys():
			if not loaded.has(key):
				loaded[key] = default_settings[key]
		return loaded
	return default_settings

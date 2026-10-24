extends Node

## Handles saving and loading player progression and game settings via JSON
## Attached as Autoload singleton: SaveManager

const SAVE_PATH: String = "user://savegame.json"
const SETTINGS_PATH: String = "user://settings.json"

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_progress(highest_level: int) -> bool:
	var save_data: Dictionary = {
		"highest_level": highest_level,
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
	if not FileAccess.file_exists(SAVE_PATH):
		return {"highest_level": 1}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {"highest_level": 1}
	var content: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(content)
	if parse_result != OK:
		push_error("SaveManager: JSON parse error in save file.")
		return {"highest_level": 1}
	if json.data is Dictionary:
		return json.data as Dictionary
	return {"highest_level": 1}

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

extends Node

## Handles saving and loading player progression and game settings via JSON
## Attached as Autoload singleton: SaveManager

const SAVE_PATH: String = "user://savegame.json"
const SETTINGS_PATH: String = "user://settings.json"
const PROFILE_PATH: String = "user://player_profile.json"

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_progress(highest_level: int) -> bool:
	# Progress is monotonic: never overwrite a further checkpoint with an earlier one.
	# (Otherwise the first Living Room, level 0, would wipe the checkpoint you can Continue from.)
	var existing_level: int = int(load_progress().get("highest_level", 0))
	if highest_level < existing_level:
		return false
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
		return {"highest_level": 0}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {"highest_level": 0}
	var content: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(content)
	if parse_result != OK:
		push_error("SaveManager: JSON parse error in save file.")
		return {"highest_level": 0}
	if json.data is Dictionary:
		return json.data as Dictionary
	return {"highest_level": 0}

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


## Saves the player's chosen name and appearance preset (see PlayerPresets).
func save_player_profile(player_name: String, preset_id: int) -> bool:
	var profile_data: Dictionary = {
		"name": player_name,
		"preset_id": preset_id,
		"saved_at": Time.get_datetime_string_from_system()
	}
	return _store_json(PROFILE_PATH, profile_data)


## Loads the player's name and preset. Defaults to no name and the first preset.
func load_player_profile() -> Dictionary:
	var defaults: Dictionary = {"name": "", "preset_id": 0}
	if not FileAccess.file_exists(PROFILE_PATH):
		return defaults
	var file: FileAccess = FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if not file:
		return defaults
	var content: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(content) != OK or not json.data is Dictionary:
		return defaults
	var loaded: Dictionary = json.data as Dictionary
	for key in defaults.keys():
		if not loaded.has(key):
			loaded[key] = defaults[key]
	return loaded


func _store_json(path: String, data: Dictionary) -> bool:
	var json_string: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Failed to open file for writing: %s" % FileAccess.get_open_error())
		return false
	file.store_string(json_string)
	file.close()
	return true

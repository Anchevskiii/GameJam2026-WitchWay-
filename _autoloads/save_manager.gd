extends Node

## Handles saving and loading player progression via JSON
## Attached as Autoload singleton: SaveManager

const SAVE_PATH: String = "user://savegame.json"

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

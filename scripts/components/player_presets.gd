class_name PlayerPresets
extends RefCounted

## Registry of the 5 playable character presets (male, female + Halloween monsters).
## Shared by the Customization menu and the in-game player controller so the chosen
## look is the same everywhere. No scene attachment needed - use the static methods.

const DEFAULT_ID: int = 0

static var _presets: Array[Dictionary] = [
	{"id": 0, "name": "Male", "texture": "res://assets/sprites/characters/player_guy.png"},
	{"id": 1, "name": "Witch", "texture": "res://assets/sprites/characters/witch.png"},
	{"id": 2, "name": "Vampire", "texture": "res://assets/sprites/characters/vampire.png"},
	{"id": 3, "name": "Werewolf", "texture": "res://assets/sprites/characters/werewolf.png"},
	{"id": 4, "name": "Ghost", "texture": "res://assets/sprites/characters/ghost.png"},
]


static func count() -> int:
	return _presets.size()


static func is_valid(id: int) -> bool:
	return id >= 0 and id < _presets.size()


static func display_name(id: int) -> String:
	if is_valid(id):
		return String(_presets[id]["name"])
	return String(_presets[DEFAULT_ID]["name"])


static func texture_path(id: int) -> String:
	if is_valid(id):
		return String(_presets[id]["texture"])
	return String(_presets[DEFAULT_ID]["texture"])


static func texture(id: int) -> Texture2D:
	return load(texture_path(id)) as Texture2D

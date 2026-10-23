class_name LevelConfig
extends Resource

## Data model for dungeon level generation rules
## Can be saved and configured in the Inspector as .tres files

@export var level_number: int = 1
@export var level_title: String = "Haunted Chamber"
@export var room_count: int = 5
@export var cpu_overload_speed_multiplier: float = 1.0
@export var mandatory_bug_type: String = "fake_wall"
@export var available_entities: Array[EntityData] = []

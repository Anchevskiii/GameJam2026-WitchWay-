class_name EntityData
extends Resource

## Data model for monster configurations and stats
## Can be saved and configured in the Inspector as .tres files

@export var entity_name: String = "Entity"
@export var move_speed: float = 70.0
@export var scare_amount: float = 20.0
@export var scare_rate_per_sec: float = 15.0
@export var detection_radius: float = 180.0
@export var can_pass_through_walls: bool = false
@export var texture: Texture2D

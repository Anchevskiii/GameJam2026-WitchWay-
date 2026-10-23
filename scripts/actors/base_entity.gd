class_name BaseEntity
extends CharacterBody2D

## Base class for horror dungeon entities and monsters
## Attached to: CharacterBody2D in scenes/actors/base_entity.tscn

@export var entity_name: String = "Spooky Entity"
@export var move_speed: float = 60.0
@export var detection_range: float = 200.0
@export var stop_distance: float = 28.0
@export var can_pass_through_walls: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var scare_source: ScareSource = $ScareSource

var _target_player: CharacterBody2D = null
var _is_active: bool = true

func _ready() -> void:
	EventBus.game_over_triggered.connect(_on_game_over)
	if scare_source:
		scare_source.source_name = entity_name

func _physics_process(delta: float) -> void:
	if not _is_active or GameManager.is_game_over:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	_find_player()
	_handle_movement(delta)
	move_and_slide()

func _find_player() -> void:
	if not _target_player:
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_target_player = players[0] as CharacterBody2D

func _handle_movement(delta: float) -> void:
	if not _target_player:
		velocity = Vector2.ZERO
		return
	
	var dist: float = global_position.distance_to(_target_player.global_position)
	if dist <= detection_range:
		var dir: Vector2 = (_target_player.global_position - global_position).normalized()
		if dist > stop_distance:
			velocity = velocity.lerp(dir * move_speed, 8.0 * delta)
		else:
			# Hover gently near player without blocking or pushing
			velocity = velocity.lerp(Vector2.ZERO, 6.0 * delta)
			
		if sprite and dir.x != 0.0:
			sprite.flip_h = dir.x < 0.0
	else:
		velocity = velocity.lerp(Vector2.ZERO, 6.0 * delta)

func _on_game_over() -> void:
	_is_active = false

class_name PlayerController
extends CharacterBody2D

## Top-down player controller with directional flashlight following player movement
## Attached to: CharacterBody2D in scenes/actors/player.tscn

@export_group("Movement")
@export var walk_speed: float = 175.0
@export var sprint_speed: float = 250.0
@export var acceleration: float = 20.0
@export var friction: float = 24.0

@export_group("Flashlight")
@export var turn_speed: float = 18.0
@export var flashlight_energy: float = 1.4
@export var enable_flashlight_flicker: bool = true
@export var flicker_min_interval: float = 6.0
@export var flicker_max_interval: float = 14.0

@onready var flashlight_pivot: Node2D = $FlashlightPivot
@onready var flashlight_beam: PointLight2D = $FlashlightPivot/FlashlightBeam
@onready var player_sprite: Sprite2D = $PlayerSprite
@onready var camera: Camera2D = $Camera2D

var _facing_direction: Vector2 = Vector2.DOWN
var _is_flashlight_on: bool = true
var _can_move: bool = true

var _flicker_timer: float = 0.0
var _is_flickering: bool = false
var _flicker_duration: float = 0.0

func _ready() -> void:
	add_to_group("player")
	EventBus.game_over_triggered.connect(_on_game_over)
	_reset_flicker_timer()
	_update_flashlight_state()
	if flashlight_pivot:
		flashlight_pivot.rotation = _facing_direction.angle()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_flashlight"):
		_is_flashlight_on = not _is_flashlight_on
		_update_flashlight_state()

func _physics_process(delta: float) -> void:
	if not _can_move:
		velocity = velocity.lerp(Vector2.ZERO, friction * delta)
		move_and_slide()
		return
	
	_handle_movement(delta)
	_handle_direction(delta)
	_handle_flashlight_flicker(delta)
	move_and_slide()

func _handle_movement(delta: float) -> void:
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var is_sprinting: bool = Input.is_action_pressed("sprint")
	var target_speed: float = sprint_speed if is_sprinting else walk_speed
	
	if input_vector != Vector2.ZERO:
		velocity = velocity.lerp(input_vector.normalized() * target_speed, acceleration * delta)
		_facing_direction = input_vector.normalized()
	else:
		velocity = velocity.lerp(Vector2.ZERO, friction * delta)

func _handle_direction(delta: float) -> void:
	if not flashlight_pivot:
		return
	
	var target_angle: float = _facing_direction.angle()
	flashlight_pivot.rotation = lerp_angle(flashlight_pivot.rotation, target_angle, turn_speed * delta)
	
	if player_sprite:
		player_sprite.rotation = lerp_angle(player_sprite.rotation, target_angle, turn_speed * delta)

func _handle_flashlight_flicker(delta: float) -> void:
	if not enable_flashlight_flicker or not _is_flashlight_on or not flashlight_beam:
		return
	
	if _is_flickering:
		_flicker_duration -= delta
		if _flicker_duration <= 0.0:
			_is_flickering = false
			flashlight_beam.energy = flashlight_energy
			_reset_flicker_timer()
		else:
			# Random subtle jitter around 50-75% energy, never completely zero
			flashlight_beam.energy = flashlight_energy * randf_range(0.45, 0.75)
	else:
		_flicker_timer -= delta
		if _flicker_timer <= 0.0:
			_is_flickering = true
			_flicker_duration = randf_range(0.08, 0.18)

func _reset_flicker_timer() -> void:
	_flicker_timer = randf_range(flicker_min_interval, flicker_max_interval)

func _update_flashlight_state() -> void:
	if flashlight_beam:
		flashlight_beam.enabled = _is_flashlight_on
		flashlight_beam.energy = flashlight_energy

func _on_game_over() -> void:
	_can_move = false

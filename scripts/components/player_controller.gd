class_name PlayerController
extends CharacterBody2D

## Top-Down Player Controller with dynamic 2D flashlight and camera tracking
## Attached to: CharacterBody2D in scenes/actors/player.tscn

@export_group("Movement")
@export var walk_speed: float = 160.0
@export var sprint_speed: float = 230.0
@export var acceleration: float = 18.0
@export var friction: float = 20.0

@export_group("Flashlight")
@export var flashlight_turn_speed: float = 12.0
@export var flashlight_energy: float = 1.0

@onready var flashlight_pivot: Node2D = $FlashlightPivot
@onready var flashlight_cone: PointLight2D = $FlashlightPivot/FlashlightCone
@onready var ambient_body_light: PointLight2D = $AmbientBodyLight
@onready var sprite: Sprite2D = $Sprite2D
@onready var camera: Camera2D = $Camera2D

var _is_flashlight_on: bool = true
var _can_move: bool = true

func _ready() -> void:
	EventBus.game_over_triggered.connect(_on_game_over)
	_update_flashlight_state()

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
	_handle_flashlight_aim(delta)
	move_and_slide()

func _handle_movement(delta: float) -> void:
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var is_sprinting: bool = Input.is_action_pressed("sprint")
	var target_speed: float = sprint_speed if is_sprinting else walk_speed
	
	if input_vector != Vector2.ZERO:
		velocity = velocity.lerp(input_vector.normalized() * target_speed, acceleration * delta)
		# Face direction horizontally
		if input_vector.x != 0.0:
			sprite.flip_h = input_vector.x < 0.0
	else:
		velocity = velocity.lerp(Vector2.ZERO, friction * delta)

func _handle_flashlight_aim(delta: float) -> void:
	if not flashlight_pivot:
		return
	var mouse_pos: Vector2 = get_global_mouse_position()
	var target_angle: float = (mouse_pos - global_position).angle()
	flashlight_pivot.rotation = lerp_angle(flashlight_pivot.rotation, target_angle, flashlight_turn_speed * delta)

func _update_flashlight_state() -> void:
	if flashlight_cone:
		flashlight_cone.enabled = _is_flashlight_on

func _on_game_over() -> void:
	_can_move = false

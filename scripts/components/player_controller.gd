class_name PlayerController
extends CharacterBody2D

## Top-down player controller with directional flashlight and the rubber chicken scare tool.
## Attached to: CharacterBody2D in scenes/actors/player.tscn

const PUDDLE_TEXTURE: Texture2D = preload("res://assets/sprites/objects/puddle.png")

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

@export_group("Rubber Chicken (scare tool)")
## How far the honk reaches, in pixels.
@export var honk_range: float = 120.0
## Half-width of the honk cone in degrees (60 = a 120 degree cone in front of the player).
@export var honk_half_angle: float = 60.0
## Seconds between honks, so the player can't spam.
@export var honk_cooldown: float = 0.7

@onready var flashlight_pivot: Node2D = $FlashlightPivot
@onready var flashlight_beam: PointLight2D = $FlashlightPivot/FlashlightBeam
@onready var player_sprite: Sprite2D = $PlayerSprite
@onready var camera: Camera2D = $Camera2D

var _facing_direction: Vector2 = Vector2.DOWN
var _is_flashlight_on: bool = true
## Rooms can break the flashlight ("flashlight texture failed to load").
var _flashlight_available: bool = true
var _can_move: bool = true
var _honk_cooldown_left: float = 0.0

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


func _physics_process(delta: float) -> void:
	if not _can_move:
		velocity = velocity.lerp(Vector2.ZERO, friction * delta)
		move_and_slide()
		return

	# Input is polled here (not _unhandled_input) so it also works inside the world SubViewport.
	if Input.is_action_just_pressed("toggle_flashlight"):
		_is_flashlight_on = not _is_flashlight_on
		_update_flashlight_state()
	_honk_cooldown_left -= delta
	if Input.is_action_just_pressed("scare") and _honk_cooldown_left <= 0.0:
		_honk()

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
		flashlight_beam.enabled = _is_flashlight_on and _flashlight_available
		flashlight_beam.energy = flashlight_energy


## Called by the Room. Darkness rooms turn the flashlight off.
func set_flashlight_available(available: bool) -> void:
	_flashlight_available = available
	_update_flashlight_state()


# ---------------------------------------------------------------- rubber chicken

func _honk() -> void:
	_honk_cooldown_left = honk_cooldown
	AudioManager.play("honk", 0.0, randf_range(0.9, 1.15))
	EventBus.player_honked.emit(global_position, _facing_direction, honk_range, honk_half_angle)
	_spawn_honk_effect()


## A fading cone + "HONK!" text so the player can see the honk's reach.
func _spawn_honk_effect() -> void:
	var effect := Node2D.new()
	effect.global_position = global_position
	effect.z_index = 15

	var cone := Polygon2D.new()
	var points: PackedVector2Array = [Vector2.ZERO]
	for i in 9:
		var angle: float = deg_to_rad(lerpf(-honk_half_angle, honk_half_angle, i / 8.0))
		points.append(Vector2.RIGHT.rotated(angle) * honk_range)
	cone.polygon = points
	cone.color = Color(1.0, 0.95, 0.4, 0.25)
	cone.rotation = _facing_direction.angle()
	effect.add_child(cone)

	var label := Label.new()
	label.text = "HONK!"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.position = _facing_direction * 30.0 - Vector2(22, 10)
	effect.add_child(label)

	get_parent().add_child(effect)
	var tween: Tween = effect.create_tween()
	tween.tween_property(effect, "modulate:a", 0.0, 0.35)
	tween.parallel().tween_property(label, "position:y", label.position.y - 14.0, 0.35)
	tween.tween_callback(effect.queue_free)


# ---------------------------------------------------------------- game over

func _on_game_over() -> void:
	_can_move = false
	var puddle := Sprite2D.new()
	puddle.texture = PUDDLE_TEXTURE
	puddle.global_position = global_position + Vector2(0, 6)
	puddle.z_index = -1
	puddle.scale = Vector2.ZERO
	get_parent().add_child(puddle)
	puddle.create_tween().tween_property(puddle, "scale", Vector2.ONE * 2.0, 1.2)
	AudioManager.play("sad_trombone")
	Narrator.say_event("death", {}, true)

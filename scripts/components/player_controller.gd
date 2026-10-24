class_name PlayerController
extends CharacterBody2D

## Top-down player controller: movement, flashlight, the masked BOO and hiding.
##   SPACE  BOO! Only scares monsters that don't see you coming (from behind / around a corner).
##   E      hide in a nearby cupboard/couch (monsters can't see you). E again sneaks out,
##          SPACE jumps out with a lunge - a jump-out ALWAYS surprises and reaches further.
## The walk animation is handled by the StumbleAnimator child node.
## Attached to: CharacterBody2D in scenes/actors/player.tscn

const PUDDLE_TEXTURE: Texture2D = preload("res://assets/sprites/objects/puddle.png")
const MASK_TEXTURE: Texture2D = preload("res://assets/sprites/characters/player_guy_mask.png")

@export_group("Movement")
@export var walk_speed: float = 175.0
@export var sprint_speed: float = 250.0
@export var acceleration: float = 20.0
@export var friction: float = 24.0

@export_group("Flashlight")
@export var turn_speed: float = 18.0
@export var flashlight_energy: float = 1.4
@export var enable_flashlight_flicker: bool = true
@export var flicker_min_interval: float = 2.5
@export var flicker_max_interval: float = 6.0

@export_group("Mask scare")
## How close a monster must be for a BOO to reach it, in pixels.
@export var boo_range: float = 80.0
## Jumping out of a hiding spot reaches further (measured from the hiding spot).
@export var jump_out_range: float = 170.0
## Speed of the lunge when jumping out of hiding.
@export var jump_out_speed: float = 520.0
## Seconds between BOOs, so the player can't spam.
@export var boo_cooldown: float = 0.8
## How long the mask stays on after a BOO.
@export var mask_time: float = 0.6

@onready var flashlight_pivot: Node2D = $FlashlightPivot
@onready var flashlight_beam: PointLight2D = $FlashlightPivot/FlashlightBeam
@onready var player_sprite: Sprite2D = $PlayerSprite
@onready var camera: Camera2D = $Camera2D
@onready var glow_light: PointLight2D = $GlowLight
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var mask_bar: ProgressBar = get_node_or_null("MaskBar")
@onready var chills_ring: PointLight2D = get_node_or_null("ChillsRing")
@onready var _normal_texture: Texture2D = player_sprite.texture

## True while hiding in a cupboard/couch. Monsters can't see a hidden player.
var is_hidden: bool = false
## True while wearing the picked-up disguise mask (6s powerup from Floor 3+).
var is_masked: bool = false
var mask_time_left: float = 0.0
var _hide_spot: HideSpot = null
var _pre_hide_position: Vector2

var _facing_direction: Vector2 = Vector2.DOWN
var _is_flashlight_on: bool = true
## Rooms can break the flashlight ("flashlight texture failed to load").
var _flashlight_available: bool = true
var _can_move: bool = true
var _boo_cooldown_left: float = 0.0

var _flicker_timer: float = 0.0
var _is_flickering: bool = false
var _flicker_duration: float = 0.0
var _dark_still_time: float = 0.0
var _ghost_jumpscare_triggered: bool = false


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

	_handle_mask(delta)
	_handle_ghost_chills(delta)

	# Input is polled here (not _unhandled_input) so it also works inside the world SubViewport.
	if Input.is_action_just_pressed("toggle_flashlight"):
		_is_flashlight_on = not _is_flashlight_on
		_update_flashlight_state()
	_boo_cooldown_left -= delta
	if is_hidden:
		velocity = Vector2.ZERO
		if Input.is_action_just_pressed("scare"):
			_jump_out()
		elif Input.is_action_just_pressed("interact"):
			_leave_hiding_spot()
		return
	if Input.is_action_just_pressed("interact"):
		var taken: HideSpot = _occupied_hide_spot_in_reach()
		if taken:
			(taken.occupant as Npc).ambush()  # someone's already in there...
			return
		var spot: HideSpot = _nearest_hide_spot()
		if spot:
			_hide_in(spot)
			return
	if Input.is_action_just_pressed("scare") and _boo_cooldown_left <= 0.0:
		_boo(global_position, boo_range, false)

	_handle_movement(delta)
	_handle_direction(delta)
	_handle_flashlight_flicker(delta)
	move_and_slide()


func _handle_mask(delta: float) -> void:
	if not is_masked:
		return
	mask_time_left -= delta
	if mask_bar:
		mask_bar.visible = true
		mask_bar.value = mask_time_left
	# While wearing the disguise mask, kids nearby get startled on sight!
	for kid in get_tree().get_nodes_in_group("kids"):
		var k: Kid = kid as Kid
		if k.is_scareable() and global_position.distance_to(k.global_position) < 65.0:
			k.get_scared(global_position, "a masked figure")
	if mask_time_left <= 0.0:
		is_masked = false
		player_sprite.texture = _normal_texture
		if mask_bar:
			mask_bar.visible = false


## Called only when picking up a MaskPickup item in the world (Floor 3+).
func activate_disguise_mask(duration: float = 6.0) -> void:
	is_masked = true
	mask_time_left = duration
	player_sprite.texture = MASK_TEXTURE
	if mask_bar:
		mask_bar.max_value = duration
		mask_bar.value = duration
		mask_bar.visible = true


func _handle_ghost_chills(delta: float) -> void:
	var ghost_near: bool = false
	for ghost in get_tree().get_nodes_in_group("ghosts"):
		if is_instance_valid(ghost) and global_position.distance_to((ghost as Node2D).global_position) < 180.0:
			ghost_near = true
			break

	var in_dark: bool = not _is_flashlight_on or not _flashlight_available
	if velocity.length() < 12.0 and in_dark and not is_hidden and not GameManager.is_safe_room:
		_dark_still_time += delta
	else:
		_dark_still_time = maxf(0.0, _dark_still_time - delta * 2.0)
		_ghost_jumpscare_triggered = false

	var show_chills: bool = ghost_near or _dark_still_time > 2.0
	if chills_ring:
		chills_ring.visible = show_chills
		if show_chills:
			chills_ring.energy = 0.5 + sin(Time.get_ticks_msec() * 0.007) * 0.4

	if _dark_still_time >= 6.0 and not _ghost_jumpscare_triggered:
		_ghost_jumpscare_triggered = true
		AudioManager.play("cackle", 2.0, randf_range(0.9, 1.1))
		GameManager.scare_player(30.0, "Darkness Apparition", true)


func is_facing_target(target_pos: Vector2) -> bool:
	if not _is_flashlight_on or not _flashlight_available:
		return false
	var dir_to_target: Vector2 = (target_pos - global_position).normalized()
	return _facing_direction.dot(dir_to_target) > 0.45


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

	# The sprite is a side-on pixel guy: just face left/right. StumbleAnimator does the walk.
	if player_sprite and absf(_facing_direction.x) > 0.1:
		player_sprite.flip_h = _facing_direction.x < 0.0


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
			if randf() < 0.25:
				flashlight_beam.energy = 0.0
			else:
				flashlight_beam.energy = flashlight_energy * randf_range(0.3, 0.75)
	else:
		_flicker_timer -= delta
		if _flicker_timer <= 0.0:
			_is_flickering = true
			_flicker_duration = randf_range(0.12, 0.35)


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


# ---------------------------------------------------------------- mask scare

func _boo(origin: Vector2, reach: float, from_hiding: bool) -> void:
	_boo_cooldown_left = boo_cooldown
	AudioManager.play("whoosh", -8.0, randf_range(0.95, 1.1))
	_put_on_mask()
	_spawn_boo_text()
	EventBus.player_booed.emit(origin, reach, from_hiding)


## Swap to the masked sprite for a moment.
func _put_on_mask() -> void:
	player_sprite.texture = MASK_TEXTURE
	get_tree().create_timer(mask_time).timeout.connect(func() -> void:
		if not is_masked:
			player_sprite.texture = _normal_texture)


func _spawn_boo_text() -> void:
	var label := Label.new()
	label.text = "BOO!"
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.position = global_position + Vector2(-32, -64)
	label.z_index = 30
	get_parent().add_child(label)
	var tween: Tween = label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 18.0, 0.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.2)
	tween.tween_callback(label.queue_free)


# ---------------------------------------------------------------- hiding

func _nearest_hide_spot() -> HideSpot:
	var best: HideSpot = null
	var best_dist: float = INF
	for spot in get_tree().get_nodes_in_group("hide_spots"):
		var hide_spot: HideSpot = spot as HideSpot
		var dist: float = global_position.distance_to(hide_spot.global_position)
		if hide_spot.is_player_in_reach() and hide_spot.is_free_for(self) and dist < best_dist:
			best = hide_spot
			best_dist = dist
	return best


## A cupboard in reach that a monster is hiding in, if any.
func _occupied_hide_spot_in_reach() -> HideSpot:
	for spot in get_tree().get_nodes_in_group("hide_spots"):
		var hide_spot: HideSpot = spot as HideSpot
		if hide_spot.occupied and hide_spot.occupant is Npc and hide_spot.is_player_in_reach():
			return hide_spot
	return null


func _hide_in(spot: HideSpot) -> void:
	is_hidden = true
	_hide_spot = spot
	_pre_hide_position = global_position
	spot.set_occupied(true, self)  # your head peeks out now and then
	velocity = Vector2.ZERO
	player_sprite.visible = false
	flashlight_beam.enabled = false
	glow_light.energy = 0.35  # a faint glow so dark rooms don't go fully black
	collision_shape.set_deferred("disabled", true)
	global_position = spot.global_position


func _unhide() -> void:
	is_hidden = false
	_hide_spot.set_occupied(false)
	player_sprite.visible = true
	glow_light.energy = 0.9
	_update_flashlight_state()
	collision_shape.set_deferred("disabled", false)
	global_position = _pre_hide_position


func _leave_hiding_spot() -> void:
	_unhide()
	_hide_spot = null


## Burst out of hiding towards the nearest monster (or back the way you came) and BOO.
func _jump_out() -> void:
	var spot_position: Vector2 = _hide_spot.global_position
	var direction: Vector2 = (_pre_hide_position - spot_position).normalized()
	var nearest_dist: float = jump_out_range
	for npc in get_tree().get_nodes_in_group("npcs"):
		var dist: float = spot_position.distance_to((npc as Node2D).global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			direction = spot_position.direction_to((npc as Node2D).global_position)
	_unhide()
	_hide_spot = null
	_facing_direction = direction
	velocity = direction * jump_out_speed
	_boo(spot_position, jump_out_range, true)


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

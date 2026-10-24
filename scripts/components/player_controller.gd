class_name PlayerController
extends CharacterBody2D

## Top-down player controller: movement, flashlight, the masked BOO and hiding.
##   SPACE  BOO! Only scares monsters that don't see you coming (from behind / around a corner).
##   E      hide in a nearby cupboard/couch (monsters can't see you) or hold E to search a drawer.
##          E again sneaks out of hiding, SPACE jumps out with a lunge - a jump-out ALWAYS surprises.
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
@export var flicker_min_interval: float = 6.0
@export var flicker_max_interval: float = 14.0

@export_group("Mask scare")
## How close a monster must be for a BOO to reach it, in pixels.
@export var boo_range: float = 105.0
## Jumping out of a hiding spot reaches further (measured from the hiding spot).
@export var jump_out_range: float = 190.0
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
## True while wearing the picked-up disguise mask powerup.
var is_masked: bool = false
var mask_time_left: float = 0.0
var _face_mask: Sprite2D = null
var _mask_type: int = 0
var _hide_spot: HideSpot = null
var _pre_hide_position: Vector2

var _facing_direction: Vector2 = Vector2.DOWN
var _is_flashlight_on: bool = true
## Rooms can break the flashlight ("flashlight texture failed to load").
var _flashlight_available: bool = true
var _can_move: bool = true
var _boo_cooldown_left: float = 0.0
## Seconds left stuck in a bear trap.
var _snared_left: float = 0.0
## The drawer/cabinet being searched (E held), or null.
var _searching: Searchable = null
var _search_time: float = 0.0
## The single best interactable target (HideSpot or Searchable) currently focused by the player.
var _active_interact_target: Node2D = null

var _flicker_timer: float = 0.0
var _is_flickering: bool = false
var _flicker_duration: float = 0.0


func _ready() -> void:
	add_to_group("player")
	if flashlight_beam:
		flashlight_beam.texture = _beam_texture()
		flashlight_beam.texture_scale = 2.0
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
	_handle_ghost_chills()
	_update_best_interact_target()

	# Input is polled here (not _unhandled_input) so it also works inside the world SubViewport.
	if Input.is_action_just_pressed("toggle_flashlight"):
		_is_flashlight_on = not _is_flashlight_on
		_update_flashlight_state()
	_boo_cooldown_left -= delta
	if _snared_left > 0.0:
		_snared_left -= delta
		velocity = Vector2.ZERO
		if Input.is_action_just_pressed("scare") and _boo_cooldown_left <= 0.0:
			_boo(global_position, boo_range, false)  # can't run, but you can still BOO
		return
	if _searching:
		_process_search(delta)
		return
	if is_hidden:
		velocity = Vector2.ZERO
		if Input.is_action_just_pressed("scare"):
			_jump_out()
		elif Input.is_action_just_pressed("interact"):
			_leave_hiding_spot()
		return
	if Input.is_action_just_pressed("interact") and is_instance_valid(_active_interact_target):
		if _active_interact_target is HideSpot:
			var spot: HideSpot = _active_interact_target as HideSpot
			if spot.occupied and spot.occupant is Npc:
				(spot.occupant as Npc).ambush()  # someone's already in there...
			elif spot.is_free_for(self):
				_hide_in(spot)
			return
		elif _active_interact_target is Searchable:
			var drawer: Searchable = _active_interact_target as Searchable
			if not drawer.searched:
				_searching = drawer
				_search_time = 0.0
				velocity = Vector2.ZERO
				return
	if Input.is_action_just_pressed("scare") and _boo_cooldown_left <= 0.0:
		_boo(global_position, boo_range, false)

	_handle_movement(delta)
	_handle_direction(delta)
	_handle_flashlight_flicker(delta)
	move_and_slide()


## Selects at most ONE interactable object (either a HideSpot or a Searchable) that is in reach,
## choosing the one the player is closest to and facing towards.
func _update_best_interact_target() -> void:
	var best_target: Node2D = null
	var best_score: float = INF

	if not is_hidden and _searching == null:
		for node in get_tree().get_nodes_in_group("hide_spots"):
			var spot: HideSpot = node as HideSpot
			if not spot.is_player_in_reach():
				spot.is_active_target = false
				continue
			var valid: bool = spot.is_free_for(self) or (spot.occupied and spot.occupant is Npc)
			if not valid:
				spot.is_active_target = false
				continue
			var score: float = _interaction_score(spot.global_position)
			if score < best_score:
				best_score = score
				best_target = spot

		for node in get_tree().get_nodes_in_group("searchables"):
			var drawer: Searchable = node as Searchable
			if drawer.searched or not drawer.is_player_in_reach():
				drawer.is_active_target = false
				continue
			var score: float = _interaction_score(drawer.global_position)
			if score < best_score:
				best_score = score
				best_target = drawer

	_active_interact_target = best_target
	for node in get_tree().get_nodes_in_group("hide_spots"):
		(node as HideSpot).is_active_target = (node == best_target)
	for node in get_tree().get_nodes_in_group("searchables"):
		(node as Searchable).is_active_target = (node == best_target)


## Lower score = better match. Combines distance with an alignment bonus for the direction the player faces.
func _interaction_score(target_pos: Vector2) -> float:
	var to_target: Vector2 = target_pos - global_position
	var dist: float = to_target.length()
	if dist < 0.01:
		return 0.0
	var alignment: float = _facing_direction.dot(to_target / dist)  # -1 (behind) to +1 (directly in front)
	return dist - alignment * 18.0


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
		_set_face_mask(false)
		if mask_bar:
			mask_bar.visible = false


## Shows the current mask over the player's face (the jack-o'-lantern covers the whole head).
func _set_face_mask(on: bool, type: int = -1) -> void:
	if type >= 0:
		_mask_type = type
	if _face_mask == null:
		_face_mask = Sprite2D.new()
		_face_mask.z_index = 1
		player_sprite.add_child(_face_mask)
	_face_mask.texture = MaskTypes.texture(_mask_type)
	_face_mask.position = Vector2(0, MaskTypes.offset_y(_mask_type))
	_face_mask.visible = on


## Called when picking up a MaskPickup item in the world.
func activate_disguise_mask(duration: float = 10.0, type: int = 0) -> void:
	is_masked = true
	mask_time_left = duration
	_set_face_mask(true, type)
	if mask_bar:
		mask_bar.max_value = duration
		mask_bar.value = duration
		mask_bar.visible = true


func _handle_ghost_chills() -> void:
	if chills_ring == null:
		return
	var ghost_near: bool = false
	for ghost in get_tree().get_nodes_in_group("ghosts"):
		if is_instance_valid(ghost) and global_position.distance_to((ghost as Node2D).global_position) < 160.0:
			ghost_near = true
			break
	chills_ring.visible = ghost_near
	if ghost_near:
		chills_ring.energy = 0.45 + sin(Time.get_ticks_msec() * 0.007) * 0.3


func is_facing_target(target_pos: Vector2) -> bool:
	if not _is_flashlight_on or not _flashlight_available:
		return false
	var dir_to_target: Vector2 = (target_pos - global_position).normalized()
	return _facing_direction.dot(dir_to_target) > 0.48


## Returns true if the target position is illuminated by the player's flashlight beam
## or right next to the player's personal glow.
func is_illuminating(target_pos: Vector2) -> bool:
	var dist: float = global_position.distance_to(target_pos)
	if dist <= 44.0:
		return true
	if not _is_flashlight_on or not _flashlight_available or dist > 220.0:
		return false
	if _is_flickering and flashlight_beam and flashlight_beam.energy <= 0.05:
		return false
	var dir_to_target: Vector2 = (target_pos - global_position).normalized()
	return _facing_direction.dot(dir_to_target) > 0.48


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
			# Random subtle jitter around 45-75% energy, never completely zero
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


# ---------------------------------------------------------------- mask scare

func _boo(origin: Vector2, reach: float, from_hiding: bool) -> void:
	_boo_cooldown_left = boo_cooldown
	AudioManager.play("whoosh", -8.0, randf_range(0.95, 1.1))
	_put_on_mask()
	_spawn_boo_text()
	EventBus.player_booed.emit(origin, reach, from_hiding)


## Swap to the masked sprite for a moment.
func _put_on_mask() -> void:
	_set_face_mask(true, MaskTypes.random_type() if not is_masked else _mask_type)
	get_tree().create_timer(mask_time).timeout.connect(func() -> void:
		if not is_masked:
			_set_face_mask(false))


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


# ---------------------------------------------------------------- traps & searching

## Stuck (bear trap) for `seconds`: no walking, BOO still works.
func snare(seconds: float) -> void:
	_snared_left = maxf(_snared_left, seconds)
	velocity = Vector2.ZERO


func is_snared() -> bool:
	return _snared_left > 0.0


## Holding E at a drawer: stand still until it's searched. Let go (or get scared off) = stop.
func _process_search(delta: float) -> void:
	velocity = Vector2.ZERO
	if not Input.is_action_pressed("interact") or not _searching.is_player_in_reach() or _searching.searched:
		_searching.progress = 0.0
		_searching = null
		return
	_search_time += delta
	_searching.progress = clampf(_search_time / _searching.search_time, 0.0, 1.0)
	if _search_time >= _searching.search_time:
		var drawer: Searchable = _searching
		_searching = null
		drawer.open()


# ---------------------------------------------------------------- hiding

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
	glow_light.energy = 0.55
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


static var _beam_tex: ImageTexture = null


## A wide soft cone that starts as a glow around the whole body instead of a single point.
static func _beam_texture() -> ImageTexture:
	if _beam_tex != null:
		return _beam_tex
	var size: int = 256
	var c: int = size / 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for py in size:
		for px in size:
			var u: float = float(px - c)
			var v: float = float(py - c)
			var body: float = clampf(1.0 - Vector2(u, v).length() / 17.0, 0.0, 1.0) * 0.7
			var cone: float = 0.0
			if u > 0.0:
				var half: float = 14.0 + u * 0.62
				var side: float = clampf(1.0 - absf(v) / half, 0.0, 1.0)
				side = side * side * (3.0 - 2.0 * side)
				var reach: float = clampf(1.0 - u / float(c), 0.0, 1.0)
				cone = side * pow(reach, 0.9) * clampf(u / 8.0 + 0.45, 0.0, 1.0)
			var val: float = maxf(body, cone)
			img.set_pixel(px, py, Color(val, val, val, 1.0))
	_beam_tex = ImageTexture.create_from_image(img)
	return _beam_tex

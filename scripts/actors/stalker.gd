class_name Stalker
extends Node2D

## The thing that wakes up when you take the last key. It drifts straight through walls
## towards you, a little faster the longer the chase goes on, and whispers as it gets close.
##   Hide (E)   it loses you, searches briefly, then wanders away to patrol elsewhere!
##              If you come out when it's nearby (or make noise / get spotted), it chases again.
##   BOO        stuns it for a few seconds - buys time, doesn't kill it.
##   Touch      big jumpscare and a big sanity hit; then it backs off and comes again.
## Spawned by Room when EventBus.house_awakened fires.

const TEXTURE: Texture2D = preload("res://assets/sprites/characters/stalker.png")
const GLOW_TEXTURE: Texture2D = preload("res://assets/sprites/environment/light_radial.tres")

## Pixels per second at the start of the chase, and the most it ever reaches.
@export var start_speed: float = 95.0
@export var max_speed: float = 140.0
## Speed gained per second of chasing.
@export var speed_ramp: float = 1.5
@export var touch_damage: float = 30.0
@export var touch_range: float = 22.0
@export var stun_time: float = 3.5
## After a touch it reappears this far away.
@export var retreat_distance: float = 420.0
## Sight / hearing range when it has lost the player and is patrolling away.
@export var reacquire_range: float = 240.0

var _player: PlayerController = null
var _speed: float = 0.0
var _stun_left: float = 0.0
var _pause_left: float = 1.5  # a beat to let the player see it before it moves
var _last_seen: Vector2
var _whisper_left: float = 2.0
var _sprite: Sprite2D

## True when the Stalker actively knows where the player is; false after the player hides and it wanders off.
var _tracking_player: bool = true
var _hidden_timer: float = 0.0
var _roam_target: Vector2 = Vector2.ZERO
var _roam_timer: float = 0.0


func _ready() -> void:
	add_to_group("stalker")
	_speed = start_speed
	_sprite = Sprite2D.new()
	_sprite.texture = TEXTURE
	_sprite.offset = Vector2(0, -TEXTURE.get_height() * 0.5 + 6.0)
	add_child(_sprite)
	var eyes := PointLight2D.new()  # glowing red eyes: you see it even in the dark
	eyes.texture = GLOW_TEXTURE
	eyes.texture_scale = 0.35
	eyes.energy = 1.4
	eyes.color = Color(1.0, 0.15, 0.1)
	eyes.position = Vector2(0, -TEXTURE.get_height() + 16.0)
	add_child(eyes)
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	if _player:
		_last_seen = _player.global_position
	EventBus.player_booed.connect(_on_player_booed)
	EventBus.noise_made.connect(_on_noise_made)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 1.2)


func _process(delta: float) -> void:
	if _player == null or GameManager.is_game_over:
		return
	if _stun_left > 0.0:
		_stun_left -= delta
		_sprite.visible = randf() > 0.3  # flickering, "not loaded"
		return
	_sprite.visible = true
	if _pause_left > 0.0:
		_pause_left -= delta
		return

	var dist: float = global_position.distance_to(_player.global_position)
	var player_concealed: bool = _player.is_hidden or _player.is_masked

	var target: Vector2
	var speed: float = _speed
	if player_concealed:
		_hidden_timer += delta
		if _hidden_timer < 1.2:
			# Briefly checks where it last saw you...
			target = _last_seen + Vector2(sin(Time.get_ticks_msec() / 500.0), cos(Time.get_ticks_msec() / 650.0)) * 36.0
			speed *= 0.45
		else:
			# ...then gives up and wanders away so it never camps the wardrobe!
			if _tracking_player or _roam_timer <= 0.0 or global_position.distance_to(_roam_target) < 24.0:
				_tracking_player = false
				_pick_away_roam_target()
			_roam_timer -= delta
			target = _roam_target
			speed = start_speed * 0.78
	else:
		_hidden_timer = 0.0
		if not _tracking_player:
			# Roaming after losing you: re-aggros if it sees you, hears you sprint, or you get close
			var sprinting_near: bool = _player.velocity.length() > _player.walk_speed * 1.15 and dist <= reacquire_range * 1.35
			if dist <= reacquire_range or sprinting_near or _has_clear_sight_to_player(reacquire_range * 1.4):
				_tracking_player = true
				_speed = start_speed
				AudioManager.play("whisper", 0.0)
			else:
				_roam_timer -= delta
				if _roam_timer <= 0.0 or global_position.distance_to(_roam_target) < 24.0:
					_pick_away_roam_target()
				target = _roam_target
				speed = start_speed * 0.65
		if _tracking_player:
			_last_seen = _player.global_position
			target = _last_seen
			_speed = minf(_speed + speed_ramp * delta, max_speed)
			speed = _speed

	global_position = global_position.move_toward(target, speed * delta)
	_sprite.flip_h = target.x < global_position.x

	_whisper_left -= delta
	if _whisper_left <= 0.0 and dist < 320.0:
		_whisper_left = randf_range(2.5, 4.5)
		AudioManager.play("whisper", linear_to_db(clampf(1.0 - dist / 320.0, 0.15, 1.0)))
	if dist <= touch_range and not _player.is_hidden:
		_touch()


## Picks a patrol point well away from the hiding player so the player has room to sneak out.
func _pick_away_roam_target() -> void:
	_roam_timer = randf_range(4.0, 6.5)
	var away_dir: Vector2 = (_player.global_position.direction_to(global_position) if _player else Vector2.RIGHT)
	if away_dir.length_squared() < 0.01:
		away_dir = Vector2.RIGHT.rotated(randf() * TAU)
	away_dir = away_dir.rotated(randf_range(-0.9, 0.9)).normalized()
	_roam_target = (_player.global_position if _player else global_position) + away_dir * randf_range(220.0, 340.0)


func _has_clear_sight_to_player(max_dist: float) -> bool:
	if _player == null or global_position.distance_to(_player.global_position) > max_dist:
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, _player.global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Heard a creaky floorboard, bear trap, or drawer scare: immediately comes to investigate!
func _on_noise_made(at: Vector2, radius: float) -> void:
	if _player == null or GameManager.is_game_over:
		return
	if global_position.distance_to(at) <= maxf(radius * 1.5, 420.0):
		_last_seen = at
		_roam_target = at
		_roam_timer = 5.0
		if not _player.is_hidden and not _player.is_masked:
			_tracking_player = true


func _touch() -> void:
	EventBus.jumpscare_requested.emit("stalker", touch_damage)
	# Back off to somewhere away from the player, then come again.
	global_position = _player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * retreat_distance
	_pause_left = 2.5
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 1.5)


func _on_player_booed(origin: Vector2, boo_range: float, _from_hiding: bool) -> void:
	if global_position.distance_to(origin) <= boo_range * 1.2 and _stun_left <= 0.0:
		_stun_left = stun_time
		AudioManager.play("glitch", -2.0)
		FloatingText.spawn(self, global_position + Vector2(0, -60), "STUNNED", Color(0.7, 0.5, 1.0), 18)


func is_stunned() -> bool:
	return _stun_left > 0.0

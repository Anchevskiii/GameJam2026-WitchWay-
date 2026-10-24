class_name Stalker
extends Node2D

## The thing that wakes up when you take the last key. It drifts straight through walls
## towards you, a little faster the longer the chase goes on, and whispers as it gets close.
##   Hide (E)   it loses you and drifts around where it last saw you.
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

var _player: PlayerController = null
var _speed: float = 0.0
var _stun_left: float = 0.0
var _pause_left: float = 1.5  # a beat to let the player see it before it moves
var _last_seen: Vector2
var _whisper_left: float = 2.0
var _sprite: Sprite2D


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

	var target: Vector2
	var speed: float = _speed
	if _player.is_hidden:
		# Lost you: drift around the spot it last saw you.
		target = _last_seen + Vector2(sin(Time.get_ticks_msec() / 700.0), cos(Time.get_ticks_msec() / 900.0)) * 60.0
		speed *= 0.4
	else:
		_last_seen = _player.global_position
		target = _last_seen
		_speed = minf(_speed + speed_ramp * delta, max_speed)
	global_position = global_position.move_toward(target, speed * delta)
	_sprite.flip_h = target.x < global_position.x

	var dist: float = global_position.distance_to(_player.global_position)
	_whisper_left -= delta
	if _whisper_left <= 0.0 and dist < 320.0:
		_whisper_left = randf_range(2.5, 4.5)
		AudioManager.play("whisper", linear_to_db(clampf(1.0 - dist / 320.0, 0.15, 1.0)))
	if dist <= touch_range and not _player.is_hidden:
		_touch()


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

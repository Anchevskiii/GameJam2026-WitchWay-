class_name StumbleAnimator
extends Node

## Clumsy "stumble" walk: while the body moves, the sprite rocks left and right
## around its feet with a little hop on every step. Each step picks a slightly
## different lean, so it looks like stumbling rather than marching.
## No animation frames needed - works with any single sprite.
## Attach to: a child Node of a CharacterBody2D (Player, Npc). Point `sprite_path` at its Sprite2D.

@export var sprite_path: NodePath = ^"../Sprite2D"
## Max lean to each side, in degrees.
@export var tilt_degrees: float = 12.0
## Steps per second at normal walking speed (faster when running).
@export var steps_per_second: float = 4.0
## How high (pixels) the sprite hops on each step.
@export var hop_height: float = 3.0
## Each step's lean is randomly scaled by 1 +/- this (0 = perfectly even waddle).
@export_range(0.0, 1.0) var stumble_randomness: float = 0.35
## Speed (pixels/sec) that counts as "walking normally".
@export var reference_speed: float = 175.0
## Below this speed the character counts as standing still.
@export var min_speed: float = 10.0

## Turn off while something else poses the sprite (e.g. a fainted NPC lying down).
var enabled: bool = true

var _phase: float = 0.0
var _step_tilt: float = 1.0
var _base_y: float = 0.0
var _feet: float = 0.0
var _bob: float = 0.0

@onready var _body: CharacterBody2D = get_parent() as CharacterBody2D
@onready var _sprite: Sprite2D = get_node(sprite_path) as Sprite2D


func _ready() -> void:
	_base_y = _sprite.position.y


func _process(delta: float) -> void:
	if not enabled or _sprite.texture == null:
		return

	var speed: float = _body.velocity.length() if _body else 0.0
	if speed > min_speed:
		var previous_sign: float = signf(sin(_phase))
		# One full sine cycle = two steps (left foot, right foot).
		_phase += delta * steps_per_second * PI * clampf(speed / reference_speed, 0.6, 1.8)
		if signf(sin(_phase)) != previous_sign:
			_step_tilt = 1.0 + randf_range(-stumble_randomness, stumble_randomness)
		_sprite.rotation = deg_to_rad(tilt_degrees) * _step_tilt * sin(_phase)
		_bob = hop_height * absf(cos(_phase))
	else:
		# Settle back to standing.
		_phase = 0.0
		_sprite.rotation = lerpf(_sprite.rotation, 0.0, minf(1.0, 14.0 * delta))
		_bob = lerpf(_bob, 0.0, minf(1.0, 14.0 * delta))

	_pin_to_feet()


## Rotate around the feet instead of the middle: move the texture up by half its
## height and the node down by the same amount (follows any scale changes, e.g. NPC wind-up puffing).
func _pin_to_feet() -> void:
	var height: float = _sprite.region_rect.size.y if _sprite.region_enabled else float(_sprite.texture.get_height())
	var half_height: float = height * 0.5
	_sprite.offset.y = -half_height
	_sprite.position.y = _base_y + half_height * absf(_sprite.scale.y) - _bob

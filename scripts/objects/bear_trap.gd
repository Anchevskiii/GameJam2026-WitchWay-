class_name BearTrap
extends FloorTrap

## A bear trap. Step on it and it snaps shut: you're stuck for a moment, it hurts (sanity)
## and the clang brings every monster nearby. It pries itself open again after a while.
## You can see it - in the dark only in your flashlight - so watch where you walk.

const OPEN_TEXTURE: Texture2D = preload("res://assets/sprites/objects/bear_trap.png")
const SHUT_TEXTURE: Texture2D = preload("res://assets/sprites/objects/bear_trap_shut.png")

@export var damage: float = 12.0
## Seconds the player is stuck.
@export var hold_time: float = 1.6
## Seconds until it can snap again.
@export var rearm_time: float = 10.0
@export var noise_radius: float = 280.0

var _sprite: Sprite2D
var _armed: bool = true


func _ready() -> void:
	super._ready()
	_sprite = _add_floor_sprite(OPEN_TEXTURE)


func _on_stepped() -> void:
	if not _armed:
		return
	_armed = false
	_sprite.texture = SHUT_TEXTURE
	AudioManager.play("snap", 2.0)
	_player.snare(hold_time)
	_player.global_position = global_position  # caught right on the trap
	GameManager.scare_player(damage, "Bear Trap")
	FloatingText.spawn(self, global_position + Vector2(0, -20), "SNAP!", Color(1.0, 0.35, 0.3), 22)
	EventBus.noise_made.emit(global_position, noise_radius)
	Narrator.say_event("bear_trap")
	await get_tree().create_timer(rearm_time).timeout
	_sprite.texture = OPEN_TEXTURE
	_armed = true

class_name CreakyBoard
extends FloorTrap

## A loose floorboard. Harmless, but LOUD: every monster within earshot comes to see what
## made the noise. Only a few faint cracks give it away. Sneaking (hidden) never triggers it.

const CRACKS_TEXTURE: Texture2D = preload("res://assets/sprites/objects/loose_board.png")

@export var noise_radius: float = 340.0
## Seconds before the same board can creak again.
@export var cooldown: float = 3.0

var _ready_at: float = 0.0


func _ready() -> void:
	super._ready()
	_add_floor_sprite(CRACKS_TEXTURE)


func _on_stepped() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < _ready_at:
		return
	_ready_at = now + cooldown
	AudioManager.play("creak", 0.0, randf_range(0.85, 1.15))
	FloatingText.spawn(self, global_position + Vector2(0, -16), "*CREAK*", Color(0.85, 0.7, 0.5), 16)
	EventBus.noise_made.emit(global_position, noise_radius)
	Narrator.say_event("creaky_board")

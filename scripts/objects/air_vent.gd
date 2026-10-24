class_name AirVent
extends Area2D

## Air Vent hazard: placed in tight corridors or on walls.
## Proximity triggered (tripwire / laser). When crossed, blasts compressed air
## with a loud hiss/whoosh and jumpscares the player, draining sanity.

@export var scare_damage: float = 12.0
@export var blast_cooldown: float = 4.0
@export var trigger_distance: float = 64.0
@export var vent_direction: Vector2 = Vector2.DOWN

var _is_ready: bool = true
var _cooldown_timer: float = 0.0

@onready var particles: CPUParticles2D = $Particles
@onready var vent_sprite: Sprite2D = $VentSprite


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2  # Player layer
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if not _is_ready:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0:
			_is_ready = true


func _on_body_entered(body: Node2D) -> void:
	if not _is_ready or not (body is PlayerController):
		return
	_trigger_blast()


func _trigger_blast() -> void:
	_is_ready = false
	_cooldown_timer = blast_cooldown

	# Visual blast
	if particles:
		particles.emitting = true
		particles.restart()

	# Audio & Jumpscare
	AudioManager.play("whoosh", 4.0, 1.6)
	GameManager.scare_player(scare_damage, "Air Vent", true)

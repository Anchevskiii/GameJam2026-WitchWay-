class_name AirVent
extends Node2D

## Wall-Mounted Air Vent Hazard:
## Placed on wall tiles facing hallways or rooms.
## When the player walks past the wall vent in the hallway, it blasts
## pressurized cold steam/air out from the wall into the corridor,
## jumpscaring the player and draining sanity.

@export var scare_damage: float = 14.0
@export var blast_cooldown: float = 5.0
## Direction the vent faces and blows air (e.g. DOWN, UP, LEFT, RIGHT).
@export var vent_direction: Vector2 = Vector2.DOWN

var _is_ready: bool = true
var _cooldown_timer: float = 0.0

@onready var vent_sprite: Sprite2D = $VentSprite
@onready var trigger_area: Area2D = $TriggerArea
@onready var trigger_shape: CollisionShape2D = $TriggerArea/CollisionShape2D
@onready var particles: CPUParticles2D = $Particles


func _ready() -> void:
	if trigger_area:
		trigger_area.collision_layer = 4
		trigger_area.collision_mask = 2  # Player layer
		trigger_area.body_entered.connect(_on_body_entered)
	_setup_direction(vent_direction)


func _process(delta: float) -> void:
	if not _is_ready:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0:
			_is_ready = true


## Orients the vent sprite, trigger box, and steam blast particles
## to face out from the wall into the hallway.
func set_facing_direction(dir: Vector2) -> void:
	vent_direction = dir.normalized()
	_setup_direction(vent_direction)


func _setup_direction(dir: Vector2) -> void:
	if not is_inside_tree():
		return
		
	# Rotate particles direction
	if particles:
		particles.direction = dir
		particles.position = dir * 12.0
		
	# Position the trigger area out in the hallway in front of the wall
	if trigger_shape:
		trigger_shape.position = dir * 28.0
		if absf(dir.x) > absf(dir.y):
			# Horizontal blast across a vertical corridor
			(trigger_shape.shape as RectangleShape2D).size = Vector2(36, 44)
		else:
			# Vertical blast across a horizontal corridor
			(trigger_shape.shape as RectangleShape2D).size = Vector2(44, 36)

	# Rotate vent sprite slightly if blowing horizontally
	if vent_sprite:
		if absf(dir.x) > absf(dir.y):
			vent_sprite.rotation = PI * 0.5 if dir.x > 0 else -PI * 0.5
		else:
			vent_sprite.rotation = 0.0


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
	AudioManager.play("whoosh", 5.0, randf_range(1.5, 1.8))
	GameManager.scare_player(scare_damage, "Wall Air Vent", true)
	FloatingText.spawn(self, global_position + vent_direction * 24.0, "WHOOSH!", Color(0.7, 0.9, 1.0), 16)

class_name MaskPickup
extends Area2D

## Collectible disguise mask spawned in levels.
## Walking over it puts on the mask for 10 seconds (with a countdown bar under the player).
## While masked:
##   - Monsters ignore the player (you can walk right past them)
##   - Your BOO (SPACE) scares monsters even from the front!
##   - Kids get startled on sight!
## Automatically respawns after a short delay so masks are always available!

@export var mask_duration: float = 10.0
@export var respawn_time: float = 12.0

var _time: float = 0.0
var _is_collected: bool = false
var _respawn_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2  # Player layer
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _is_collected:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return

	_time += delta
	if sprite:
		sprite.position.y = sin(_time * 4.0) * 3.0


func _on_body_entered(body: Node2D) -> void:
	if _is_collected:
		return
	if body is PlayerController:
		_is_collected = true
		_respawn_timer = respawn_time
		if sprite:
			sprite.visible = false
		set_deferred("monitoring", false)
		var player: PlayerController = body as PlayerController
		player.activate_disguise_mask(mask_duration)
		FloatingText.spawn(self, global_position, "DISGUISE MASK! (10s)", Color(0.4, 0.95, 1.0), 18)
		AudioManager.play("pop", -2.0, 1.3)


func _respawn() -> void:
	_is_collected = false
	if sprite:
		sprite.visible = true
		sprite.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(sprite, "modulate:a", 1.0, 0.5)
	set_deferred("monitoring", true)

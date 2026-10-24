class_name MaskPickup
extends Area2D

## Collectible disguise mask spawned in levels (from Floor 3+).
## Walking over it puts on the mask for 6 seconds (with a countdown bar under the player).
## While masked, monsters ignore the player and kids get scared on sight!

@export var mask_duration: float = 6.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2  # Player layer
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is PlayerController:
		var player: PlayerController = body as PlayerController
		player.activate_disguise_mask(mask_duration)
		FloatingText.spawn(self, global_position, "MASK ON! (6s)", Color(0.4, 0.95, 1.0), 18)
		AudioManager.play("pop", -2.0, 1.3)
		queue_free()

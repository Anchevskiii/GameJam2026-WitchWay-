class_name KeyPickup
extends Area2D

## Antique Brass Key pickup. Unlocks locked interior doors or the level exit.

const KEY_TEX: Texture2D = preload("res://assets/sprites/items/key.png")
const GLOW_TEX: Texture2D = preload("res://assets/sprites/environment/light_radial.tres")

@onready var sprite: Sprite2D = $Sprite2D
@onready var light: PointLight2D = $PointLight2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2  # Player layer
	body_entered.connect(_on_body_entered)
	
	if light:
		light.range_item_cull_mask = 3
		light.shadow_item_cull_mask = 1


func _on_body_entered(body: Node2D) -> void:
	if body is PlayerController:
		AudioManager.play("pop", 4.0, 1.8)
		GameManager.has_exit_key = true
		FloatingText.spawn(self, global_position, "+ FOUND EXIT KEY", Color(1.0, 0.9, 0.2), 16)
		EventBus.key_collected.emit()
		queue_free()

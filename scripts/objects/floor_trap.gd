class_name FloorTrap
extends Area2D

## Base for things that go off when the player steps on a tile (bear trap, creaky board,
## jumpscare spot). Subclasses override `_on_stepped()`.
## Created by Room from its `traps` list (generated floors fill it in).

## Size of the trigger area in pixels (a bit smaller than a tile, so you can skirt past).
@export var trigger_size: Vector2 = Vector2(20, 20)

var _player: PlayerController = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # the player
	var shape := RectangleShape2D.new()
	shape.size = trigger_size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is PlayerController and not GameManager.is_game_over:
		_player = body as PlayerController
		_on_stepped()


## Override: what happens when the player steps here.
func _on_stepped() -> void:
	pass


## Helper: a sprite on the floor, under everyone.
func _add_floor_sprite(texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.z_index = -7
	add_child(sprite)
	return sprite

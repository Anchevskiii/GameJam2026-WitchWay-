class_name MaskPickup
extends Area2D

## Collectible disguise mask spawned in levels.
## Walking over it puts on the mask for 10 seconds (with a countdown bar under the player).
## While masked:
##   - Monsters ignore the player (you can walk right past them)
##   - Your BOO (SPACE) scares monsters even from the front!
##   - Kids get startled on sight!
## Once picked up it disappears completely; the Room respawns it at a new spot later.

@export var mask_duration: float = 10.0

## Emitted when the player picks this mask up (the Room spawns a new one elsewhere).
signal collected(from_position: Vector2)


var mask_type: int = 0
var _time: float = 0.0
var _is_collected: bool = false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	mask_type = MaskTypes.random_type()
	sprite.texture = MaskTypes.texture(mask_type)
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2(1.8, 1.8)
	var label: Label = get_node_or_null("Label")
	if label:
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		label.material = unshaded
		label.text = MaskTypes.NAMES[mask_type]
		label.offset_left = -60.0
		label.offset_right = 60.0
	collision_layer = 4
	collision_mask = 2  # Player layer
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _is_collected:
		return

	_time += delta
	if sprite:
		sprite.position.y = sin(_time * 4.0) * 3.0


func _on_body_entered(body: Node2D) -> void:
	if _is_collected:
		return
	if body is PlayerController:
		_is_collected = true
		set_deferred("monitoring", false)
		var player: PlayerController = body as PlayerController
		player.activate_disguise_mask(mask_duration, mask_type)
		FloatingText.spawn(self, global_position, "%s! (10s)" % MaskTypes.NAMES[mask_type], Color(0.4, 0.95, 1.0), 18)
		AudioManager.play("pop", -2.0, 1.3)
		collected.emit(global_position)
		# The whole pickup (sprite, MASK label, glow) vanishes; the Room respawns it elsewhere.
		queue_free()

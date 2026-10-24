class_name RoomDoor
extends StaticBody2D

## An interactive interior door separating rooms in the haunted house.
## When closed: blocks movement and occludes light so player cannot see into the other room.
## When opened (via E or interaction): creaks open, allowing passage and letting light through!

const DOOR_CLOSED_TEX: Texture2D = preload("res://assets/sprites/environment/interior_door.png")
const DOOR_OPEN_TEX: Texture2D = preload("res://assets/sprites/environment/interior_door_open.png")

@export var is_open: bool = false
@export var is_locked: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var occluder: LightOccluder2D = $LightOccluder2D
@onready var interact_area: Area2D = $InteractArea
@onready var prompt_label: Label = $PromptLabel

var _player_in_reach: bool = false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	
	if prompt_label:
		prompt_label.visible = false
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		prompt_label.material = unshaded
		prompt_label.add_theme_font_size_override("font_size", 12)
		prompt_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
		prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
		prompt_label.add_theme_constant_override("outline_size", 4)
		
	if interact_area:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)
		
	_update_door_state(false)


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_reach and event.is_action_pressed("interact"):
		toggle_door()


func _on_body_entered(body: Node2D) -> void:
	if body is PlayerController:
		_player_in_reach = true
		_update_prompt()


func _on_body_exited(body: Node2D) -> void:
	if body is PlayerController:
		_player_in_reach = false
		if prompt_label:
			prompt_label.visible = false


func _update_prompt() -> void:
	if not prompt_label:
		return
	if is_locked:
		prompt_label.text = "[E] Locked"
	elif is_open:
		prompt_label.text = "[E] Close Door"
	else:
		prompt_label.text = "[E] Open Door"
	prompt_label.visible = _player_in_reach


func toggle_door() -> void:
	if is_locked:
		AudioManager.play("flicker", 2.0, 0.7)
		FloatingText.spawn(self, global_position, "LOCKED", Color(1.0, 0.4, 0.4), 14)
		return
		
	is_open = not is_open
	_update_door_state(true)
	_update_prompt()


func _update_door_state(play_sound: bool = false) -> void:
	if sprite:
		sprite.texture = DOOR_OPEN_TEX if is_open else DOOR_CLOSED_TEX
	if collision_shape:
		collision_shape.set_deferred("disabled", is_open)
	if occluder:
		occluder.visible = not is_open
		
	if play_sound:
		AudioManager.play("door_creak", 3.0, randf_range(0.92, 1.08))

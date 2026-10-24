class_name Interactable
extends Area2D

## Handles player proximity and interaction via [E] key
## Attach to: Doors, cabinets, chests, items, notes

signal interacted(player: CharacterBody2D)

@export var prompt_message: String = "Press [E] to Inspect"
@export var is_single_use: bool = false
@export var is_enabled: bool = true

var _player_in_range: CharacterBody2D = null
var _has_been_used: bool = false
var _prompt_label: Label = null

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2 # Player layer
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_setup_prompt_label()

func _setup_prompt_label() -> void:
	_prompt_label = Label.new()
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_prompt_label.material = unshaded
	_prompt_label.text = prompt_message
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.position = Vector2(-75, -40)
	_prompt_label.custom_minimum_size = Vector2(150, 20)
	_prompt_label.add_theme_font_size_override("font_size", 12)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	_prompt_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05))
	_prompt_label.add_theme_constant_override("outline_size", 4)
	_prompt_label.visible = false
	_prompt_label.z_index = 80
	add_child(_prompt_label)

func _unhandled_input(event: InputEvent) -> void:
	if not is_enabled or (_has_been_used and is_single_use):
		return
	
	if _player_in_range and event.is_action_pressed("interact"):
		trigger_interaction(_player_in_range)

func trigger_interaction(player: CharacterBody2D) -> void:
	if not is_enabled:
		return
	
	if is_single_use:
		_has_been_used = true
		_update_prompt_visibility(false)
	
	interacted.emit(player)

func set_prompt(new_prompt: String) -> void:
	prompt_message = new_prompt
	if _prompt_label:
		_prompt_label.text = new_prompt

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_in_range = body as CharacterBody2D
		_update_prompt_visibility(true)

func _on_body_exited(body: Node2D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		_update_prompt_visibility(false)

func _update_prompt_visibility(is_visible: bool) -> void:
	if _prompt_label and not (_has_been_used and is_single_use):
		_prompt_label.visible = is_visible

class_name GlitchDoor
extends StaticBody2D

## Exit door mounted on the wall of the exit room.
## Activated with [E] interaction when in front of the door.
## No repetitive sound on simple touch or proximity!

const DOOR_TEXTURE: Texture2D = preload("res://assets/sprites/environment/interior_door.png")
const MISSING_TEXTURE: Texture2D = preload("res://assets/sprites/environment/missing_texture.png")

@export var requires_cpu_overload: bool = false
@export var requires_key: bool = false
@export var flicker_at: float = 50.0
@export var missing_texture_at: float = 75.0
@export var jitter_at: float = 90.0
@export var rerender_delay: float = 5.0
@export var rearm_below_load: float = 70.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var exit_area: Area2D = $ExitArea
@onready var countdown_label: Label = $CountdownLabel

var _player_in_range: bool = false
var _used: bool = false
var _gone_time_left: float = 0.0
var _is_gone: bool = false


func _ready() -> void:
	z_index = 6
	if countdown_label:
		countdown_label.visible = false
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		countdown_label.material = unshaded
		countdown_label.add_theme_font_size_override("font_size", 12)
		countdown_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
		countdown_label.add_theme_color_override("font_outline_color", Color.BLACK)
		countdown_label.add_theme_constant_override("outline_size", 4)
		
	if exit_area:
		exit_area.body_entered.connect(_on_player_entered)
		exit_area.body_exited.connect(_on_player_exited)
		
	EventBus.glitch_mode_toggled.connect(_on_glitch_mode_toggled)


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and not _used and event.is_action_pressed("interact"):
		_try_use_door()


func _process(delta: float) -> void:
	if not requires_cpu_overload:
		return

	if _is_gone:
		_gone_time_left -= delta
		if countdown_label:
			countdown_label.text = "DOOR GLITCHED! %d" % ceili(_gone_time_left)
		if _gone_time_left <= 0.0:
			_is_gone = false
			sprite.visible = true
			_update_prompt()
		return

	var load_pct: float = GameManager.current_cpu_overload
	if load_pct >= jitter_at:
		sprite.texture = MISSING_TEXTURE
		sprite.offset = Vector2(randf_range(-2.0, 2.0), randf_range(-1.0, 1.0))
	elif load_pct >= missing_texture_at:
		sprite.texture = MISSING_TEXTURE
		sprite.offset = Vector2.ZERO
	elif load_pct >= flicker_at:
		sprite.texture = DOOR_TEXTURE
		sprite.visible = randf() > 0.15
	else:
		sprite.texture = DOOR_TEXTURE
		sprite.offset = Vector2.ZERO
		sprite.visible = true


func _on_glitch_mode_toggled(active: bool) -> void:
	if not requires_cpu_overload or not active:
		return
	_is_gone = true
	_gone_time_left = rerender_delay
	sprite.visible = false
	_update_prompt()


func _on_player_entered(body: Node2D) -> void:
	if body is PlayerController:
		_player_in_range = true
		_update_prompt()


func _on_player_exited(body: Node2D) -> void:
	if body is PlayerController:
		_player_in_range = false
		if countdown_label:
			countdown_label.visible = false


func _update_prompt() -> void:
	if not countdown_label or not _player_in_range:
		return

	countdown_label.visible = true
	if requires_key and not GameManager.has_exit_key:
		countdown_label.text = "[E] Locked (Needs Key)"
		countdown_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	elif requires_key and GameManager.has_exit_key:
		countdown_label.text = "[E] Unlock Exit"
		countdown_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	elif requires_cpu_overload and not _is_gone:
		countdown_label.text = "100% GLITCH Needed"
		countdown_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	else:
		countdown_label.text = "[E] Next Floor"
		countdown_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))


func _try_use_door() -> void:
	if requires_key and not GameManager.has_exit_key:
		FloatingText.spawn(self, global_position + Vector2(0, 16), "KEY NEEDED", Color(1.0, 0.4, 0.4), 14)
		return

	if requires_cpu_overload and not _is_gone:
		FloatingText.spawn(self, global_position + Vector2(0, 16), "GLITCH DOOR CLOSED", Color(0.4, 0.8, 1.0), 14)
		return

	_used = true
	_player_in_range = false
	if countdown_label:
		countdown_label.visible = false
	EventBus.level_completed.emit()

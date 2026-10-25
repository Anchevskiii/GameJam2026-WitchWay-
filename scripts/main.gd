extends Node

## Game entry point. Keeps the HUD/menus on top and swaps rooms inside the world SubViewport.
## Attached to: the root Node of scenes/main.tscn
##
## The world lives in a SubViewport so LagController can freeze ONLY the game picture
## (fake lag) while the HUD and the narrator keep updating normally.
## WorldContainer also carries the glitch shader (scripts/fx/glitch_fx.gd), so screen
## glitches distort only the world - the HUD stays readable.

@export var fade_out_time: float = 0.95
@export var hold_black_time: float = 1.65
@export var fade_in_time: float = 1.15

@onready var world: SubViewport = $WorldContainer/World
@onready var fade_layer: CanvasLayer = $FadeLayer
@onready var fade_rect: ColorRect = $FadeLayer/FadeRect

var _is_changing_room: bool = false
var _transition_label: Label = null


func _ready() -> void:
	LagController.register_viewport(world)
	_setup_transition_label()
	EventBus.room_change_requested.connect(_on_room_change_requested)
	EventBus.level_completed.connect(_on_level_completed)
	# Fresh start, death and "Restart" all reload Main: resume at the last Living Room.
	GameManager.current_level = GameManager.checkpoint_level
	_load_room(GameManager.scene_for_level(GameManager.current_level))
	AudioManager.start_room_ambience(1.4)


func _setup_transition_label() -> void:
	_transition_label = Label.new()
	_transition_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_transition_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_transition_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_label.add_theme_font_size_override("font_size", 28)
	_transition_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85, 1.0))
	_transition_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_transition_label.add_theme_constant_override("outline_size", 6)
	_transition_label.modulate.a = 0.0
	fade_layer.add_child(_transition_label)


func _on_level_completed() -> void:
	if _is_changing_room:
		return
	AudioManager.play("creak_door", 0.5, randf_range(0.94, 1.04))
	GameManager.advance_level()
	_on_room_change_requested(GameManager.scene_for_level(GameManager.current_level))


func _on_room_change_requested(scene_path: String) -> void:
	if _is_changing_room:
		return
	_is_changing_room = true
	AudioManager.fade_out_room_ambience(fade_out_time)

	var tween: Tween = create_tween()
	# 1. Fade screen to black while room audio slowly fades out to silence
	tween.tween_property(fade_rect, "color:a", 1.0, fade_out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 2. In complete silence on the black screen, load the new room and show "Progressing to 'Floor X: Room Name'"
	tween.tween_callback(func() -> void:
		var title: String = _load_room(scene_path)
		_transition_label.text = "Progressing to 'Floor %d: %s'" % [GameManager.current_level + 1, title]
	)
	tween.tween_property(_transition_label, "modulate:a", 1.0, 0.35)
	tween.tween_interval(hold_black_time)
	tween.tween_property(_transition_label, "modulate:a", 0.0, 0.35)
	# 3. Fade screen back in from black while ambient sound & whispers slowly fade in
	tween.tween_callback(func() -> void:
		AudioManager.start_room_ambience(fade_in_time + 0.5)
	)
	tween.tween_property(fade_rect, "color:a", 0.0, fade_in_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _is_changing_room = false)


func _load_room(scene_path: String) -> String:
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		push_error("Main: could not load room %s" % scene_path)
		return "Unknown Room"
	for child in world.get_children():
		world.remove_child(child)
		child.queue_free()
	var instance: Node = scene.instantiate()
	world.add_child(instance)
	if instance.get("room_title") != null:
		return String(instance.get("room_title"))
	return "Unknown Room"

extends Node

## Game entry point. Keeps the HUD/menus on top and swaps rooms inside the world SubViewport.
## Attached to: the root Node of scenes/main.tscn
##
## The world lives in a SubViewport so LagController can freeze ONLY the game picture
## (fake lag) while the HUD and the narrator keep updating normally.
## WorldContainer also carries the glitch shader (scripts/fx/glitch_fx.gd), so screen
## glitches distort only the world - the HUD stays readable.

@export var fade_time: float = 0.3

@onready var world: SubViewport = $WorldContainer/World
@onready var fade_rect: ColorRect = $FadeLayer/FadeRect

var _is_changing_room: bool = false


func _ready() -> void:
	LagController.register_viewport(world)
	EventBus.room_change_requested.connect(_on_room_change_requested)
	EventBus.level_completed.connect(_on_level_completed)
	# Fresh start, death and "Restart" all reload Main: resume at the last Living Room.
	GameManager.current_level = GameManager.checkpoint_level
	_load_room(GameManager.scene_for_level(GameManager.current_level))


func _on_level_completed() -> void:
	if _is_changing_room:
		return
	GameManager.advance_level()
	_on_room_change_requested(GameManager.scene_for_level(GameManager.current_level))


func _on_room_change_requested(scene_path: String) -> void:
	if _is_changing_room:
		return
	_is_changing_room = true
	var tween: Tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, fade_time)
	tween.tween_callback(_load_room.bind(scene_path))
	tween.tween_property(fade_rect, "color:a", 0.0, fade_time)
	tween.tween_callback(func() -> void: _is_changing_room = false)


func _load_room(scene_path: String) -> void:
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		push_error("Main: could not load room %s" % scene_path)
		return
	for child in world.get_children():
		world.remove_child(child)
		child.queue_free()
	world.add_child(scene.instantiate())

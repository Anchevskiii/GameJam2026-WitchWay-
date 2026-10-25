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
var _transition_container: Control = null
var _transition_badge: Label = null
var _transition_title: Label = null
var _transition_sub: Label = null


func _ready() -> void:
	LagController.register_viewport(world)
	_setup_transition_label()
	EventBus.room_change_requested.connect(_on_room_change_requested)
	EventBus.level_completed.connect(_on_level_completed)
	# Fresh start, death and "Restart" all reload Main: resume at the last Living Room.
	GameManager.current_level = GameManager.checkpoint_level
	AudioManager.stop_room_music()
	_load_room(GameManager.scene_for_level(GameManager.current_level))
	AudioManager.stop_menu_music()
	_apply_room_ambience(1.4)


## Safe rooms keep their own music; the haunted whispers only play on real floors.
func _apply_room_ambience(fade_in_duration: float) -> void:
	if GameManager.is_safe_room:
		AudioManager.fade_out_room_ambience(0.35)
	else:
		AudioManager.start_room_ambience(fade_in_duration)


func _setup_transition_label() -> void:
	_transition_container = CenterContainer.new()
	_transition_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_container.modulate.a = 0.0

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 130)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.04, 0.10, 0.95)
	sb.border_color = Color(0.96, 0.58, 0.22)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(0)
	panel.add_theme_stylebox_override("panel", sb)
	_transition_container.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	_transition_badge = Label.new()
	_transition_badge.text = "HAUNTED MANSION"
	_transition_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_transition_badge.add_theme_font_override("font", UiTheme.font())
	_transition_badge.add_theme_font_size_override("font_size", 10)
	_transition_badge.add_theme_color_override("font_color", Color(0.96, 0.58, 0.22))
	vbox.add_child(_transition_badge)

	_transition_title = Label.new()
	_transition_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_transition_title.add_theme_font_override("font", UiTheme.font())
	_transition_title.add_theme_font_size_override("font_size", 16)
	_transition_title.add_theme_color_override("font_color", Color(0.96, 0.92, 0.85))
	_transition_title.add_theme_color_override("font_shadow_color", Color(0.08, 0.04, 0.12))
	_transition_title.add_theme_constant_override("shadow_offset_x", 2)
	_transition_title.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(_transition_title)

	_transition_sub = Label.new()
	_transition_sub.text = "Entering darkness... Tread lightly and stay quiet."
	_transition_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_transition_sub.add_theme_font_override("font", UiTheme.font())
	_transition_sub.add_theme_font_size_override("font_size", 9)
	_transition_sub.add_theme_color_override("font_color", Color(0.62, 0.60, 0.76))
	vbox.add_child(_transition_sub)

	fade_layer.add_child(_transition_container)


func _on_level_completed() -> void:
	if _is_changing_room:
		return
	AudioManager.play("byebye", 0.5, 1.0)
	AudioManager.play("creak_door", -2.5, randf_range(0.94, 1.04))
	GameManager.on_floor_completed()
	GameManager.advance_level()
	_on_room_change_requested(GameManager.scene_for_level(GameManager.current_level))


func _on_room_change_requested(scene_path: String) -> void:
	if _is_changing_room:
		return
	_is_changing_room = true
	GameManager.is_transitioning = true
	AudioManager.fade_out_room_ambience(fade_out_time)

	var tween: Tween = create_tween()
	# 1. Fade screen to black while room audio slowly fades out to silence
	tween.tween_property(fade_rect, "color:a", 1.0, fade_out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 2. In complete silence on the black screen, load the new room and show "Progressing to 'Floor X: Room Name'"
	tween.tween_callback(func() -> void:
		var title: String = _load_room(scene_path)
		var full_title: String = GameManager.floor_title(title).to_upper()
		_transition_title.text = full_title
		if GameManager.is_safe_room:
			_transition_badge.text = "SAFE REFUGE"
			_transition_sub.text = "Rest your weary nerves. Casper's tavern is here."
		else:
			_transition_badge.text = "FLOOR PROGRESSION"
			_transition_sub.text = "Entering darkness... Tread lightly and stay quiet."
	)
	tween.tween_property(_transition_container, "modulate:a", 1.0, 0.35)
	tween.tween_interval(hold_black_time)
	tween.tween_property(_transition_container, "modulate:a", 0.0, 0.35)
	# 3. Fade screen back in from black while ambient sound & whispers slowly fade in
	tween.tween_callback(func() -> void:
		_apply_room_ambience(fade_in_time + 0.5)
	)
	tween.tween_property(fade_rect, "color:a", 0.0, fade_in_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		_is_changing_room = false
		GameManager.is_transitioning = false
	)


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

class_name MainMenu
extends Control

## Main Menu with animated cinematic intro:
## Camera moves down the pixel-art haunted forest path with subtle walking sway,
## the outer trees (with wind swaying branches) smoothly part outwards,
## revealing the Victorian haunted mansion,
## a ghost emerges from the front door and flies to hover on the right lawn near pumpkins,
## and the title ("Witch Way?") and menu options fade into view.
## Attached to: Control node in scenes/ui/main_menu.tscn

@export var start_level_scene: PackedScene = preload("res://scenes/main.tscn")

@onready var background_container: Control = $BackgroundContainer
@onready var background: TextureRect = $BackgroundContainer/Background
@onready var ghost_sprite: Sprite2D = $BackgroundContainer/EmergingGhost
@onready var forest_path_container: Control = $ForestPathContainer
@onready var forest_path_bg: TextureRect = $ForestPathContainer/ForestPathBg
@onready var dark_overlay: ColorRect = $DarkOverlay
@onready var tree_left: TextureRect = $TreeOverlayLeft
@onready var tree_right: TextureRect = $TreeOverlayRight

@onready var main_layout: VBoxContainer = $MainLayout
@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var settings_menu: SettingsMenu = $SettingsMenu

var _intro_completed: bool = false
var _intro_tween: Tween = null
var _time_elapsed: float = 0.0
var _walk_intensity: float = 0.0
var _target_forest_pos: Vector2 = Vector2.ZERO
var _ghost_reached_lawn: bool = false

const GHOST_TARGET_POS: Vector2 = Vector2(930.0, 520.0)

func _ready() -> void:
	_setup_buttons()
	_check_save_state()
	_setup_intro_initial_state()
	_play_intro_animation()

func _setup_intro_initial_state() -> void:
	# Forest path starts slightly zoomed in
	if forest_path_container:
		forest_path_container.pivot_offset = Vector2(640, 560)
		forest_path_container.scale = Vector2(1.22, 1.22)
		_target_forest_pos = Vector2(0, -25)
		forest_path_container.position = _target_forest_pos
		forest_path_container.modulate.a = 1.0

	_walk_intensity = 1.0

	# Single pair of outer trees with wind shader
	if tree_left:
		tree_left.position = Vector2(0, 0)
	if tree_right:
		tree_right.position = Vector2(743, 0)

	# Atmospheric dark mist
	if dark_overlay:
		dark_overlay.modulate.a = 0.75

	# Mansion background is static and perfectly anchored
	if background_container:
		background_container.scale = Vector2(1.0, 1.0)
		background_container.position = Vector2.ZERO
		background_container.pivot_offset = Vector2(640, 360)

	# Ghost hidden inside mansion door
	if ghost_sprite:
		ghost_sprite.position = Vector2(640, 470)
		ghost_sprite.scale = Vector2(0.3, 0.3)
		ghost_sprite.modulate.a = 0.0

	_ghost_reached_lawn = false

	# Menu UI hidden initially
	if main_layout:
		main_layout.modulate.a = 0.0

func _process(delta: float) -> void:
	_time_elapsed += delta

	# Very subtle, gentle walking sway (no jitter or harsh shake)
	if forest_path_container and _walk_intensity > 0.001:
		var bob_y: float = sin(_time_elapsed * 3.5) * (1.5 * _walk_intensity)
		var sway_x: float = cos(_time_elapsed * 1.75) * (1.0 * _walk_intensity)
		forest_path_container.position = _target_forest_pos + Vector2(sway_x, bob_y)

	# Gentle ghost floating bobbing once arrived on lawn
	if ghost_sprite and _ghost_reached_lawn:
		ghost_sprite.rotation = 0.06 * sin(_time_elapsed * 3.0)
		ghost_sprite.position.y = GHOST_TARGET_POS.y + sin(_time_elapsed * 3.4) * 6.0

func _play_intro_animation() -> void:
	_intro_tween = create_tween().set_parallel(true)

	# 1. Subtle camera glide forward down forest path
	_intro_tween.tween_property(self, "_walk_intensity", 0.0, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_intro_tween.tween_property(forest_path_container, "scale", Vector2(1.0, 1.0), 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_intro_tween.tween_property(self, "_target_forest_pos", Vector2.ZERO, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_intro_tween.tween_property(dark_overlay, "modulate:a", 0.0, 2.2).set_trans(Tween.TRANS_SINE)

	# 2. Forest path dissolves smoothly to reveal the Victorian mansion
	_intro_tween.tween_property(forest_path_container, "modulate:a", 0.0, 1.6).set_delay(1.6).set_trans(Tween.TRANS_SINE)

	# 3. Outer trees part gracefully to the left and right
	_intro_tween.tween_property(tree_left, "position:x", -580.0, 2.0).set_delay(1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_intro_tween.tween_property(tree_right, "position:x", 1340.0, 2.0).set_delay(1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# 4. Ghost emerges from mansion door and flies to hover on the right lawn
	_intro_tween.tween_property(ghost_sprite, "modulate:a", 1.0, 0.4).set_delay(3.0)
	_intro_tween.tween_property(ghost_sprite, "position", GHOST_TARGET_POS, 1.5).set_delay(3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(ghost_sprite, "scale", Vector2(2.4, 2.4), 1.5).set_delay(3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 5. Fade in Main Menu UI
	_intro_tween.chain().tween_property(main_layout, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	_intro_tween.chain().tween_callback(func() -> void:
		_ghost_reached_lawn = true
		_intro_completed = true
	)

func _unhandled_input(event: InputEvent) -> void:
	# Skip intro immediately on any key press or mouse click
	if not _intro_completed:
		if event is InputEventKey or (event is InputEventMouseButton and event.pressed):
			_skip_intro()

func _skip_intro() -> void:
	if _intro_tween and _intro_tween.is_valid():
		_intro_tween.kill()

	_walk_intensity = 0.0
	_target_forest_pos = Vector2.ZERO
	_ghost_reached_lawn = true
	_intro_completed = true

	if forest_path_container:
		forest_path_container.modulate.a = 0.0
		forest_path_container.scale = Vector2(1.0, 1.0)
		forest_path_container.position = Vector2.ZERO
	if dark_overlay:
		dark_overlay.modulate.a = 0.0

	if tree_left:
		tree_left.position.x = -580.0
	if tree_right:
		tree_right.position.x = 1340.0

	if background_container:
		background_container.scale = Vector2(1.0, 1.0)
		background_container.position = Vector2.ZERO

	if ghost_sprite:
		ghost_sprite.position = GHOST_TARGET_POS
		ghost_sprite.scale = Vector2(2.4, 2.4)
		ghost_sprite.modulate.a = 1.0

	if main_layout:
		main_layout.modulate.a = 1.0

func _setup_buttons() -> void:
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

func _check_save_state() -> void:
	if continue_button:
		continue_button.disabled = not SaveManager.has_save_file()

func _on_new_game_pressed() -> void:
	GameManager.start_new_run()
	if start_level_scene:
		get_tree().change_scene_to_packed(start_level_scene)
	else:
		get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_continue_pressed() -> void:
	var progress: Dictionary = SaveManager.load_progress()
	# The save holds the last Living Room reached; Main starts at GameManager's checkpoint.
	GameManager.start_from_checkpoint(int(progress.get("highest_level", 0)))
	if start_level_scene:
		get_tree().change_scene_to_packed(start_level_scene)
	else:
		get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_settings_pressed() -> void:
	if settings_menu:
		settings_menu.open()

func _on_quit_pressed() -> void:
	get_tree().quit()

class_name PauseMenu
extends CanvasLayer

## In-game Pause Menu triggered by [ESC] key
## Attached to: CanvasLayer in scenes/ui/pause_menu.tscn

@onready var panel: Control = $Panel
@onready var resume_button: Button = $Panel/CenterContainer/VBoxContainer/ResumeButton
@onready var restart_button: Button = $Panel/CenterContainer/VBoxContainer/RestartButton
@onready var settings_button: Button = $Panel/CenterContainer/VBoxContainer/SettingsButton
@onready var main_menu_button: Button = $Panel/CenterContainer/VBoxContainer/MainMenuButton
@onready var quit_button: Button = $Panel/CenterContainer/VBoxContainer/QuitButton
@onready var settings_menu: SettingsMenu = $SettingsMenu

var _is_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var panel: Control = get_node_or_null("Panel")
	if panel:
		panel.theme = UiTheme.build()
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") and not GameManager.is_game_over:
		if settings_menu and settings_menu.visible:
			settings_menu.close()
		else:
			toggle_pause()

func toggle_pause() -> void:
	_is_paused = not _is_paused
	if _is_paused:
		AudioManager.pause_room_music()
		AudioManager.play_menu_music()
	else:
		AudioManager.stop_menu_music()
		AudioManager.resume_room_music()
	get_tree().paused = _is_paused
	visible = _is_paused

func _on_resume_pressed() -> void:
	_is_paused = false
	AudioManager.stop_menu_music()
	AudioManager.resume_room_music()
	get_tree().paused = false
	visible = false

func _on_restart_pressed() -> void:
	_is_paused = false
	AudioManager.stop_menu_music()
	AudioManager.stop_room_music()
	get_tree().paused = false
	visible = false
	GameManager.reset_level_state()
	get_tree().reload_current_scene()

func _on_settings_pressed() -> void:
	if settings_menu:
		settings_menu.open()

func _on_main_menu_pressed() -> void:
	_is_paused = false
	AudioManager.stop_room_music()
	get_tree().paused = false
	visible = false
	GameManager.is_game_active = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_quit_pressed() -> void:
	_is_paused = false
	AudioManager.stop_menu_music()
	AudioManager.stop_room_music()
	get_tree().paused = false
	get_tree().quit()

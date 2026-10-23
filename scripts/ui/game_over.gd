class_name GameOverScreen
extends CanvasLayer

## Game Over screen when Sanity overflows ("Pants Peed" fail state)
## Attached to: CanvasLayer in scenes/ui/game_over.tscn

@onready var panel: Control = $Panel
@onready var retry_button: Button = $Panel/CenterContainer/VBoxContainer/RetryButton

func _ready() -> void:
	visible = false
	EventBus.game_over_triggered.connect(_on_game_over)
	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)

func _on_game_over() -> void:
	visible = true

func _on_retry_pressed() -> void:
	visible = false
	GameManager.reset_level_state()
	get_tree().reload_current_scene()

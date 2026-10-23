class_name HUD
extends CanvasLayer

## Manages Sanity, CPU Overload, and Inventory status displays
## Attached to: CanvasLayer in scenes/ui/hud.tscn

@onready var sanity_bar: ProgressBar = $Control/PanelContainer/VBoxContainer/SanityBox/SanityBar
@onready var sanity_label: Label = $Control/PanelContainer/VBoxContainer/SanityBox/HeaderBox/SanityPercent
@onready var cpu_bar: ProgressBar = $Control/PanelContainer/VBoxContainer/CPUBox/CPUBar
@onready var cpu_label: Label = $Control/PanelContainer/VBoxContainer/CPUBox/HeaderBox/CPUPercent
@onready var key_status_label: Label = $Control/PanelContainer/VBoxContainer/KeyStatusLabel

func _ready() -> void:
	EventBus.sanity_changed.connect(_on_sanity_changed)
	EventBus.cpu_overload_changed.connect(_on_cpu_overload_changed)
	EventBus.item_collected.connect(_on_item_collected)
	_on_sanity_changed(GameManager.current_sanity, GameManager.max_sanity)
	_on_cpu_overload_changed(GameManager.current_cpu_overload, GameManager.max_cpu_overload)

func _on_sanity_changed(current: float, max_val: float) -> void:
	if sanity_bar:
		sanity_bar.max_value = max_val
		sanity_bar.value = current
	if sanity_label:
		var pct: int = int((current / max(max_val, 1.0)) * 100.0)
		sanity_label.text = "%d%%" % pct

func _on_cpu_overload_changed(current: float, max_val: float) -> void:
	if cpu_bar:
		cpu_bar.max_value = max_val
		cpu_bar.value = current
	if cpu_label:
		var pct: int = int((current / max(max_val, 1.0)) * 100.0)
		cpu_label.text = "%d%%" % pct

func _on_item_collected(item_name: String) -> void:
	if item_name.to_lower().contains("key") and key_status_label:
		key_status_label.text = "KEY: [ACQUIRED]"
		key_status_label.modulate = Color(0.3, 1.0, 0.4, 1.0)

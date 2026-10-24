class_name HUD
extends CanvasLayer

## Sanity bar, GLITCH bar (scares make the house glitch), room name/objective and the Narrator text box.
## Attached to: CanvasLayer in scenes/ui/hud.tscn

const CPU_CALM: Color = Color(0.2, 0.8, 1.0)
const CPU_WARM: Color = Color(1.0, 0.65, 0.2)
const CPU_HOT: Color = Color(1.0, 0.25, 0.25)
const CPU_OVERLOAD: Color = Color(1.0, 0.0, 0.86)

@onready var sanity_bar: ProgressBar = $Control/PanelContainer/VBoxContainer/SanityBox/SanityBar
@onready var sanity_label: Label = $Control/PanelContainer/VBoxContainer/SanityBox/HeaderBox/SanityPercent
@onready var cpu_bar: ProgressBar = $Control/PanelContainer/VBoxContainer/CPUBox/CPUBar
@onready var cpu_label: Label = $Control/PanelContainer/VBoxContainer/CPUBox/HeaderBox/CPUPercent
@onready var room_label: Label = $Control/PanelContainer/VBoxContainer/RoomLabel
@onready var objective_label: Label = $Control/PanelContainer/VBoxContainer/ObjectiveLabel
@onready var narrator_box: PanelContainer = $Control/NarratorBox
@onready var narrator_text: Label = $Control/NarratorBox/VBoxContainer/NarratorText

var _cpu_fill: StyleBoxFlat
var _narrator_tween: Tween


func _ready() -> void:
	# Own copy of the fill style so changing its colour doesn't touch other bars.
	_cpu_fill = (cpu_bar.get_theme_stylebox("fill") as StyleBoxFlat).duplicate()
	cpu_bar.add_theme_stylebox_override("fill", _cpu_fill)
	narrator_box.visible = false

	EventBus.sanity_changed.connect(_on_sanity_changed)
	EventBus.cpu_overload_changed.connect(_on_cpu_overload_changed)
	EventBus.room_entered.connect(_on_room_entered)
	EventBus.narrator_line_changed.connect(_on_narrator_line_changed)
	EventBus.key_collected.connect(_on_key_collected)
	_on_sanity_changed(GameManager.current_sanity, GameManager.max_sanity)
	_on_cpu_overload_changed(GameManager.current_cpu_overload, GameManager.max_cpu_overload)


func _on_key_collected() -> void:
	if objective_label:
		objective_label.text = "[KEY FOUND!] Unlock the Exit Door."
		objective_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))


func _on_sanity_changed(current: float, max_val: float) -> void:
	sanity_bar.max_value = max_val
	sanity_bar.value = current
	var pct: int = int((current / maxf(max_val, 1.0)) * 100.0)
	sanity_label.text = "%d%%" % pct
	sanity_bar.modulate = Color(1, 1, 1) if pct > 25 else Color(1, 0.6, 0.6)


func _on_cpu_overload_changed(current: float, max_val: float) -> void:
	cpu_bar.max_value = max_val
	cpu_bar.value = current
	var pct: int = int((current / maxf(max_val, 1.0)) * 100.0)
	# The glitch meter in words: scaring things makes the house glitch; at 100% it crashes.
	if pct >= 100:
		cpu_label.text = "CRASHED!"
		_cpu_fill.bg_color = CPU_OVERLOAD
	elif pct >= 75:
		cpu_label.text = "%d%% CRASHING" % pct
		_cpu_fill.bg_color = CPU_HOT
	elif pct >= 50:
		cpu_label.text = "%d%% LAGGING" % pct
		_cpu_fill.bg_color = CPU_WARM
	elif pct >= 20:
		cpu_label.text = "%d%% FLICKERING" % pct
		_cpu_fill.bg_color = CPU_CALM
	else:
		cpu_label.text = "STABLE"
		_cpu_fill.bg_color = CPU_CALM


func _on_room_entered(room_title: String, objective: String) -> void:
	room_label.text = room_title.to_upper()
	if GameManager.has_exit_key:
		objective_label.text = "[KEY FOUND!] Unlock the Exit Door."
		objective_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	else:
		objective_label.text = objective
		objective_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 1))
	objective_label.visible = not objective.is_empty()


## Typewriter-style narrator box. Empty text hides it.
func _on_narrator_line_changed(text: String) -> void:
	if _narrator_tween:
		_narrator_tween.kill()
	if text.is_empty():
		narrator_box.visible = false
		return
	narrator_box.visible = true
	narrator_text.text = text
	narrator_text.visible_ratio = 0.0
	_narrator_tween = create_tween()
	_narrator_tween.tween_property(narrator_text, "visible_ratio", 1.0, minf(0.02 * text.length(), 1.2))

extends Control

## Ending screen with run statistics. SPACE / ENTER starts a new run in the Living Room.
## Attached to: the root Control of scenes/levels/ending.tscn

@export_file("*.tscn") var restart_room: String = "res://scenes/levels/living_room.tscn"

@onready var stats_label: Label = $CenterContainer/VBoxContainer/StatsLabel

var _restarting: bool = false


func _ready() -> void:
	GameManager.is_safe_room = true
	GameManager.reset_cpu_load()
	EventBus.room_entered.emit("Outside", "")
	stats_label.text = (
		"Monsters scared: %d\nProps spawned: %d\nTimes you peed: %d\nBugs encountered: 0 (they were all features)"
		% [GameManager.stats_npcs_scared, GameManager.stats_props_spawned, GameManager.stats_times_peed])
	Narrator.clear()
	Narrator.say("Thank you for visiting the Haunted House. Please rate us five stars. Management.")


func _process(_delta: float) -> void:
	if _restarting:
		return
	if Input.is_action_just_pressed("scare") or Input.is_action_just_pressed("ui_accept"):
		_restarting = true
		GameManager.stats_npcs_scared = 0
		GameManager.stats_props_spawned = 0
		GameManager.stats_times_peed = 0
		GameManager.reset_level_state()
		EventBus.room_change_requested.emit(restart_room)

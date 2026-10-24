extends Node

## Manages core game state: Sanity (player "health") and the fake CPU load meter.
## Attached as Autoload singleton: GameManager
##
## Sanity: starts full (100) and drains when the player gets scared. At 0 the player
## pees their pants (game over). Regenerates slowly while standing still (see SanityComponent).
## GLITCH meter (current_cpu_overload, shown as "GLITCH" in the HUD): scaring things makes the
## house glitch. Every scare adds glitch (shown as "+N GLITCH" where it happened). It holds for
## a few seconds, then drains - so chain scares quickly. At 100% the house crashes: the
## exit door on OVERLOAD floors fails to render, and the screen glitches hardest.

@export var max_sanity: float = 100.0
@export var max_cpu_overload: float = 100.0
## How fast the glitch meter drains per second once it starts draining.
@export var cpu_decay_rate: float = 3.0
## Seconds the meter holds after the last gain before it starts draining.
@export var glitch_hold_time: float = 6.0

@export_group("Difficulty")
## Every monster's wind-up is multiplied by this (lower = they scare you faster).
@export var monster_windup_scale: float = 0.35
## Every monster sees this much further than its NpcData says (shorter, tighter FOV).
@export var monster_sight_scale: float = 0.72

## Endless run: level 0, 3, 6, ... are the Living Room (safe room + checkpoint).
## Levels 1 and 2 are the hand-made Dark Hallway and Dining Room; every other level is generated.
const LIVING_ROOM_EVERY: int = 3
const LIVING_ROOM_SCENE: String = "res://scenes/levels/living_room.tscn"
const HANDMADE_LEVELS: Dictionary = {
	1: "res://scenes/levels/dark_hallway.tscn",
	2: "res://scenes/levels/dining_room.tscn",
}
const GENERATED_SCENE: String = "res://scenes/levels/generated_room.tscn"

var current_level: int = 0
## The last Living Room reached. Dying sends the player back here.
var checkpoint_level: int = 0
var best_level: int = 0
var current_sanity: float = 100.0
var current_cpu_overload: float = 0.0
var is_glitch_mode: bool = false
var is_game_over: bool = false
var is_game_active: bool = false
var has_exit_key: bool = false

## Set by the current Room. Safe rooms (Living Room) ignore scares and keep sanity full.
var is_safe_room: bool = false
## Set by the current Room. Multiplies every prop's load weight ("this room is unoptimized").
var cpu_load_multiplier: float = 1.0

# Run statistics, shown on the game over screen.
var stats_npcs_scared: int = 0
var stats_props_spawned: int = 0
var stats_times_peed: int = 0
var stats_kids_peed: int = 0

var _time_since_glitch_gain: float = 999.0

var _low_sanity_warned: bool = false


func _ready() -> void:
	is_game_active = false
	reset_level_state()
	EventBus.npc_scared.connect(_on_npc_scared)


func _on_npc_scared(_npc_name: String) -> void:
	# Laughing off a successful scare restores a bit of sanity!
	restore_sanity(10.0)


func _process(delta: float) -> void:
	if is_game_over or not is_game_active:
		return
	_time_since_glitch_gain += delta
	if current_cpu_overload > 0.0 and _time_since_glitch_gain >= glitch_hold_time:
		_set_cpu_load(current_cpu_overload - cpu_decay_rate * delta)


## Adds glitch (a prop was spawned, something got scared). The room multiplier is applied here.
func add_cpu_load(amount: float) -> void:
	if is_game_over:
		return
	_time_since_glitch_gain = 0.0
	_set_cpu_load(current_cpu_overload + amount * cpu_load_multiplier)


func _set_cpu_load(value: float) -> void:
	current_cpu_overload = clampf(value, 0.0, max_cpu_overload)
	EventBus.cpu_overload_changed.emit(current_cpu_overload, max_cpu_overload)
	var glitch_now: bool = current_cpu_overload >= max_cpu_overload
	if glitch_now != is_glitch_mode:
		is_glitch_mode = glitch_now
		EventBus.glitch_mode_toggled.emit(is_glitch_mode)
		if is_glitch_mode:
			Narrator.say_event("glitch_crash")


## Removes sanity. Call this whenever something scares the player.
## is_ambush = true deals bonus shock damage (jumping out of wardrobe, corner ambush, dark jumpscare).
func scare_player(amount: float, source_name: String = "", is_ambush: bool = false) -> void:
	if is_game_over or is_safe_room or amount <= 0.0:
		return
	var final_amount: float = amount * (1.5 if is_ambush else 1.0)
	current_sanity = clampf(current_sanity - final_amount, 0.0, max_sanity)
	EventBus.sanity_changed.emit(current_sanity, max_sanity)
	EventBus.player_scared.emit(final_amount, source_name)

	if current_sanity <= max_sanity * 0.25 and not _low_sanity_warned:
		_low_sanity_warned = true
		Narrator.say_event("low_sanity")
	if current_sanity <= 0.0:
		trigger_game_over()


func restore_sanity(amount: float) -> void:
	if is_game_over:
		return
	current_sanity = clampf(current_sanity + amount, 0.0, max_sanity)
	if current_sanity > max_sanity * 0.4:
		_low_sanity_warned = false
	EventBus.sanity_changed.emit(current_sanity, max_sanity)


func refill_sanity() -> void:
	restore_sanity(max_sanity)


func trigger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	stats_times_peed += 1
	EventBus.game_over_triggered.emit()


## Called on game start, retry, and when a new room is entered.
func reset_level_state() -> void:
	current_sanity = max_sanity
	current_cpu_overload = 0.0
	is_glitch_mode = false
	is_game_over = false
	is_game_active = true
	has_exit_key = false
	_low_sanity_warned = false
	EventBus.sanity_changed.emit(current_sanity, max_sanity)
	EventBus.cpu_overload_changed.emit(current_cpu_overload, max_cpu_overload)
	EventBus.glitch_mode_toggled.emit(false)


func is_safe_level(_level: int) -> bool:
	return false


func scene_for_level(_level: int) -> String:
	return GENERATED_SCENE


## 0 for the first loop, then 1, 2, 3... Generated rooms get bigger and meaner with it.
func difficulty_tier(level: int = current_level) -> int:
	return level / LIVING_ROOM_EVERY


## New Game: start the run from floor 1 (level 0).
func start_new_run() -> void:
	stats_npcs_scared = 0
	stats_props_spawned = 0
	stats_times_peed = 0
	stats_kids_peed = 0
	start_from_checkpoint(0)
	SaveManager.save_progress(0)


## Continue: resume at the exact floor reached.
func start_from_checkpoint(level: int) -> void:
	checkpoint_level = maxi(level, 0)
	current_level = checkpoint_level
	best_level = maxi(best_level, checkpoint_level)
	reset_level_state()


## Called when the player walks out of a room's exit door.
func advance_level() -> void:
	current_level += 1
	best_level = maxi(best_level, current_level)
	checkpoint_level = current_level
	SaveManager.save_progress(current_level)


## Only clears the CPU meter (used when walking into a new room; sanity carries over).
func reset_cpu_load() -> void:
	_set_cpu_load(0.0)

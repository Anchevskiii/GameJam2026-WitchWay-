extends Node

## Manages core game state: Sanity (player "health") and the fake CPU load meter.
## Attached as Autoload singleton: GameManager
##
## Sanity: starts full (100) and drains when the player gets scared. At 0 the player
## pees their pants (game over). Regenerates slowly while standing still (see SanityComponent).
## CPU load: a fake gameplay meter. Props add load, and it decays back down on its own,
## so the player must chain scares quickly to push it to 100%.

@export var max_sanity: float = 100.0
@export var max_cpu_overload: float = 100.0
## How fast CPU load drains per second when nothing is happening.
@export var cpu_decay_rate: float = 3.5

var current_level: int = 1
var current_sanity: float = 100.0
var current_cpu_overload: float = 0.0
var is_glitch_mode: bool = false
var is_game_over: bool = false

## Set by the current Room. Safe rooms (Living Room) ignore scares and keep sanity full.
var is_safe_room: bool = false
## Set by the current Room. Multiplies every prop's load weight ("this room is unoptimized").
var cpu_load_multiplier: float = 1.0

# Run statistics, shown on the ending screen.
var stats_npcs_scared: int = 0
var stats_props_spawned: int = 0
var stats_times_peed: int = 0

var _low_sanity_warned: bool = false


func _ready() -> void:
	reset_level_state()


func _process(delta: float) -> void:
	if is_game_over:
		return
	if current_cpu_overload > 0.0:
		_set_cpu_load(current_cpu_overload - cpu_decay_rate * delta)


## Adds CPU load (e.g. a prop was spawned). The room multiplier is applied here.
func add_cpu_load(amount: float) -> void:
	if is_game_over:
		return
	_set_cpu_load(current_cpu_overload + amount * cpu_load_multiplier)


func _set_cpu_load(value: float) -> void:
	current_cpu_overload = clampf(value, 0.0, max_cpu_overload)
	EventBus.cpu_overload_changed.emit(current_cpu_overload, max_cpu_overload)
	var glitch_now: bool = current_cpu_overload >= max_cpu_overload
	if glitch_now != is_glitch_mode:
		is_glitch_mode = glitch_now
		EventBus.glitch_mode_toggled.emit(is_glitch_mode)


## Removes sanity. Call this whenever something scares the player.
func scare_player(amount: float, source_name: String = "") -> void:
	if is_game_over or is_safe_room or amount <= 0.0:
		return
	current_sanity = clampf(current_sanity - amount, 0.0, max_sanity)
	EventBus.sanity_changed.emit(current_sanity, max_sanity)
	EventBus.player_scared.emit(amount, source_name)

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
	_low_sanity_warned = false
	EventBus.sanity_changed.emit(current_sanity, max_sanity)
	EventBus.cpu_overload_changed.emit(current_cpu_overload, max_cpu_overload)
	EventBus.glitch_mode_toggled.emit(false)


## Only clears the CPU meter (used when walking into a new room; sanity carries over).
func reset_cpu_load() -> void:
	_set_cpu_load(0.0)

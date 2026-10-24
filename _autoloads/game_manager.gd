extends Node

## Manages core game state, levels, sanity, and glitch overload
## Attached as Autoload singleton: GameManager

@export var max_sanity: float = 100.0
@export var max_cpu_overload: float = 100.0
@export var cpu_overload_increase_rate: float = 1.5

var current_level: int = 1
var current_sanity: float = 0.0
var current_cpu_overload: float = 0.0
var is_glitch_mode: bool = false
var is_game_over: bool = false
var is_game_active: bool = false

func _ready() -> void:
	is_game_active = false
	reset_level_state()

func _process(delta: float) -> void:
	if not is_game_over and is_game_active:
		_process_cpu_overload(delta)

func _process_cpu_overload(delta: float) -> void:
	if current_cpu_overload < max_cpu_overload:
		current_cpu_overload = minf(current_cpu_overload + (cpu_overload_increase_rate * delta), max_cpu_overload)
		EventBus.cpu_overload_changed.emit(current_cpu_overload, max_cpu_overload)
		
		if current_cpu_overload >= max_cpu_overload and not is_glitch_mode:
			is_glitch_mode = true
			EventBus.glitch_mode_toggled.emit(true)

func add_sanity(amount: float, source_name: String = "") -> void:
	if is_game_over:
		return
	current_sanity = clampf(current_sanity + amount, 0.0, max_sanity)
	EventBus.sanity_changed.emit(current_sanity, max_sanity)
	if amount > 0.0:
		EventBus.player_scared.emit(amount, source_name)
	
	if current_sanity >= max_sanity:
		trigger_game_over()

func reduce_sanity(amount: float) -> void:
	current_sanity = clampf(current_sanity - amount, 0.0, max_sanity)
	EventBus.sanity_changed.emit(current_sanity, max_sanity)

func trigger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	EventBus.game_over_triggered.emit()

func reset_level_state() -> void:
	current_sanity = 0.0
	current_cpu_overload = 0.0
	is_glitch_mode = false
	is_game_over = false
	is_game_active = true
	EventBus.sanity_changed.emit(current_sanity, max_sanity)
	EventBus.cpu_overload_changed.emit(current_cpu_overload, max_cpu_overload)
	EventBus.glitch_mode_toggled.emit(false)

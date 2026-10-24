extends Node

## Fake lag driven by CPU load. Purely visual + intentional dodge windows.
## Attached as Autoload singleton: LagController
##
## Above `lag_start_load`, the game world's SubViewport stops redrawing for a few
## milliseconds at a time, so the picture stutters. Game logic and player input KEEP
## RUNNING during a freeze (fair "lag"). While `is_frozen` is true, NPC wind-ups and
## traps pause - that is the "feature": skilled players dodge during the stutter.
##
## Main registers the world viewport with `register_viewport()`.

## CPU % where stutter begins.
@export var lag_start_load: float = 50.0
## Freeze length range in seconds (scaled by load). Never longer than max.
@export var min_freeze: float = 0.05
@export var max_freeze: float = 0.15
## Time between freezes: long at lag_start_load, short at 100%.
@export var interval_at_start: float = 1.6
@export var interval_at_max: float = 0.35

var is_frozen: bool = false

var _viewport: SubViewport = null
var _next_freeze_in: float = 1.0
var _freeze_left: float = 0.0


func register_viewport(viewport: SubViewport) -> void:
	_viewport = viewport


func _process(delta: float) -> void:
	if is_frozen:
		_freeze_left -= delta
		if _freeze_left <= 0.0:
			_set_frozen(false)
		return

	var load_pct: float = GameManager.current_cpu_overload
	if load_pct < lag_start_load or GameManager.is_game_over:
		return
	var t: float = inverse_lerp(lag_start_load, 100.0, load_pct)
	_next_freeze_in -= delta
	if _next_freeze_in <= 0.0:
		_freeze_left = minf(lerpf(min_freeze, max_freeze, t) * randf_range(0.7, 1.0), max_freeze)
		_next_freeze_in = lerpf(interval_at_start, interval_at_max, t) * randf_range(0.6, 1.4)
		_set_frozen(true)


## 0 when calm, 1 at full load. Handy for other "lag" cues (choppy animation, etc).
func lag_amount() -> float:
	return clampf(inverse_lerp(lag_start_load, 100.0, GameManager.current_cpu_overload), 0.0, 1.0)


func _set_frozen(frozen: bool) -> void:
	is_frozen = frozen
	if is_instance_valid(_viewport):
		_viewport.render_target_update_mode = (
			SubViewport.UPDATE_DISABLED if frozen else SubViewport.UPDATE_ALWAYS)
	EventBus.lag_freeze_changed.emit(frozen)

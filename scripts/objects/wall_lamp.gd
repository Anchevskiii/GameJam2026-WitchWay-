class_name WallLamp
extends Node2D

## Wall lamp / room light that provides eerie atmosphere.
## Supports both rapid creepy flickering and temporary blackouts (turning completely off
## for 0.8 - 1.8s before snapping back on). Can also drive an external PointLight2D (e.g. on corner lamps).

@export var light_energy: float = 0.85
@export var light_color: Color = Color(1.0, 0.8, 0.5)
@export var light_scale: float = 0.65
@export var flicker_enabled: bool = true
@export var flicker_interval_min: float = 2.0
@export var flicker_interval_max: float = 6.5
@export var blackout_chance: float = 0.42

var _timer: float = 0.0
var _is_flickering: bool = false
var _is_blackout: bool = false
var _event_duration: float = 0.0

@onready var light: PointLight2D = get_node_or_null("PointLight2D")
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")


func _ready() -> void:
	if light:
		light.energy = light_energy
		light.color = light_color
		light.texture_scale = light_scale
	_reset_timer()


func _process(delta: float) -> void:
	if not flicker_enabled or light == null:
		return

	if _is_blackout:
		_event_duration -= delta
		if _event_duration <= 0.0:
			_is_blackout = false
			light.energy = light_energy
			if sprite:
				sprite.modulate = Color.WHITE
			_reset_timer()
		else:
			# Right before coming back on, stutter briefly
			if _event_duration < 0.18 and randf() < 0.4:
				light.energy = light_energy * 0.6
			else:
				light.energy = 0.0
	elif _is_flickering:
		_event_duration -= delta
		if _event_duration <= 0.0:
			_is_flickering = false
			light.energy = light_energy
			if sprite:
				sprite.modulate = Color.WHITE
			_reset_timer()
		else:
			if randf() < 0.35:
				light.energy = 0.05
				if sprite:
					sprite.modulate = Color(0.55, 0.5, 0.5)
			else:
				light.energy = light_energy * randf_range(0.2, 0.85)
				if sprite:
					sprite.modulate = Color.WHITE
	else:
		_timer -= delta
		if _timer <= 0.0:
			if randf() < blackout_chance:
				_is_blackout = true
				_event_duration = randf_range(0.85, 1.85)
				light.energy = 0.0
				if sprite:
					sprite.modulate = Color(0.4, 0.38, 0.42)
			else:
				_is_flickering = true
				_event_duration = randf_range(0.18, 0.55)


func _reset_timer() -> void:
	_timer = randf_range(flicker_interval_min, flicker_interval_max)

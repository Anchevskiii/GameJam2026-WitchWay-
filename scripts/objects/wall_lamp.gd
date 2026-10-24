class_name WallLamp
extends Node2D

## Wall lamp / room light that provides atmosphere.
## Supports subtle or aggressive flickering and temporary blackouts so rooms aren't always evenly lit.

@export var light_energy: float = 1.1
@export var light_color: Color = Color(1.0, 0.85, 0.55)
@export var light_scale: float = 1.2
@export var flicker_enabled: bool = true
@export var flicker_interval_min: float = 2.5
@export var flicker_interval_max: float = 8.0
@export var blackout_chance: float = 0.3

var _timer: float = 0.0
var _is_flickering: bool = false
var _flicker_duration: float = 0.0

@onready var light: PointLight2D = $PointLight2D
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	if light:
		light.energy = light_energy
		light.color = light_color
		light.texture_scale = light_scale
	_reset_timer()


func _process(delta: float) -> void:
	if not flicker_enabled or light == null:
		return

	if _is_flickering:
		_flicker_duration -= delta
		if _flicker_duration <= 0.0:
			_is_flickering = false
			light.energy = light_energy
			_reset_timer()
		else:
			if randf() < blackout_chance:
				light.energy = 0.0
			else:
				light.energy = light_energy * randf_range(0.2, 0.8)
	else:
		_timer -= delta
		if _timer <= 0.0:
			_is_flickering = true
			_flicker_duration = randf_range(0.1, 0.4)


func _reset_timer() -> void:
	_timer = randf_range(flicker_interval_min, flicker_interval_max)

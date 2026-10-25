extends TileMapLayer

## Makes walls you can walk through look "a bit buggy". They use the normal wall texture
## (Room paints them on this layer), but every now and then the layer twitches sideways,
## shifts colour and a few pixels flash magenta (the missing texture peeking out).
## Attached to: GlitchWalls (TileMapLayer) in scenes/levels/room_base.tscn

## Glitch "ticks" per second; each tick may start or end a burst.
@export var ticks_per_second: float = 10.0
## Chance per tick that it glitches (0 = never, 1 = always).
@export_range(0.0, 1.0) var burst_chance: float = 0.18
## Max sideways twitch in pixels during a burst.
@export var jitter_pixels: float = 2.0
@export var burst_tint: Color = Color(1.08, 0.9, 1.08)
@export var fleck_color: Color = Color(1.0, 0.0, 1.0)
## Magenta pixels per fake-wall tile during a burst.
@export var flecks_per_tile: int = 3

var _tick_left: float = 0.0
var _bursting: bool = false
var _flecks: Array[Rect2] = []
## Draws the flecks. A child, so they land on top of the tiles (the layer's own drawing is under them).
var _fleck_canvas := Node2D.new()


func _ready() -> void:
	_fleck_canvas.draw.connect(_draw_flecks)
	add_child(_fleck_canvas)


func _process(delta: float) -> void:
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = 1.0 / ticks_per_second
	_bursting = randf() < burst_chance
	position.x = randf_range(-jitter_pixels, jitter_pixels) if _bursting else 0.0
	self_modulate = burst_tint if _bursting else Color.WHITE
	_flecks.clear()
	if _bursting:
		var size: float = tile_set.tile_size.x
		for cell in get_used_cells():
			for i in flecks_per_tile:
				var spot := Vector2(cell) * size + Vector2(randi_range(0, int(size) - 3), randi_range(0, int(size) - 3))
				_flecks.append(Rect2(spot.floor(), Vector2(3, 3)))
	_fleck_canvas.queue_redraw()


func _draw_flecks() -> void:
	for fleck in _flecks:
		_fleck_canvas.draw_rect(fleck, fleck_color)

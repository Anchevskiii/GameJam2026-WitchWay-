extends SubViewportContainer

## Makes the haunted house look broken. The higher the GLITCH meter, the more it glitches:
##   - a full-screen glitch shader (assets/shaders/glitch.gdshader) on this container
##   - random glitch BURSTS (even when calm - the house is always a bit buggy)
##   - during bursts: furniture flashes to missing texture, monsters leave afterimages
## Attached to: WorldContainer (SubViewportContainer) in scenes/main.tscn

const MISSING_TEXTURE: Texture2D = preload("res://assets/sprites/environment/missing_texture.png")

## Glitch strength at each meter milestone: calm -> 25% -> 50% -> 80% -> 90% -> 100%.
@export var calm_intensity: float = 0.0
@export var flicker_intensity: float = 0.05
@export var heavy_intensity: float = 0.12
@export var severe_intensity: float = 0.25
@export var critical_intensity: float = 0.36
@export var max_intensity: float = 0.42
## Seconds between random bursts when calm, and at 100% meter.
@export var burst_interval_calm: float = 7.0
@export var burst_interval_max: float = 0.8
## Burst strength when calm, and at 100% meter.
@export var burst_strength_calm: float = 0.02
@export var burst_strength: float = 0.6

@onready var world: SubViewport = $World

var _burst_left: float = 0.0
var _next_burst: float = 3.0
var _material: ShaderMaterial


func _ready() -> void:
	_material = material as ShaderMaterial


func _process(delta: float) -> void:
	if _material == null:
		return
	var level: float = clampf(GameManager.glitch_level() / 100.0, 0.0, 1.0)
	var intensity: float = _intensity_for(level)

	_next_burst -= delta
	if _next_burst <= 0.0:
		_start_burst(level)
	if _burst_left > 0.0:
		_burst_left -= delta
		intensity = maxf(intensity, lerpf(burst_strength_calm, burst_strength, level * level))

	_material.set_shader_parameter("intensity", intensity)


## Keeps the screen in step with the milestones shown on the GLITCH bar.
func _intensity_for(level: float) -> float:
	if level < 0.25:
		return lerpf(calm_intensity, flicker_intensity, inverse_lerp(0.0, 0.25, level))
	if level < 0.5:
		return lerpf(flicker_intensity, heavy_intensity, inverse_lerp(0.25, 0.5, level))
	if level < 0.8:
		return lerpf(heavy_intensity, severe_intensity, inverse_lerp(0.5, 0.8, level))
	if level < 0.9:
		return lerpf(severe_intensity, critical_intensity, inverse_lerp(0.8, 0.9, level))
	return lerpf(critical_intensity, max_intensity, inverse_lerp(0.9, 1.0, level))


func _start_burst(level: float) -> void:
	_burst_left = randf_range(0.08, 0.25)
	_next_burst = lerpf(burst_interval_calm, burst_interval_max, level) * randf_range(0.5, 1.5)
	_material.set_shader_parameter("seed", randf() * 100.0)
	if level > 0.25 or randf() < 0.05:
		_flash_missing_texture()
	if level > 0.5:
		_monster_afterimage()


## A random piece of furniture briefly "fails to load".
func _flash_missing_texture() -> void:
	var room: Node = world.get_child(0) if world.get_child_count() > 0 else null
	if room == null or not room.has_node("Decor"):
		return
	var sprites: Array[Sprite2D] = []
	for body in room.get_node("Decor").get_children():
		if body is StaticBody2D and body.get_child_count() > 0 and body.get_child(0) is Sprite2D:
			sprites.append(body.get_child(0))
	if sprites.is_empty():
		return
	var sprite: Sprite2D = sprites.pick_random()
	var original: Texture2D = sprite.texture
	if original == MISSING_TEXTURE:
		return
	sprite.texture = MISSING_TEXTURE
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, original.get_size())
	get_tree().create_timer(randf_range(0.15, 0.4)).timeout.connect(func() -> void:
		if is_instance_valid(sprite):
			sprite.texture = original
			sprite.region_enabled = false)


## A monster leaves a fading duplicate of itself behind ("entity duplicated").
func _monster_afterimage() -> void:
	var monsters: Array[Node] = get_tree().get_nodes_in_group("npcs")
	if monsters.is_empty():
		return
	var npc: Npc = monsters.pick_random() as Npc
	if not npc.sprite.visible or npc.sprite.texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = npc.sprite.texture
	ghost.flip_h = npc.sprite.flip_h
	ghost.offset = npc.sprite.offset
	ghost.scale = npc.sprite.scale
	ghost.modulate = Color(1.0, 0.3, 0.9, 0.6)
	ghost.global_position = npc.sprite.global_position + Vector2(randf_range(-14.0, 14.0), 0.0)
	npc.get_parent().add_child(ghost)
	var tween: Tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.5)
	tween.tween_callback(ghost.queue_free)

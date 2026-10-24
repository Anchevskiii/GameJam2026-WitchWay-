extends SubViewportContainer

## Makes the haunted house look broken. The higher the GLITCH meter, the more it glitches:
##   - a full-screen glitch shader (assets/shaders/glitch.gdshader) on this container
##   - random glitch BURSTS (even when calm - the house is always a bit buggy)
##   - during bursts: furniture flashes to missing texture, monsters leave afterimages
## Attached to: WorldContainer (SubViewportContainer) in scenes/main.tscn

const MISSING_TEXTURE: Texture2D = preload("res://assets/sprites/environment/missing_texture.png")

## Glitch shown at 0% meter (none) and at 100% (subtle atmospheric glitch).
@export var calm_intensity: float = 0.0
@export var max_intensity: float = 0.14
## Seconds between random bursts when calm, and at 100% meter.
@export var burst_interval_calm: float = 30.0
@export var burst_interval_max: float = 3.0
@export var burst_strength: float = 0.18

@onready var world: SubViewport = $World

var _burst_left: float = 0.0
var _next_burst: float = 3.0
var _material: ShaderMaterial


func _ready() -> void:
	_material = material as ShaderMaterial


func _process(delta: float) -> void:
	if _material == null:
		return
	var meter: float = clampf(GameManager.current_cpu_overload / GameManager.max_cpu_overload, 0.0, 1.0)
	var intensity: float = lerpf(calm_intensity, max_intensity, meter * meter)

	if meter > 0.35:
		_next_burst -= delta
		if _next_burst <= 0.0:
			_start_burst(meter)
	if _burst_left > 0.0:
		_burst_left -= delta
		intensity = maxf(intensity, burst_strength * meter)

	_material.set_shader_parameter("intensity", intensity)


func _start_burst(meter: float) -> void:
	_burst_left = randf_range(0.08, 0.25)
	_next_burst = lerpf(burst_interval_calm, burst_interval_max, meter) * randf_range(0.5, 1.5)
	_material.set_shader_parameter("seed", randf() * 100.0)
	if meter > 0.2 or randf() < 0.5:
		_flash_missing_texture()
	if meter > 0.4:
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

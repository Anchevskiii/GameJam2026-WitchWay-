class_name Room
extends Node2D

## One room of the haunted house, built from an ASCII layout you edit in the Inspector.
## Attached to: the root Node2D of every scene in scenes/levels/ (living_room, dark_hallway, ...)
## With `procedural` on, HouseGenerator writes the layout and all settings below instead.
##
## Layout legend (one character = one 32x32 tile):
##   #  wall                    .  floor               (space) nothing
##   X  missing-texture wall    F  missing-texture FAKE wall (walk right through it!)
##   P  player start            D  exit door (put it in the outer wall)
##   &  a trick-or-treating kid (kids that start close together form a group)
##   any other letter is looked up in the legends below, in this order:
##     npc_legend (NpcData)            hide_legend (furniture you can hide in)
##     decor_legend (solid furniture)  floor_decor_legend (walk-over clutter: rugs, bones...)
##     light_legend (walk-over clutter that glows: candles)

const TILE_SIZE: int = 32
const TILE_SOURCE: int = 0
const WALL_TILE: Vector2i = Vector2i(2, 0)
const MISSING_SOLID_TILE: Vector2i = Vector2i(3, 0)
const MISSING_FAKE_TILE: Vector2i = Vector2i(4, 0)

const NPC_SCENE: PackedScene = preload("res://scenes/actors/npc.tscn")
const DOOR_SCENE: PackedScene = preload("res://scenes/objects/bugs/glitch_door.tscn")
const KID_SCENE: PackedScene = preload("res://scenes/actors/kid.tscn")
const LAMP_SCENE: PackedScene = preload("res://scenes/objects/wall_lamp.tscn")
const VENT_SCENE: PackedScene = preload("res://scenes/objects/traps_scares/air_vent.tscn")
const MASK_SCENE: PackedScene = preload("res://scenes/objects/mask_pickup.tscn")
const ROOM_DOOR_SCENE: PackedScene = preload("res://scenes/objects/interactables/room_door.tscn")
const KEY_SCENE: PackedScene = preload("res://scenes/objects/interactables/key_pickup.tscn")
const BED_TEX: Texture2D = preload("res://assets/sprites/objects/bed.png")
## Kids that start within this distance of each other form one group.
const KID_GROUP_RANGE: float = 130.0
const GLOW_TEXTURE: Texture2D = preload("res://assets/sprites/environment/light_radial.tres")
const HOUSE_TILES_TEX: Texture2D = preload("res://assets/sprites/environment/house_tiles.png")

## Scene files visited this run, so revisits can use shorter narrator lines.
static var _visited_scenes: Dictionary = {}

@export var room_title: String = "Room"
@export_multiline var objective: String = ""
@export_multiline var layout: String = ""
## Letter -> NpcData resource, e.g. {"g": ghost.tres}
@export var npc_legend: Dictionary = {}
## Letter -> Texture2D for furniture the player (and sneaky monsters) can hide in.
@export var hide_legend: Dictionary = {}
## Letter -> Texture2D for solid furniture, e.g. {"t": table.png}
@export var decor_legend: Dictionary = {}
## Letter -> Texture2D for clutter you walk over (rug, cobweb, bones). No collision.
@export var floor_decor_legend: Dictionary = {}
## Letter -> Texture2D for walk-over clutter that also gives off light (candles).
@export var light_legend: Dictionary = {}

@export_group("Generation")
## Build this room with HouseGenerator (endless levels) instead of the layout above.
@export var procedural: bool = false

@export_group("Exit")
## true = the door only disappears when CPU load hits 100%.
@export var exit_requires_cpu_overload: bool = false
@export var exit_requires_key: bool = false
## Seconds the overloaded door stays gone before it re-renders.
@export var door_open_time: float = 4.0

@export_group("Rules")
## Living Room: no sanity loss, sanity refilled, progress saved.
@export var is_safe_room: bool = false
## Multiplies prop CPU weights in this room.
@export var cpu_load_multiplier: float = 1.0
@export var flashlight_works: bool = true
## CanvasModulate colour. Near-black so rooms are dark and walls block vision into other rooms.
@export var ambient_color: Color = Color(0.025, 0.025, 0.04, 1)
## > 0: NPCs are invisible/missing-texture until the player is this close (pixels).
@export var npc_load_radius: float = 0.0
## Multiplies every NPC's wander radius. 0 = everyone stays in their spot (dinner party).
@export var npc_wander_scale: float = 1.0
## Monsters with hides_in_furniture may hide and ambush in this room (off for dinner parties).
@export var npcs_hide: bool = true
## Monsters chase their target while winding up (off for dinner parties: guests stay seated).
@export var npcs_chase: bool = true
## Difficulty: multiplies NPC wind-up time (lower = faster scares) and scare damage.
@export var npc_windup_scale: float = 1.0
@export var npc_damage_scale: float = 1.0

@export_group("Narrator")
@export var intro_lines: Array[String] = []
## Used instead of intro_lines when coming back to this room later in the run.
@export var revisit_lines: Array[String] = []

@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var floor_layer: TileMapLayer = $Floor
@onready var wall_layer: TileMapLayer = $Walls
@onready var decor_root: Node2D = $Decor
@onready var props_root: Node2D = $Props
@onready var actors_root: Node2D = $Actors
@onready var player: PlayerController = $Actors/Player


func _ready() -> void:
	if procedural:
		_apply_generated(HouseGenerator.new().generate(GameManager.current_level, randi()))

	props_root.add_to_group("prop_layer")
	if ambient_color.r > 0.1 or ambient_color.g > 0.1:
		ambient_color = Color(0.025, 0.025, 0.04, 1)
	canvas_modulate.color = ambient_color

	GameManager.is_safe_room = is_safe_room
	GameManager.cpu_load_multiplier = cpu_load_multiplier
	GameManager.reset_cpu_load()
	if is_safe_room:
		GameManager.refill_sanity()
		SaveManager.save_progress(GameManager.current_level)  # this Living Room = checkpoint

	_build_from_layout()
	_group_kids()
	player.set_flashlight_available(true)

	EventBus.room_entered.emit("Floor %d: %s" % [GameManager.current_level + 1, room_title], objective)
	Narrator.clear()
	var revisit: bool = _visited_scenes.has(scene_file_path) and not revisit_lines.is_empty()
	for line in (revisit_lines if revisit else intro_lines):
		Narrator.say(line)
	_visited_scenes[scene_file_path] = true


## Copies HouseGenerator's output (property name -> value) onto this room.
func _apply_generated(settings: Dictionary) -> void:
	for key in settings:
		set(key, settings[key])


var _layout_rows: PackedStringArray = []


func _get_layout_char(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= _layout_rows.size():
		return " "
	var row: String = _layout_rows[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return " "
	return row[cell.x]


func _build_from_layout() -> void:
	_layout_rows = layout.split("\n")
	for y in _layout_rows.size():
		var row: String = _layout_rows[y]
		for x in row.length():
			var ch: String = row[x]
			var cell := Vector2i(x, y)
			if ch == " ":
				continue
			if ch != "#" and ch != "X":
				floor_layer.set_cell(cell, TILE_SOURCE, Vector2i(posmod(x, 2), posmod(y, 2)))
			match ch:
				"#", "X":
					wall_layer.set_cell(cell, TILE_SOURCE, WALL_TILE)
					_spawn_wall_occluder(cell)
				"F":
					_spawn_phase_wall(cell)
				"P":
					player.global_position = cell_to_world(cell)
					player.camera.reset_smoothing()
				"D":
					_spawn_door(cell)
				"&":
					var kid: Kid = KID_SCENE.instantiate()
					kid.position = cell_to_world(cell)
					actors_root.add_child(kid)
				".":
					pass
				_:
					_spawn_from_legend(ch, cell)


func _spawn_wall_occluder(cell: Vector2i) -> void:
	var occluder := LightOccluder2D.new()
	occluder.position = cell_to_world(cell)
	occluder.occluder_light_mask = 1
	var poly := OccluderPolygon2D.new()
	poly.cull_mode = OccluderPolygon2D.CULL_DISABLED
	poly.polygon = PackedVector2Array([
		Vector2(-16, -16),
		Vector2(16, -16),
		Vector2(16, 16),
		Vector2(-16, 16)
	])
	occluder.occluder = poly
	decor_root.add_child(occluder)


## Spawns a bugged wall ("F") that looks identical to a normal brick wall,
## has NO collision (player can phase through it), NO shadow occluder,
## and subtly flickers so the observant player knows they can walk through it!
func _spawn_phase_wall(cell: Vector2i) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = HOUSE_TILES_TEX
	sprite.region_enabled = true
	sprite.region_rect = Rect2(64, 0, 32, 32)  # exact normal wall brick tile (2:0)
	sprite.position = cell_to_world(cell)
	sprite.z_index = 5
	sprite.light_mask = 2
	decor_root.add_child(sprite)

	var glitch_timer := Timer.new()
	glitch_timer.wait_time = randf_range(1.5, 3.2)
	glitch_timer.autostart = true
	sprite.add_child(glitch_timer)
	glitch_timer.timeout.connect(func() -> void:
		var tw: Tween = sprite.create_tween()
		tw.tween_property(sprite, "modulate:a", 0.45, 0.08)
		tw.parallel().tween_property(sprite, "position:x", sprite.position.x + randf_range(-1.5, 1.5), 0.08)
		tw.tween_property(sprite, "modulate:a", 1.0, 0.12)
		tw.parallel().tween_property(sprite, "position:x", cell_to_world(cell).x, 0.12)
		glitch_timer.wait_time = randf_range(2.0, 4.5)
	)


func _spawn_from_legend(ch: String, cell: Vector2i) -> void:
	if npc_legend.has(ch):
		var npc: Npc = NPC_SCENE.instantiate()
		npc.data = npc_legend[ch]
		npc.load_in_radius = npc_load_radius
		npc.wander_scale = npc_wander_scale
		npc.can_hide = npcs_hide
		npc.can_chase = npcs_chase
		npc.windup_scale = npc_windup_scale
		npc.damage_scale = npc_damage_scale
		npc.position = cell_to_world(cell)
		actors_root.add_child(npc)
	elif hide_legend.has(ch):
		var furniture: StaticBody2D = _spawn_decor(hide_legend[ch], cell)
		furniture.add_child(HideSpot.new())
	elif decor_legend.has(ch):
		_spawn_decor(decor_legend[ch], cell)
	elif floor_decor_legend.has(ch):
		_spawn_floor_decor(floor_decor_legend[ch], cell)
	elif light_legend.has(ch):
		var glow := PointLight2D.new()
		glow.texture = GLOW_TEXTURE
		glow.texture_scale = 0.45
		glow.energy = 0.75
		glow.color = Color(1.0, 0.75, 0.4)
		glow.range_item_cull_mask = 3
		glow.shadow_item_cull_mask = 1
		glow.shadow_enabled = true
		_spawn_floor_decor(light_legend[ch], cell).add_child(glow)
	elif ch == "l":
		var lamp: WallLamp = LAMP_SCENE.instantiate()
		lamp.position = cell_to_world(cell)
		decor_root.add_child(lamp)
	elif ch == "d":
		var door: RoomDoor = ROOM_DOOR_SCENE.instantiate()
		door.position = cell_to_world(cell)
		decor_root.add_child(door)
	elif ch == "B":
		var bed: StaticBody2D = _spawn_decor(BED_TEX, cell)
		bed.add_child(HideSpot.new())
	elif ch == "K":
		var key_item: KeyPickup = KEY_SCENE.instantiate()
		key_item.position = cell_to_world(cell)
		decor_root.add_child(key_item)
	elif ch == "v" or ch == "a":
		var vent: AirVent = VENT_SCENE.instantiate()
		vent.position = cell_to_world(cell)
		# Orient vent towards adjacent open floor tile
		var best_dir: Vector2 = Vector2.DOWN
		for dir in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor: Vector2i = cell + dir
			var ch_n: String = _get_layout_char(neighbor)
			if ch_n == "." or ch_n == "P" or ch_n == "r":
				best_dir = Vector2(dir)
				break
		vent.vent_direction = best_dir
		decor_root.add_child(vent)
	elif ch == "M":
		var mask_item: MaskPickup = MASK_SCENE.instantiate()
		mask_item.position = cell_to_world(cell)
		decor_root.add_child(mask_item)
	else:
		push_warning("Room '%s': unknown layout character '%s' at %s" % [room_title, ch, cell])


func _spawn_decor(texture: Texture2D, cell: Vector2i) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = cell_to_world(cell)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	body.add_child(sprite)
	var shape := RectangleShape2D.new()
	# Tighter collision so players don't snag on furniture edges
	shape.size = texture.get_size() * 0.75
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	decor_root.add_child(body)
	return body


## Walk-over clutter: drawn on the floor, under everyone, no collision.
func _spawn_floor_decor(texture: Texture2D, cell: Vector2i) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = cell_to_world(cell)
	sprite.z_index = -8
	decor_root.add_child(sprite)
	return sprite


func _spawn_door(cell: Vector2i) -> void:
	var door: GlitchDoor = DOOR_SCENE.instantiate()
	door.requires_cpu_overload = exit_requires_cpu_overload
	door.requires_key = exit_requires_key
	door.rerender_delay = door_open_time
	door.position = cell_to_world(cell)
	decor_root.add_child(door)


## The first kid of each cluster leads; the others follow it around.
func _group_kids() -> void:
	var kids: Array[Node] = get_tree().get_nodes_in_group("kids")
	for kid in kids:
		var k: Kid = kid as Kid
		if k.leader != null:
			continue
		k.leader = k
		for other in kids:
			var o: Kid = other as Kid
			if o.leader == null and o.global_position.distance_to(k.global_position) <= KID_GROUP_RANGE:
				o.leader = k


static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE_SIZE) + Vector2.ONE * TILE_SIZE * 0.5

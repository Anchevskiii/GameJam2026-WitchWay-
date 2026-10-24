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
## Kids that start within this distance of each other form one group.
const KID_GROUP_RANGE: float = 130.0
const GLOW_TEXTURE: Texture2D = preload("res://assets/sprites/environment/light_radial.tres")

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
## Seconds the overloaded door stays gone before it re-renders.
@export var door_open_time: float = 4.0

@export_group("Rules")
## Living Room: no sanity loss, sanity refilled, progress saved.
@export var is_safe_room: bool = false
## Multiplies prop CPU weights in this room.
@export var cpu_load_multiplier: float = 1.0
@export var flashlight_works: bool = true
## CanvasModulate colour. White = normal lighting, near-black = darkness room.
@export var ambient_color: Color = Color(1, 1, 1)
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
	canvas_modulate.color = ambient_color

	GameManager.is_safe_room = is_safe_room
	GameManager.cpu_load_multiplier = cpu_load_multiplier
	GameManager.reset_cpu_load()
	if is_safe_room:
		GameManager.refill_sanity()
		SaveManager.save_progress(GameManager.current_level)  # this Living Room = checkpoint

	_build_from_layout()
	_group_kids()
	player.set_flashlight_available(flashlight_works)

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


func _build_from_layout() -> void:
	var rows: PackedStringArray = layout.split("\n")
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch: String = row[x]
			var cell := Vector2i(x, y)
			if ch == " ":
				continue
			if ch != "#" and ch != "X":
				floor_layer.set_cell(cell, TILE_SOURCE, Vector2i(posmod(x, 2), posmod(y, 2)))
			match ch:
				"#":
					wall_layer.set_cell(cell, TILE_SOURCE, WALL_TILE)
				"X":
					wall_layer.set_cell(cell, TILE_SOURCE, MISSING_SOLID_TILE)
				"F":
					wall_layer.set_cell(cell, TILE_SOURCE, MISSING_FAKE_TILE)
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
		glow.texture_scale = 0.5
		glow.energy = 0.9
		glow.color = Color(1.0, 0.75, 0.4)
		_spawn_floor_decor(light_legend[ch], cell).add_child(glow)
	elif ch == "l":
		var lamp: WallLamp = LAMP_SCENE.instantiate()
		lamp.position = cell_to_world(cell)
		decor_root.add_child(lamp)
	elif ch == "v":
		var vent: AirVent = VENT_SCENE.instantiate()
		vent.position = cell_to_world(cell)
		decor_root.add_child(vent)
	elif ch == "M":
		var mask_item: MaskPickup = MASK_SCENE.instantiate()
		mask_item.position = cell_to_world(cell)
		decor_root.add_child(mask_item)
	else:
		push_warning("Room '%s': unknown layout character '%s' at %s" % [room_title, ch, cell])


func _spawn_decor(texture: Texture2D, cell: Vector2i) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = cell_to_world(cell)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	body.add_child(sprite)
	var shape := RectangleShape2D.new()
	shape.size = texture.get_size() * 0.85
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

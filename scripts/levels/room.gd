class_name Room
extends Node2D

## One room of the haunted house, built from an ASCII layout you edit in the Inspector.
## Attached to: the root Node2D of every scene in scenes/levels/ (living_room, dark_hallway, ...)
##
## Layout legend (one character = one 32x32 tile):
##   #  wall                    .  floor               (space) nothing
##   X  missing-texture wall    F  missing-texture FAKE wall (walk right through it!)
##   P  player start            D  exit door (put it in the outer wall)
##   any other letter: looked up in npc_legend (NpcData) or decor_legend (Texture2D)

const TILE_SIZE: int = 32
const TILE_SOURCE: int = 0
const WALL_TILE: Vector2i = Vector2i(2, 0)
const MISSING_SOLID_TILE: Vector2i = Vector2i(3, 0)
const MISSING_FAKE_TILE: Vector2i = Vector2i(4, 0)

const NPC_SCENE: PackedScene = preload("res://scenes/actors/npc.tscn")
const DOOR_SCENE: PackedScene = preload("res://scenes/objects/bugs/glitch_door.tscn")

@export var room_title: String = "Room"
@export_multiline var objective: String = ""
@export_multiline var layout: String = ""
## Letter -> NpcData resource, e.g. {"g": ghost.tres}
@export var npc_legend: Dictionary = {}
## Letter -> Texture2D for solid furniture, e.g. {"t": table.png}
@export var decor_legend: Dictionary = {}

@export_group("Exit")
@export_file("*.tscn") var next_room: String = ""
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

@export_group("Narrator")
@export var intro_lines: Array[String] = []

@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var floor_layer: TileMapLayer = $Floor
@onready var wall_layer: TileMapLayer = $Walls
@onready var decor_root: Node2D = $Decor
@onready var props_root: Node2D = $Props
@onready var actors_root: Node2D = $Actors
@onready var player: PlayerController = $Actors/Player


func _ready() -> void:
	props_root.add_to_group("prop_layer")
	canvas_modulate.color = ambient_color

	GameManager.is_safe_room = is_safe_room
	GameManager.cpu_load_multiplier = cpu_load_multiplier
	GameManager.reset_cpu_load()
	if is_safe_room:
		GameManager.refill_sanity()
		SaveManager.save_progress(GameManager.current_level)

	_build_from_layout()
	player.set_flashlight_available(flashlight_works)

	EventBus.room_entered.emit(room_title, objective)
	Narrator.clear()
	for line in intro_lines:
		Narrator.say(line)


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
		npc.position = cell_to_world(cell)
		actors_root.add_child(npc)
	elif decor_legend.has(ch):
		_spawn_decor(decor_legend[ch], cell)
	else:
		push_warning("Room '%s': unknown layout character '%s' at %s" % [room_title, ch, cell])


func _spawn_decor(texture: Texture2D, cell: Vector2i) -> void:
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


func _spawn_door(cell: Vector2i) -> void:
	var door: GlitchDoor = DOOR_SCENE.instantiate()
	door.requires_cpu_overload = exit_requires_cpu_overload
	door.next_room = next_room
	door.rerender_delay = door_open_time
	door.position = cell_to_world(cell)
	decor_root.add_child(door)


static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE_SIZE) + Vector2.ONE * TILE_SIZE * 0.5

class_name Room
extends Node2D

## One room of the haunted house, built from an ASCII layout you edit in the Inspector.
## Attached to: the root Node2D of every scene in scenes/levels/ (living_room, dark_hallway, ...)
## With `procedural` on, HouseGenerator writes the layout and all settings below instead.
##
## Layout legend (one character = one 32x32 tile):
##   #  wall                    .  floor               (space) nothing
##   X  wall (same as #)        F  FAKE wall: looks like a wall, a bit buggy - walk right through it!
##   P  player start            D  exit door (put it in the outer wall)
##   &  a trick-or-treating kid (kids that start close together form a group)
##   +  covered by a multi-tile piece of furniture (blocked)
##   any other letter is looked up in the legends below, in this order:
##     wall_decor_legend (FurnitureData on a WALL tile: windows, paintings - still a wall)
##     npc_legend (NpcData)            furniture_legend (FurnitureData: letter = top-left tile)
##     hide_legend (furniture you can hide in)          decor_legend (solid furniture)
##     floor_decor_legend (walk-over clutter: rugs, bones...)
##     light_legend (walk-over clutter that glows: candles)
##
## 3/4 view: a wall tile with floor below it is drawn as a wallpapered wall face, every other
## wall tile as lavender ceiling. Floors and wallpaper come from the RoomTheme (default_theme,
## or per area via `zones` on generated floors).

const TILE_SIZE: int = 32
const TILE_SOURCE: int = 0
const WALL_TILE: Vector2i = Vector2i(2, 0)

const NPC_SCENE: PackedScene = preload("res://scenes/actors/npc.tscn")
const DOOR_SCENE: PackedScene = preload("res://scenes/objects/bugs/glitch_door.tscn")
const KID_SCENE: PackedScene = preload("res://scenes/actors/kid.tscn")
const MASK_SCENE: PackedScene = preload("res://scenes/objects/mask_pickup.tscn")
const LAMP_SCENE: PackedScene = preload("res://scenes/objects/wall_lamp.tscn")
## Kids that start within this distance of each other form one group.
const KID_GROUP_RANGE: float = 130.0
const MASK_RESPAWN_DELAY: float = 14.0
const ENTITY_CHECK_INTERVAL: float = 7.0
const GLOW_TEXTURE: Texture2D = preload("res://assets/sprites/environment/light_radial.tres")
const FALLBACK_THEME: RoomTheme = preload("res://data/themes/living_room.tres")
## Layout of assets/sprites/interiors/house_interior.png (see the build script).
const CEILING_ROW: int = 0
const WALLPAPER_ROW: int = 2       ## 1-tile wall face (wall 1 tile thick)
const FLOOR_ROW: int = 12
const FACE_BOTTOM_ROW: int = 22    ## 2-tile wall face, lower half (wall 2+ tiles thick)
const FACE_TOP_ROW: int = 32       ## 2-tile wall face, upper half with the ceiling band
## Plain ceiling tile (its outline is drawn by WallOutlines), and the height of the ceiling
## band at the top of a 2-tile wall face.
const CEILING_TILE: Vector2i = Vector2i(7, CEILING_ROW + 1)
const BAND: float = 10.0
## Wall decorations keep this many pixels away from corners and doorways.
const WALL_DECOR_MARGIN: float = 3.0

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
## Letter -> FurnitureData (bookshelves, beds, lamps, rugs...). The letter marks the top-left
## tile of the piece; fill the rest of its footprint with "+".
@export var furniture_legend: Dictionary = {}
## Letter -> FurnitureData hung on a WALL tile (window, painting, mirror). The tile stays a wall.
@export var wall_decor_legend: Dictionary = {}

@export_group("Look")
## Wallpaper, floor and furniture set used everywhere a zone doesn't say otherwise.
@export var default_theme: RoomTheme
## Generated floors: [[Rect2i area, RoomTheme], ...] so every room of the house gets its own look.
@export var zones: Array = []

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
## CanvasModulate colour. Darkened on haunted floors so rooms feel eerie and other rooms aren't visible.
@export var ambient_color: Color = Color(0.05, 0.045, 0.08)
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
@export var npc_speed_scale: float = 1.0
@export var npc_sight_scale: float = 1.0
## Multiplies how fast standing still / hiding restores sanity (< 1 on deeper floors).
@export var sanity_regen_scale: float = 1.0

@export_group("Haunting")
## Keys the exit needs (hidden in searchable furniture). 0 = the exit isn't locked.
@export var keys_needed: int = 0
## What's inside searchable furniture, by the furniture's top-left cell: Vector2i -> Searchable.Contents.
## Pieces not listed get candy or nothing (and, outside safe rooms, sometimes a scare).
@export var search_contents: Dictionary = {}
## Floor traps: [Vector2i cell, "bear" | "creak" | "jumpscare"], ...
@export var traps: Array = []
## The Stalker's speed when the house wakes up (after the last key).
@export var stalker_speed: float = 95.0

@export_group("Narrator")
@export var intro_lines: Array[String] = []
## Used instead of intro_lines when coming back to this room later in the run.
@export var revisit_lines: Array[String] = []

@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var floor_layer: TileMapLayer = $Floor
@onready var wall_layer: TileMapLayer = $Walls
@onready var wall_top_layer: TileMapLayer = $WallTops
@onready var glitch_layer: TileMapLayer = $GlitchWalls
@onready var decor_root: Node2D = $Decor
@onready var props_root: Node2D = $Props
@onready var actors_root: Node2D = $Actors
@onready var player: PlayerController = $Actors/Player


func _ready() -> void:
	if procedural:
		_apply_generated(HouseGenerator.new().generate(GameManager.current_level, randi()))

	props_root.add_to_group("prop_layer")
	actors_root.add_to_group("actors_root")
	if not is_safe_room and (ambient_color.r > 0.12 or ambient_color.g > 0.12):
		ambient_color = Color(0.05, 0.045, 0.08, 1.0)
	canvas_modulate.color = ambient_color

	GameManager.is_safe_room = is_safe_room
	GameManager.cpu_load_multiplier = cpu_load_multiplier
	GameManager.sanity_regen_scale = sanity_regen_scale
	GameManager.reset_cpu_load()
	if is_safe_room:
		GameManager.refill_sanity()
		SaveManager.save_progress(GameManager.current_level)  # this Living Room = checkpoint

	GameManager.set_keys_needed(keys_needed)
	_build_from_layout()
	_build_wall_outlines()
	_spawn_traps()
	_spawn_initial_masks()
	_spawn_wall_lamps()
	_group_kids()
	add_child(Dread.new())
	EventBus.house_awakened.connect(_on_house_awakened)
	player.set_flashlight_available(flashlight_works)

	EventBus.room_entered.emit("Floor %d: %s" % [GameManager.current_level + 1, room_title], objective)
	Narrator.clear()
	var revisit: bool = _visited_scenes.has(scene_file_path) and not revisit_lines.is_empty()
	for line in (revisit_lines if revisit else intro_lines):
		Narrator.say(line)
	_visited_scenes[scene_file_path] = true


var _entity_spawn_timer: float = 0.0


func _process(delta: float) -> void:
	if is_safe_room or GameManager.is_game_over:
		return
	_entity_spawn_timer += delta
	if _entity_spawn_timer >= ENTITY_CHECK_INTERVAL:
		_entity_spawn_timer = 0.0
		_check_respawn_entities()


## Periodically spawns a replacement monster away from the player when most monsters are disabled,
## ensuring the player never runs out of targets (especially on CPU overload floors).
func _check_respawn_entities() -> void:
	if npc_legend.is_empty() or not is_instance_valid(player):
		return
	var npcs: Array[Node] = get_tree().get_nodes_in_group("npcs")
	var active_count: int = 0
	for n in npcs:
		var npc: Npc = n as Npc
		if is_instance_valid(npc) and npc.state != Npc.State.DONE:
			active_count += 1

	var desired_count: int = 2 + mini(GameManager.current_level / 3, 3)
	if exit_requires_cpu_overload:
		desired_count += 2
	if active_count >= desired_count:
		return

	var spawn_candidates: Array[Vector2i] = []
	for y in range(1, _rows.size() - 1):
		for x in range(1, _rows[y].length() - 1):
			if _rows[y][x] == ".":
				var world_p: Vector2 = cell_to_world(Vector2i(x, y))
				if world_p.distance_to(player.global_position) > 200.0:
					spawn_candidates.append(Vector2i(x, y))
	if spawn_candidates.is_empty():
		return
	var cell: Vector2i = spawn_candidates[randi() % spawn_candidates.size()]
	var npc: Npc = NPC_SCENE.instantiate()
	var keys: Array = npc_legend.keys()
	var k: String = keys[randi() % keys.size()]
	npc.data = npc_legend[k]
	npc.load_in_radius = npc_load_radius
	npc.wander_scale = maxf(npc_wander_scale, 0.7)
	npc.can_hide = npcs_hide
	npc.can_chase = true
	npc.windup_scale = npc_windup_scale
	npc.damage_scale = npc_damage_scale
	npc.speed_scale = npc_speed_scale
	npc.sight_scale = npc_sight_scale
	npc.position = cell_to_world(cell)
	actors_root.add_child(npc)


## Copies HouseGenerator's output (property name -> value) onto this room.
func _apply_generated(settings: Dictionary) -> void:
	for key in settings:
		set(key, settings[key])


func _build_from_layout() -> void:
	if default_theme == null:
		default_theme = FALLBACK_THEME
	_rows = layout.split("\n")
	for y in _rows.size():
		var row: String = _rows[y]
		for x in row.length():
			var ch: String = row[x]
			var cell := Vector2i(x, y)
			if ch == " ":
				continue
			if not _is_wall(ch):
				_paint_floor(cell)
			if ch == "#" or ch == "X" or wall_decor_legend.has(ch):
				wall_layer.set_cell(cell, TILE_SOURCE, WALL_TILE)  # invisible: collision only
				_paint_wall_top(cell)
				if wall_decor_legend.has(ch):
					_spawn_wall_decor(wall_decor_legend[ch], cell)
				continue
			match ch:
				"F":
					_paint_wall_top(cell)  # looks like a wall (a bit buggy), has no collision
				"P":
					player.global_position = cell_to_world(cell)
					player.camera.reset_smoothing()
				"D":
					_spawn_door(cell)
				"&":
					var kid: Kid = KID_SCENE.instantiate()
					kid.position = cell_to_world(cell)
					actors_root.add_child(kid)
				".", "+":
					pass
				_:
					_spawn_from_legend(ch, cell)


# ---------------------------------------------------------------- 3/4 view tiles

var _rows: PackedStringArray = []


func _char_at(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= _rows.size() or cell.x < 0 or cell.x >= _rows[cell.y].length():
		return " "
	return _rows[cell.y][cell.x]


func _is_wall(ch: String) -> bool:
	return ch == "#" or ch == "X" or wall_decor_legend.has(ch)


## Walls and fake walls (F: drawn like a wall, but you can walk through it).
func _looks_like_wall(ch: String) -> bool:
	return _is_wall(ch) or ch == "F"


## Walls, the void outside, and fake walls all count as "solid" for drawing.
func _looks_solid(cell: Vector2i) -> bool:
	var ch: String = _char_at(cell)
	return _looks_like_wall(ch) or ch == " "


## Fake walls go on the GlitchWalls layer (its shader makes them twitch); the rest on WallTops.
func _wall_layer_for(cell: Vector2i) -> TileMapLayer:
	return glitch_layer if _char_at(cell) == "F" else wall_top_layer


func _paint_floor(cell: Vector2i) -> void:
	var pattern: int = theme_at(cell).floor_pattern
	var origin := Vector2i((pattern % 2) * 3, FLOOR_ROW + (pattern / 2) * 2)
	floor_layer.set_cell(cell, TILE_SOURCE, origin + Vector2i(posmod(cell.x, 3), posmod(cell.y, 2)))


## A wall with floor below it is a wall FACE (wallpaper of the room below). If the wall is
## 2+ tiles thick the face is 2 tiles tall, like in the reference art. Any other wall is
## CEILING, outlined on every side that doesn't touch another wall.
func _paint_wall_top(cell: Vector2i) -> void:
	var below: Vector2i = cell + Vector2i.DOWN
	if not _looks_solid(below):
		var wallpaper: int = theme_at(below).wallpaper
		var column: int = posmod(cell.x, 3)
		var above: Vector2i = cell + Vector2i.UP
		if _looks_like_wall(_char_at(above)):
			_wall_layer_for(cell).set_cell(cell, TILE_SOURCE, Vector2i(column, FACE_BOTTOM_ROW + wallpaper))
			_wall_layer_for(above).set_cell(above, TILE_SOURCE, Vector2i(column, FACE_TOP_ROW + wallpaper))
		else:
			_wall_layer_for(cell).set_cell(cell, TILE_SOURCE, Vector2i(column, WALLPAPER_ROW + wallpaper))
		return
	if _is_face_top(cell):
		return  # already painted as the upper half of the wall face below it
	_wall_layer_for(cell).set_cell(cell, TILE_SOURCE, CEILING_TILE)


## Is the TOP part of this tile ceiling (lavender)? Ceiling tiles, the band of a face top,
## and the void outside the house are; wall faces and floor aren't.
func _ceiling_upper(cell: Vector2i) -> bool:
	return _looks_solid(cell) and not _is_face_bottom(cell)


## Is the LOWER part of this tile ceiling? Only full ceiling tiles (and the void).
func _ceiling_lower(cell: Vector2i) -> bool:
	return _ceiling_upper(cell) and not _is_face_top(cell)


## A wall tile with floor right below it (shows wallpaper).
func _is_face_bottom(cell: Vector2i) -> bool:
	return _looks_like_wall(_char_at(cell)) and not _looks_solid(cell + Vector2i.DOWN)


## The dark outline around every piece of ceiling, worked out on half-tiles (the band at the
## top of a wall face is ceiling, the wallpaper below it isn't) and including the diagonal
## neighbours, so inside corners are filled too.
func _build_wall_outlines() -> void:
	var outlines := WallOutlines.new()
	outlines.z_index = -4
	var t: float = TILE_SIZE
	for y in _rows.size():
		for x in _rows[y].length():
			var c := Vector2i(x, y)
			var full: bool = _looks_like_wall(_char_at(c)) and _ceiling_lower(c)
			var band: bool = _is_face_top(c)
			if not full and not band:
				continue
			var o := Vector2(c) * t
			var up: Vector2i = c + Vector2i.UP
			var down: Vector2i = c + Vector2i.DOWN
			# Top edge: 2px where it lines up with a band, 4px on plain ceiling.
			var top: float = 2.0 if band or _is_face_top(c + Vector2i.LEFT) or _is_face_top(c + Vector2i.RIGHT) else 4.0
			if not _ceiling_lower(up):
				outlines.rects.append(Rect2(o, Vector2(t, top)))
			for side in [Vector2i.LEFT, Vector2i.RIGHT]:
				var sx: float = o.x if side == Vector2i.LEFT else o.x + t - 4.0
				# Inside corner at the top: ceiling above and beside, but not diagonally.
				if _ceiling_lower(up) and _ceiling_upper(c + side) and not _ceiling_lower(up + side):
					outlines.rects.append(Rect2(sx, o.y, 4.0, top))
				# Side edge: upper part (band level), then the rest of a full ceiling tile.
				if not _ceiling_upper(c + side):
					outlines.rects.append(Rect2(sx, o.y, 4.0, BAND + (3.0 if band else 0.0)))
				if full and not _ceiling_lower(c + side):
					outlines.rects.append(Rect2(sx, o.y + BAND, 4.0, t - BAND))
				# Inside corner at the bottom.
				if full and _ceiling_upper(down) and _ceiling_lower(c + side) and not _ceiling_upper(down + side):
					outlines.rects.append(Rect2(sx, o.y + t - 4.0, 4.0, 4.0))
			if full and not _ceiling_upper(down):
				outlines.rects.append(Rect2(o.x, o.y + t - 4.0, t, 4.0))
	add_child(outlines)


## True for the upper tile of a 2-tile wall face (a wall whose wall below has floor below it).
func _is_face_top(cell: Vector2i) -> bool:
	if not _looks_like_wall(_char_at(cell)):
		return false
	var below: Vector2i = cell + Vector2i.DOWN
	return _looks_like_wall(_char_at(below)) and not _looks_solid(below + Vector2i.DOWN)


## The theme of the area a tile belongs to (doorways borrow a neighbour's).
func theme_at(cell: Vector2i) -> RoomTheme:
	for probe in [cell, cell + Vector2i.DOWN, cell + Vector2i.UP, cell + Vector2i.LEFT, cell + Vector2i.RIGHT]:
		for zone in zones:
			if (zone[0] as Rect2i).has_point(probe):
				return zone[1]
	return default_theme


func _spawn_from_legend(ch: String, cell: Vector2i) -> void:
	if furniture_legend.has(ch):
		_spawn_furniture(furniture_legend[ch], cell)
	elif npc_legend.has(ch):
		var npc: Npc = NPC_SCENE.instantiate()
		npc.data = npc_legend[ch]
		npc.load_in_radius = npc_load_radius
		npc.wander_scale = npc_wander_scale
		npc.can_hide = npcs_hide
		npc.can_chase = npcs_chase
		npc.windup_scale = npc_windup_scale
		npc.damage_scale = npc_damage_scale
		npc.speed_scale = npc_speed_scale
		npc.sight_scale = npc_sight_scale
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
	elif ch == "M":
		_spawn_mask_at(cell_to_world(cell))
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


## A piece from the interior sheet, standing on the bottom edge of its footprint
## (`cell` = top-left tile). Tall pieces rise over the wall behind them (3/4 view);
## only the footprint collides. The node sits at the footprint's bottom edge, which is
## what Y-sorting uses, so characters pass in front of / behind it correctly.
func _spawn_furniture(piece: FurnitureData, cell: Vector2i) -> void:
	var size := Vector2(piece.footprint * TILE_SIZE)
	var top_left := Vector2(cell * TILE_SIZE)
	var sprite := Sprite2D.new()
	sprite.texture = piece.texture
	if piece.kind == FurnitureData.Kind.RUG:
		sprite.position = top_left + size * 0.5
		sprite.z_index = -8
		decor_root.add_child(sprite)
		return
	var body := StaticBody2D.new()
	body.position = top_left + Vector2(size.x * 0.5, size.y - 2.0)
	sprite.offset = Vector2(0, -piece.texture.get_height() * 0.5)
	body.add_child(sprite)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(size.x - 6.0, size.y - 8.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -size.y * 0.5)
	body.add_child(collision)
	if piece.hideable:
		var spot := HideSpot.new()
		spot.position = Vector2(0, -size.y * 0.5)
		body.add_child(spot)
	elif piece.searchable:
		var drawer := Searchable.new()
		drawer.position = Vector2(0, -size.y * 0.5)
		drawer.contents = search_contents.get(cell, _random_contents())
		body.add_child(drawer)
	if piece.emits_light():
		var glow := PointLight2D.new()
		glow.name = "PointLight2D"
		glow.texture = GLOW_TEXTURE
		glow.texture_scale = 0.65
		glow.energy = 0.9
		glow.color = piece.light_color
		glow.position = Vector2(0, -piece.texture.get_height() * 0.6)
		if is_safe_room:
			body.add_child(glow)
		else:
			var lamp_controller := WallLamp.new()
			lamp_controller.light_energy = 0.9
			lamp_controller.light_color = piece.light_color
			lamp_controller.light_scale = 0.65
			lamp_controller.add_child(glow)
			body.add_child(lamp_controller)
	decor_root.add_child(body)


## Windows, paintings and mirrors hang on a wall face, just above the skirting.
## Pieces wider than a tile are kept on their own stretch of wall: never over a corner,
## a doorway or into a side wall (nudged sideways, or left out if the wall is too short).
func _spawn_wall_decor(piece: FurnitureData, cell: Vector2i) -> void:
	if not _is_wall_face(cell):
		return  # not a wall face (no room below it): nothing to hang it on
	var width: float = piece.texture.get_width()
	# The run of wall face this cell is part of, in pixels (a little margin at each end).
	var first: int = cell.x
	while _is_wall_face(Vector2i(first - 1, cell.y)):
		first -= 1
	var last: int = cell.x
	while _is_wall_face(Vector2i(last + 1, cell.y)):
		last += 1
	var run_left: float = first * TILE_SIZE + WALL_DECOR_MARGIN
	var run_right: float = (last + 1) * TILE_SIZE - WALL_DECOR_MARGIN
	if width > run_right - run_left:
		return
	var x: float = clampf(cell.x * TILE_SIZE + TILE_SIZE * 0.5, run_left + width * 0.5, run_right - width * 0.5)
	var sprite := Sprite2D.new()
	sprite.texture = piece.texture
	if _is_wall(_char_at(cell + Vector2i.UP)):
		sprite.position = Vector2(x, cell.y * TILE_SIZE + 6.0)  # centred on a 2-tile wall
	else:
		sprite.position = Vector2(x, (cell.y + 1) * TILE_SIZE - 7.0 - piece.texture.get_height() * 0.5)
	sprite.z_index = -4
	decor_root.add_child(sprite)


## A real wall tile with floor right below it: the visible, wallpapered face of a wall.
func _is_wall_face(cell: Vector2i) -> bool:
	return _is_wall(_char_at(cell)) and not _looks_solid(cell + Vector2i.DOWN)


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
	door.room = self
	door.position = cell_to_world(cell)
	decor_root.add_child(door)


## Walking distance in tiles between two points, around walls (furniture is ignored).
## Returns -1 if `to` can't be reached. Used by the exit door to give the player time.
func walking_tiles(from: Vector2, to: Vector2) -> int:
	var start := Vector2i((from / TILE_SIZE).floor())
	var goal := Vector2i((to / TILE_SIZE).floor())
	var dist: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		if c == goal:
			return dist[c]
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			var ch: String = _char_at(n)
			if not dist.has(n) and ch != " " and not _is_wall(ch):
				dist[n] = dist[c] + 1
				queue.append(n)
	return -1


## Unlisted drawers: mostly empty, some candy, and (not in safe rooms) the odd nasty surprise.
func _random_contents() -> Searchable.Contents:
	var roll: float = randf()
	if roll < 0.3:
		return Searchable.Contents.CANDY
	if roll < 0.4 and not is_safe_room:
		return Searchable.Contents.SCARE
	return Searchable.Contents.NOTHING


func _spawn_traps() -> void:
	for entry in traps:
		var trap: FloorTrap
		match String(entry[1]):
			"bear":
				trap = BearTrap.new()
			"creak":
				trap = CreakyBoard.new()
			"jumpscare":
				var trigger := JumpscareTrigger.new()
				trigger.npc_windup_scale = npc_windup_scale
				trigger.npc_damage_scale = npc_damage_scale
				trigger.npc_speed_scale = npc_speed_scale
				trap = trigger
			_:
				push_warning("Room '%s': unknown trap '%s'" % [room_title, entry[1]])
				continue
		trap.position = cell_to_world(entry[0])
		decor_root.add_child(trap)


## Spawns disguise masks on haunted floors (and respawns them elsewhere after being picked up).
func _spawn_initial_masks() -> void:
	if is_safe_room:
		return
	var existing: int = 0
	for c in decor_root.get_children():
		if c is MaskPickup:
			existing += 1
	var target_count: int = 2 if procedural else 1
	for i in maxi(0, target_count - existing):
		_respawn_mask(player.global_position if is_instance_valid(player) else Vector2.ZERO)


func _spawn_mask_at(world_pos: Vector2) -> void:
	var mask_item: MaskPickup = MASK_SCENE.instantiate()
	mask_item.position = world_pos
	mask_item.collected.connect(_on_mask_collected)
	decor_root.add_child(mask_item)


func _on_mask_collected(from_pos: Vector2) -> void:
	get_tree().create_timer(MASK_RESPAWN_DELAY).timeout.connect(_respawn_mask.bind(from_pos))


func _respawn_mask(old_pos: Vector2) -> void:
	if GameManager.is_game_over or not is_instance_valid(player):
		return
	var occupied: Array[Vector2] = []
	for g in ["npcs", "kids"]:
		for n in get_tree().get_nodes_in_group(g):
			occupied.append((n as Node2D).global_position)
	var best: Array[Vector2i] = []
	for y in range(1, _rows.size() - 1):
		for x in range(1, _rows[y].length() - 1):
			if _rows[y][x] != ".":
				continue
			var wp: Vector2 = cell_to_world(Vector2i(x, y))
			if wp.distance_to(player.global_position) < 160.0 or wp.distance_to(old_pos) < 140.0:
				continue
			var clear: bool = true
			for o in occupied:
				if wp.distance_to(o) < 100.0:
					clear = false
					break
			if clear:
				best.append(Vector2i(x, y))
	if best.is_empty():
		get_tree().create_timer(10.0).timeout.connect(_respawn_mask.bind(old_pos))
		return
	_spawn_mask_at(cell_to_world(best[randi() % best.size()]))


## Spawns flickering wall sconces on bare back-wall stretches so some rooms have eerie wall lighting.
func _spawn_wall_lamps() -> void:
	if is_safe_room:
		return
	var placed: Array[Vector2] = []
	for y in range(1, _rows.size() - 1):
		for x in range(2, _rows[y].length() - 2):
			var cell := Vector2i(x, y)
			# Bare wall face (not already holding a window/painting) with open floor below
			if _char_at(cell) != "#" or not _is_wall_face(cell):
				continue
			if _char_at(cell + Vector2i.LEFT) != "#" or _char_at(cell + Vector2i.RIGHT) != "#":
				continue
			var wp: Vector2 = cell_to_world(cell)
			var too_close: bool = false
			for p in placed:
				if wp.distance_to(p) < 220.0:
					too_close = true
					break
			if too_close or randf() > 0.28:
				continue
			var lamp: WallLamp = LAMP_SCENE.instantiate()
			if _is_wall(_char_at(cell + Vector2i.UP)):
				lamp.position = Vector2(wp.x, cell.y * TILE_SIZE + 8.0)
			else:
				lamp.position = Vector2(wp.x, (cell.y + 1) * TILE_SIZE - 16.0)
			decor_root.add_child(lamp)
			placed.append(wp)


## The last key was taken: lights fail, everything hears it, and the Stalker comes -
## from behind you (the side away from the exit), so it chases rather than blocks.
func _on_house_awakened() -> void:
	AudioManager.play("slam", 1.5)
	Narrator.say_event("house_awake", {}, true)
	var dark: Color = ambient_color * Color(0.6, 0.55, 0.6)
	var tween: Tween = create_tween()
	for i in 4:
		tween.tween_property(canvas_modulate, "color", Color(0.05, 0.02, 0.04), 0.06)
		tween.tween_property(canvas_modulate, "color", ambient_color, 0.08)
	tween.tween_property(canvas_modulate, "color", Color(dark.r, dark.g, dark.b), 0.6)
	EventBus.noise_made.emit(player.global_position, 600.0)
	var away: Vector2 = Vector2.LEFT
	for c in decor_root.get_children():
		if c is GlitchDoor:
			away = (c as Node2D).global_position.direction_to(player.global_position)
	var stalker := Stalker.new()
	stalker.start_speed = stalker_speed
	stalker.max_speed = stalker_speed * 1.5
	stalker.position = player.global_position + away * 420.0
	actors_root.add_child(stalker)


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

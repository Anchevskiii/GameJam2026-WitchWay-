class_name HouseGenerator
extends RefCounted

## Writes a random haunted-house floor as an ASCII layout + Room settings (endless levels).
## Usage (Room does this when `procedural` is on):
##   var settings: Dictionary = HouseGenerator.new().generate(level, seed)
##   for key in settings: room.set(key, settings[key])
##
## How it works:
##   1. BSP: the floor is cut in two by a wall again and again; every cut gets a 2-tile
##      doorway, so every room is reachable by construction.
##   2. Start room is random, the exit goes in the outer wall of the room farthest away.
##   3. Every room gets a RoomTheme (library, bedroom, kitchen...) and is furnished from it:
##      a showpiece in the middle of the back wall, the rest of the wall lined with furniture
##      (always one hiding spot), pictures on the bare wall, a table with chairs on a rug,
##      plants/lamps in the corners and clutter on the floor.
##      Monsters go everywhere except the start room.
##   Horizontal walls are 2 tiles thick so rooms get the tall 3/4-view back walls.
##   4. Two kinds of "bug" level, alternating:
##        DARK      lights off, exit walled in - one of the walls is fake (it looks a bit buggy).
##        OVERLOAD  a dinner party: crash the CPU to 100% so the exit door stops rendering.
##   5. Everything is flood-fill checked; a bad roll is simply re-rolled with the next seed.

enum Kind { DARK, OVERLOAD }

const MIN_ROOM_W: int = 6
const MIN_ROOM_H: int = 5
## Rooms bigger than this are always cut again (big floors get more rooms, not emptier ones).
const MAX_ROOM_W: int = 14
const MAX_ROOM_H: int = 10
## Thickness of horizontal walls (2 = tall wallpapered back walls).
const H_WALL: int = 2
const MAX_ATTEMPTS: int = 40

const NPC_PATHS: Dictionary = {
	"g": "res://data/npcs/ghost.tres",
	"m": "res://data/npcs/tired_vampire.tres",
	"h": "res://data/npcs/witch.tres",
	"w": "res://data/npcs/werewolf.tres",
	"b": "res://data/npcs/bat.tres",
	"j": "res://data/npcs/jack_o_lantern.tres",
	"G": "res://data/npcs/big_jack.tres",
}
const WANDERERS: String = "gmhwb"
## Dinner guests carry real luggage (no bats - they only drop a sock), so the party can
## always crash the CPU. The witch (cauldron!) is always invited.
const PARTY_GUESTS: String = "gmhw"
const OBJ: String = "res://assets/sprites/objects/%s.png"
const DECOR_ITEMS: Dictionary = {"T": "dining_table"}
const FLOOR_ITEMS: Dictionary = {"o": "cobweb", "n": "bones", "u": "pumpkin"}
const LIGHT_ITEMS: Dictionary = {"c": "candles"}

const THEME: String = "res://data/themes/%s.tres"
const ROOM_THEMES: Array[String] = ["library", "bedroom", "study", "kitchen", "storage", "living_room", "dining"]
const DARK_ROOM_THEMES: Array[String] = ["storage", "library", "bedroom", "storage", "study"]
## Layout letters handed out to the furniture used on a floor (none clash with NPCs/specials).
const CHAR_POOL: String = "0123456789ABCEHIJKLNOQRSUVWYZadefiklpqstvxyz!$%=?@^~*-_;:<>,|"

const DARK_TITLES: Array[String] = ["The Basement (Lights Not Included)", "The Attic of Unloaded Textures",
	"The Servants' Corridor", "The Cellar, Probably", "The Unrendered Wing", "The Laundry Room of Regret"]
const PARTY_TITLES: Array[String] = ["The Ballroom (Unoptimized)", "The Banquet Hall", "The Kitchen (Too Many Pots)",
	"The Grand Hall of Polygons", "The Guest Wing (Many Guests)", "The Library Party"]

var rng := RandomNumberGenerator.new()

var _w: int
var _h: int
var _grid: Array = []          # _grid[y][x] -> single-character String
var _leaves: Array[Rect2i] = []  # rooms (floor area, walls excluded)
var _doorways: Array[Vector2i] = []
var _reserved: Dictionary = {}   # cells nothing may be placed on (door fronts, doorways)
var _zones: Array = []           # [[Rect2i room, RoomTheme], ...]
var _piece_chars: Dictionary = {}       # FurnitureData -> layout letter
var _furniture_legend: Dictionary = {}  # letter -> FurnitureData
var _wall_decor_legend: Dictionary = {} # letter -> FurnitureData (on wall tiles)
var _walk_over: Dictionary = {}         # letters you can walk on (rugs)
var _party_room: Rect2i = Rect2i()
var _piece_at: Dictionary = {}          # cell -> FurnitureData standing there
var _piece_origins: Array = []          # [[top-left cell, FurnitureData], ...] in placing order
var _search_contents: Dictionary = {}   # top-left cell -> Searchable.Contents
var _traps: Array = []                  # [[cell, "bear" | "creak" | "jumpscare"], ...]
var _room_has_hide: bool = false        # the room being furnished has a hiding spot
var _shop_room: Rect2i = Rect2i()       # bright monster-free room with the vending machine
var _shop_cell: Vector2i = Vector2i(-1, -1)


## Returns Room property name -> value. `level` sets difficulty and the level kind.
func generate(level: int, seed_value: int) -> Dictionary:
	var tier: int = GameManager.difficulty_tier(level)
	# Same order as the hand-made rooms: 1st room after a Living Room is dark, 2nd is the party.
	var kind: Kind = Kind.DARK if level % GameManager.LIVING_ROOM_EVERY == 1 else Kind.OVERLOAD
	for attempt in MAX_ATTEMPTS:
		rng.seed = seed_value + attempt * 7919
		var settings: Dictionary = _try_generate(tier, kind)
		if not settings.is_empty():
			return settings
	push_error("HouseGenerator: no valid layout after %d attempts (level %d)" % [MAX_ATTEMPTS, level])
	return {}


func _try_generate(tier: int, kind: Kind) -> Dictionary:
	_w = 28 + mini(tier, 5) * 3
	_h = 20 + mini(tier, 5) * 2
	_grid.clear()
	_leaves.clear()
	_doorways.clear()
	_reserved.clear()
	_zones.clear()
	_piece_chars.clear()
	_furniture_legend.clear()
	_wall_decor_legend.clear()
	_walk_over.clear()
	_piece_at.clear()
	_piece_origins.clear()
	_search_contents.clear()
	_traps.clear()
	_party_room = Rect2i()
	for y in _h:
		var row: Array = []
		for x in _w:
			row.append("#" if x == 0 or y < H_WALL or x == _w - 1 or y == _h - 1 else ".")
		_grid.append(row)

	_split(Rect2i(1, H_WALL, _w - 2, _h - H_WALL - 1), 0)
	for cell in _doorways:
		_reserve_around(cell)

	var start_room: Rect2i = _leaves[rng.randi_range(0, _leaves.size() - 1)]
	var start: Vector2i = _center(start_room)
	_put(start, "P")
	_reserve_around(start)
	var exit_room_index: int = _place_exit(start, kind)
	if exit_room_index < 0:
		return {}
	if not _choose_shop_room(start, start_room, _leaves[exit_room_index]):
		return {}
	if kind == Kind.DARK:
		_glitch_an_inner_wall()

	var npc_count: int = mini(4 + tier * 2, 14)
	var party_loot: float = 0.0
	if kind == Kind.OVERLOAD:
		party_loot = _place_party(start_room, tier)
		npc_count -= 6
	_furnish(start_room, kind)
	if _furniture_legend.size() + _wall_decor_legend.size() > CHAR_POOL.length():
		return {}
	_shop_cell = _pick_shop_cell()
	if _shop_cell.x < 0:
		return {}
	_place_monsters(start_room, maxi(npc_count, 2), tier, kind, _leaves[exit_room_index])
	# Fewer trick-or-treaters (= less candy to heal with) the deeper you go.
	_place_kids(start_room, clampi(3 - tier / 2, 1, 3))
	if not _hide_keys(start, start_room, _keys_for(tier), tier):
		return {}
	_place_traps(start, start_room, tier)

	if not _is_valid(kind):
		return {}
	return _settings(tier, kind, party_loot)


# ---------------------------------------------------------------- layout

## Binary space partitioning: cut the rectangle with a wall (with a 2-tile doorway) and recurse.
func _split(rect: Rect2i, depth: int) -> void:
	var can_cut_vertical: bool = rect.size.x >= MIN_ROOM_W * 2 + 1
	var can_cut_horizontal: bool = rect.size.y >= MIN_ROOM_H * 2 + H_WALL
	var too_big: bool = rect.size.x > MAX_ROOM_W or rect.size.y > MAX_ROOM_H
	if (not can_cut_vertical and not can_cut_horizontal) or (not too_big and (depth >= 4 or (depth >= 2 and rng.randf() < 0.3))):
		_leaves.append(rect)
		return
	var vertical: bool = can_cut_vertical and (not can_cut_horizontal or rect.size.x > MAX_ROOM_W or rect.size.x >= rect.size.y * 1.4)
	if vertical:
		var x: int = rng.randi_range(rect.position.x + MIN_ROOM_W, rect.end.x - MIN_ROOM_W - 1)
		for y in range(rect.position.y, rect.end.y):
			_put(Vector2i(x, y), "#")
		var gap: int = rng.randi_range(rect.position.y + 1, rect.end.y - 3)
		_open_doorway([Vector2i(x, gap), Vector2i(x, gap + 1)])
		_split(Rect2i(rect.position.x, rect.position.y, x - rect.position.x, rect.size.y), depth + 1)
		_split(Rect2i(x + 1, rect.position.y, rect.end.x - x - 1, rect.size.y), depth + 1)
	else:
		# Horizontal walls are H_WALL thick (tall back walls for the room below).
		var y: int = rng.randi_range(rect.position.y + MIN_ROOM_H, rect.end.y - MIN_ROOM_H - H_WALL)
		var gap: int = rng.randi_range(rect.position.x + 1, rect.end.x - 3)
		var doorway: Array = []
		for t in H_WALL:
			for x in range(rect.position.x, rect.end.x):
				_put(Vector2i(x, y + t), "#")
			doorway.append_array([Vector2i(gap, y + t), Vector2i(gap + 1, y + t)])
		_open_doorway(doorway)
		_split(Rect2i(rect.position.x, rect.position.y, rect.size.x, y - rect.position.y), depth + 1)
		_split(Rect2i(rect.position.x, y + H_WALL, rect.size.x, rect.end.y - y - H_WALL), depth + 1)


func _open_doorway(cells: Array) -> void:
	for cell in cells:
		_put(cell, ".")
		_doorways.append(cell)


## One room per floor is set aside for the vending machine: no monsters, kids, keys or traps.
## It's the room closest to the start (never the start room or the exit room).
func _choose_shop_room(start: Vector2i, start_room: Rect2i, exit_room: Rect2i) -> bool:
	var dist: Dictionary = _distances_from(start)
	var best_dist: int = 1 << 30
	_shop_room = Rect2i()
	for room in _leaves:
		if room == start_room or room == exit_room:
			continue
		var d: int = dist.get(_center(room), -1)
		if d >= 0 and d < best_dist:
			best_dist = d
			_shop_room = room
	return _shop_room.get_area() > 0


## The vending machine stands in the middle of the shop room (or the nearest free cell).
func _pick_shop_cell() -> Vector2i:
	var middle: Vector2i = _center(_shop_room)
	if _cell_at(middle) == "." and not _reserved.has(middle):
		_reserved[middle] = true
		return middle
	return _random_free_cell(_shop_room)


## Puts the exit door in the outer wall of the room farthest from the start.
## DARK levels wall in the door's alcove, exactly one of the walls fake (drawn a bit buggy).
func _place_exit(start: Vector2i, kind: Kind) -> int:
	var dist: Dictionary = _distances_from(start)
	var best: int = -1
	var best_dist: int = -1
	for i in _leaves.size():
		var room: Rect2i = _leaves[i]
		var touches_border: bool = room.position.x == 1 or room.position.y == H_WALL or room.end.x == _w - 1 or room.end.y == _h - 1
		var d: int = dist.get(_center(room), -1)
		if touches_border and d > best_dist and not room.has_point(start):
			best = i
			best_dist = d
	if best < 0:
		return -1
	var room: Rect2i = _leaves[best]
	# [door cell, direction into the room]
	var options: Array = []
	if room.end.x == _w - 1:
		options.append([Vector2i(_w - 1, rng.randi_range(room.position.y + 1, room.end.y - 2)), Vector2i.LEFT])
	if room.position.x == 1:
		options.append([Vector2i(0, rng.randi_range(room.position.y + 1, room.end.y - 2)), Vector2i.RIGHT])
	if room.position.y == H_WALL:
		options.append([Vector2i(rng.randi_range(room.position.x + 1, room.end.x - 2), H_WALL - 1), Vector2i.DOWN])
	if room.end.y == _h - 1:
		options.append([Vector2i(rng.randi_range(room.position.x + 1, room.end.x - 2), _h - 1), Vector2i.UP])
	var pick: Array = options[rng.randi_range(0, options.size() - 1)]
	var door: Vector2i = pick[0]
	var inward: Vector2i = pick[1]
	_put(door, "D")
	var alcove: Vector2i = door + inward
	_reserve_around(alcove)
	_reserve_around(alcove + inward)
	if kind == Kind.DARK:
		var side := Vector2i(inward.y, inward.x)
		var seal: Array[Vector2i] = [alcove + inward, alcove + side, alcove - side]
		var fake: int = rng.randi_range(0, 2)
		for i in seal.size():
			_put(seal[i], "F" if i == fake else "X")
			_reserve_around(seal[i])
	return best


## DARK levels: one stretch of inner wall becomes "XFX" - a secret shortcut.
func _glitch_an_inner_wall() -> void:
	for attempt in 30:
		var cell := Vector2i(rng.randi_range(2, _w - 3), rng.randi_range(2, _h - 3))
		if _cell_at(cell) != "#" or _reserved.has(cell):
			continue
		# Only 1-thick (vertical) walls: a single fake tile is a real shortcut through them.
		var along: Vector2i = Vector2i.DOWN
		if _cell_at(cell + Vector2i.LEFT) == "#" or _cell_at(cell + Vector2i.RIGHT) == "#":
			continue
		if _cell_at(cell - along) == "#" and _cell_at(cell + along) == "#":
			_put(cell - along, "X")
			_put(cell, "F")
			_put(cell + along, "X")
			return


# ---------------------------------------------------------------- contents

## OVERLOAD levels: a long table in the biggest room with six guests close enough to
## set each other off. Returns their total loot weight (used to tune the CPU multiplier).
func _place_party(start_room: Rect2i, tier: int) -> float:
	var party_room: Rect2i = Rect2i()
	for room in _leaves:
		if room != start_room and room != _shop_room and room.get_area() > party_room.get_area() and room.size.x >= 7 and room.size.y >= 5:
			party_room = room
	if party_room.get_area() == 0:
		return 0.0
	_party_room = party_room
	var c: Vector2i = _center(party_room)
	_put(c, "T")
	for dx in range(-2, 3):
		_reserved[c + Vector2i(dx, 0)] = true
	var seats: Array[Vector2i] = [c + Vector2i(-1, -1), c + Vector2i(1, -1), c + Vector2i(-1, 1),
		c + Vector2i(1, 1), c + Vector2i(-2, 0), c + Vector2i(2, 0)]
	var loot: float = 0.0
	for i in seats.size():
		var key: String = PARTY_GUESTS[rng.randi_range(0, PARTY_GUESTS.length() - 1)]
		if i == 0:
			key = "h"
		elif i == 5 and tier >= 2:
			key = "G"
		if _cell_at(seats[i]) == ".":
			_put(seats[i], key)
			_reserved[seats[i]] = true
			loot += _loot_weight(key)
	return loot


func _furnish(start_room: Rect2i, kind: Kind) -> void:
	var previous: String = ""
	for room in _leaves:
		var theme_id: String
		if room == start_room or room == _shop_room:
			theme_id = "living_room"
		elif room == _party_room:
			theme_id = "dining"
		else:
			var pool: Array[String] = DARK_ROOM_THEMES if kind == Kind.DARK else ROOM_THEMES
			theme_id = pool[rng.randi_range(0, pool.size() - 1)]
			if theme_id == previous:
				theme_id = pool[rng.randi_range(0, pool.size() - 1)]
		previous = theme_id
		var theme: RoomTheme = load(THEME % theme_id)
		_zones.append([room, theme])
		_furnish_room(room, theme)
		_clutter(room, kind)


## Furnishes a room the way a real one looks: a showpiece in the middle of the back wall
## with little helpers beside it, the rest of the back wall lined with furniture, pictures
## on the bare wall, a table with chairs (or just a rug) as the room's centre, plants and
## lamps in the corners and some clutter on the floor. Always at least one hiding spot.
func _furnish_room(room: Rect2i, theme: RoomTheme) -> void:
	_room_has_hide = false
	var feature: Rect2i = _place_feature(room, theme)
	_place_set(room, theme, feature)
	_line_back_wall(room, theme)
	_hang_wall_decor(room, theme)

	# Corners first, then a few small pieces along the side and bottom walls.
	var y: int = room.position.y
	if not theme.accent_pieces.is_empty():
		for corner in [Vector2i(room.position.x, room.end.y - 1), Vector2i(room.end.x - 1, room.end.y - 1)]:
			if _cell_at(corner) == "." and not _reserved.has(corner) and rng.randf() < 0.7:
				_place_piece(_pick(theme.accent_pieces), corner)
				_reserve_around(corner)
	var edge_cells: Array[Vector2i] = []
	for cy in range(y + 2, room.end.y):
		edge_cells.append(Vector2i(room.position.x, cy))
		edge_cells.append(Vector2i(room.end.x - 1, cy))
	for cx in range(room.position.x + 1, room.end.x - 1):
		edge_cells.append(Vector2i(cx, room.end.y - 1))
	_shuffle(edge_cells)
	var side_count: int = clampi((room.size.x + room.size.y) / 5, 1, 4)
	for cell in edge_cells:
		if side_count <= 0 or theme.side_pieces.is_empty():
			break
		if _cell_at(cell) == "." and not _reserved.has(cell):
			_place_piece(_pick(theme.side_pieces), cell)
			_reserve_around(cell)
			side_count -= 1

	# Walk-over clutter: cushions, dropped books.
	if not theme.floor_clutter.is_empty():
		for i in rng.randi_range(1, 2):
			var piece: FurnitureData = _pick(theme.floor_clutter)
			var cell: Vector2i = _random_free_cell(room)
			if cell.x >= 0 and _area_free(Rect2i(cell, piece.footprint), room):
				_place_piece(piece, cell)


## The room's showpiece (fireplace, bed, stove), as close to the middle of the back wall
## as it fits, with the same little piece on both sides of it. Returns where it went.
func _place_feature(room: Rect2i, theme: RoomTheme) -> Rect2i:
	if theme.feature_pieces.is_empty():
		return Rect2i()
	var piece: FurnitureData = _pick(theme.feature_pieces)
	var y: int = room.position.y
	var middle: int = room.position.x + (room.size.x - piece.footprint.x) / 2
	for offset in [0, -1, 1, -2, 2, -3, 3]:
		var area := Rect2i(Vector2i(middle + offset, y), piece.footprint)
		if not (_area_free(area, room) and _wall_above(area.position.x, y, area.size.x)):
			continue
		_place_piece(piece, area.position)
		_reserve_rect(Rect2i(area.position.x, area.end.y, area.size.x, 1))  # walk space in front
		_room_has_hide = piece.hideable
		if not theme.feature_flank.is_empty():
			var flank: FurnitureData = _pick(theme.feature_flank)
			for fx in [area.position.x - 1, area.end.x]:
				var cell := Vector2i(fx, y)
				if _area_free(Rect2i(cell, Vector2i.ONE), room) and _wall_above(fx, y, 1):
					_place_piece(flank, cell)
					_reserve_rect(Rect2i(fx, y + 1, 1, 1))
		return area
	return Rect2i()


## A table with chairs facing it from every side the theme has a chair for, on a rug. It
## goes in front of the showpiece or in the middle of the room, with a free ring around
## it so nobody gets stuck. Rooms too small for chairs get the table alone, or just a rug.
func _place_set(room: Rect2i, theme: RoomTheme, feature: Rect2i) -> void:
	if room == _party_room:
		return
	var table: FurnitureData = null if theme.center_pieces.is_empty() else _pick(theme.center_pieces)
	var back_depth: int = maxi(feature.size.y, 1)
	var in_front: bool = theme.set_in_front_of_feature and feature.size.x > 0
	# Try the full set first, then smaller ones: 0 all chairs, 1 side chairs, 2 table, 3 rug.
	for variant in 4:
		var core: FurnitureData = table if variant < 3 else null
		var core_size: Vector2i = core.footprint if core != null else Vector2i(2, 1)
		var w: int = 1 if variant <= 1 and core != null and theme.seat_west != null else 0
		var e: int = 1 if variant <= 1 and core != null and theme.seat_east != null else 0
		var n: int = 1 if variant == 0 and core != null and theme.seat_north != null else 0
		var s: int = 1 if variant == 0 and core != null and theme.seat_south != null else 0
		var size: Vector2i = core_size + Vector2i(w + e, n + s)
		var spot: Vector2i = _find_set_spot(room, size, back_depth, feature if in_front else Rect2i())
		if spot.x < 0:
			continue
		var bounds := Rect2i(spot, size)
		var table_cell: Vector2i = spot + Vector2i(w, n)
		if core != null:
			_place_piece(core, table_cell)
			for dy in core_size.y:
				_maybe_seat(theme.seat_west, table_cell + Vector2i(-1, dy), w)
				_maybe_seat(theme.seat_east, table_cell + Vector2i(core_size.x, dy), e)
			# A desk (no side chairs) gets a single chair; a table gets one per tile.
			var desk: bool = theme.seat_west == null and theme.seat_east == null
			var desk_chair: int = rng.randi_range(0, core_size.x - 1)
			for dx in core_size.x:
				if desk and dx != desk_chair:
					continue
				_maybe_seat(theme.seat_north, table_cell + Vector2i(dx, -1), n)
				_maybe_seat(theme.seat_south, table_cell + Vector2i(dx, core_size.y), s)
		_place_rug_under(room, theme, bounds)
		_reserve_rect(bounds.grow(1))
		return


func _maybe_seat(seat: FurnitureData, cell: Vector2i, enabled: int) -> void:
	if enabled > 0 and seat != null and rng.randf() < 0.85:
		_place_piece(seat, cell)


## Top-left cell for a set of `size` tiles with a free ring around it, or (-1, -1).
## With a `feature` it is tried centred right in front of it first (one walk row in between).
func _find_set_spot(room: Rect2i, size: Vector2i, back_depth: int, feature: Rect2i) -> Vector2i:
	var top: int = room.position.y + back_depth + 1   # back wall row(s) + a walk row
	var candidates: Array[Vector2i] = []
	if feature.size.x > 0:
		var fx: int = feature.position.x + (feature.size.x - size.x) / 2
		for offset in [0, -1, 1, -2, 2]:
			candidates.append(Vector2i(fx + offset, feature.end.y + 1))
	# The middle of the floor in front of the back wall (also the fallback).
	var x: int = room.position.x + (room.size.x - size.x) / 2
	var y: int = top + maxi(0, (room.end.y - top - size.y) / 2)
	for dy in [0, 1, -1]:
		for dx in [0, -1, 1, -2, 2]:
			candidates.append(Vector2i(x + dx, y + dy))
	for spot in candidates:
		var bounds := Rect2i(spot, size)
		if spot.y >= top and room.encloses(bounds.grow(1)) and _area_free(bounds, room) and _ring_clear(bounds):
			return spot
	return Vector2i(-1, -1)


## True if nothing blocks the tiles all around `rect`.
func _ring_clear(rect: Rect2i) -> bool:
	var ring: Rect2i = rect.grow(1)
	for cy in range(ring.position.y, ring.end.y):
		for cx in range(ring.position.x, ring.end.x):
			var cell := Vector2i(cx, cy)
			if not rect.has_point(cell) and not _is_walkable(_cell_at(cell), false):
				return false
	return true


## The biggest of the theme's rugs that fits under the set (centred on it).
func _place_rug_under(room: Rect2i, theme: RoomTheme, bounds: Rect2i) -> void:
	var rugs: Array[FurnitureData] = theme.rugs.duplicate()
	rugs.sort_custom(func(a: FurnitureData, b: FurnitureData) -> bool:
		return a.footprint.x * a.footprint.y > b.footprint.x * b.footprint.y)
	for rug in rugs:
		var area := Rect2i(bounds.position + (bounds.size - rug.footprint) / 2, rug.footprint)
		if room.encloses(area) and bounds.grow(1).encloses(area) and _cell_at(area.position) == ".":
			_put(area.position, _letter_for(rug, false))
			_reserve_rect(area)
			return


## Lines the rest of the back wall: big pieces (a hiding spot first), now and then a lamp
## or plant between them, and sometimes a gap for a window.
func _line_back_wall(room: Rect2i, theme: RoomTheme) -> void:
	if theme.north_pieces.is_empty():
		return
	var y: int = room.position.y
	var x: int = room.position.x
	var last_was_big: bool = false
	while x < room.end.x:
		if not (_area_free(Rect2i(x, y, 1, 1), room) and _wall_above(x, y, 1)):
			x += 1
			last_was_big = false
			continue
		if _room_has_hide and rng.randf() < 0.15:
			x += 1  # a bare bit of wall for a window or painting
			last_was_big = false
			continue
		if last_was_big and not theme.accent_pieces.is_empty() and rng.randf() < 0.4:
			_place_piece(_pick(theme.accent_pieces), Vector2i(x, y))
			_reserve_rect(Rect2i(x, y + 1, 1, 1))
			x += 1
			last_was_big = false
			continue
		var piece: FurnitureData = _fit_north_piece(room, theme, Vector2i(x, y))
		if piece == null:
			if not theme.accent_pieces.is_empty() and rng.randf() < 0.5:
				_place_piece(_pick(theme.accent_pieces), Vector2i(x, y))
				_reserve_rect(Rect2i(x, y + 1, 1, 1))
			x += 1
			last_was_big = false
			continue
		_place_piece(piece, Vector2i(x, y))
		_reserve_rect(Rect2i(x, y + piece.footprint.y, piece.footprint.x, 1))  # walk space in front
		_room_has_hide = _room_has_hide or piece.hideable
		x += piece.footprint.x
		last_was_big = true


## A back-wall piece that fits at `cell` (a hideable one while the room has no hiding spot).
func _fit_north_piece(room: Rect2i, theme: RoomTheme, cell: Vector2i) -> FurnitureData:
	var options: Array[FurnitureData] = theme.north_pieces.duplicate()
	if not _room_has_hide:
		var hideable: Array[FurnitureData] = options.filter(func(p: FurnitureData) -> bool: return p.hideable)
		if not hideable.is_empty():
			options = hideable
	for i in range(options.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: FurnitureData = options[i]
		options[i] = options[j]
		options[j] = tmp
	for piece in options:
		if _area_free(Rect2i(cell, piece.footprint), room) and _wall_above(cell.x, cell.y, piece.footprint.x):
			return piece
	return null


## Windows and paintings on the back wall: on bare wall, or above furniture low enough.
## A piece wider than a tile also needs wall (and low enough furniture) on both sides, so it
## never hangs over a corner or a doorway; wide pieces get extra space between them.
func _hang_wall_decor(room: Rect2i, theme: RoomTheme) -> void:
	if theme.wall_decor.is_empty():
		return
	var y: int = room.position.y
	var last_decor: int = -99
	var last_wide: bool = false
	for wx in range(room.position.x, room.end.x):
		if _cell_at(Vector2i(wx, y - 1)) != "#" or rng.randf() > 0.75:
			continue
		var options: Array[FurnitureData] = theme.wall_decor.filter(
			func(d: FurnitureData) -> bool: return _decor_fits(d, wx, room))
		if options.is_empty():
			continue
		var decor: FurnitureData = _pick(options)
		var wide: bool = _is_wide(decor)
		if wx - last_decor < (3 if wide or last_wide else 2):
			continue
		_put(Vector2i(wx, y - 1), _letter_for(decor, true))
		last_decor = wx
		last_wide = wide


func _is_wide(decor: FurnitureData) -> bool:
	return decor.texture.get_width() > 34


## True if `decor` can hang above (wx, top row of `room`) without poking into anything.
func _decor_fits(decor: FurnitureData, wx: int, room: Rect2i) -> bool:
	var y: int = room.position.y
	var span: Array[int] = [wx]
	if _is_wide(decor):
		span = [wx - 1, wx, wx + 1]
	for x in span:
		if x < room.position.x or x >= room.end.x or _cell_at(Vector2i(x, y - 1)) != "#":
			return false
		var below: FurnitureData = _piece_at.get(Vector2i(x, y))
		if below == null:
			if _cell_at(Vector2i(x, y)) != ".":
				return false
		elif below.kind != FurnitureData.Kind.NORTH or decor.texture.get_height() * 0.5 + below.texture.get_height() > 56.0:
			return false
	return true


func _pick(list: Array[FurnitureData]) -> FurnitureData:
	return list[rng.randi_range(0, list.size() - 1)]


## Writes a piece into the grid: its letter on the top-left tile, "+" on the rest of the footprint.
func _place_piece(piece: FurnitureData, cell: Vector2i) -> void:
	var letter: String = _letter_for(piece, false)
	for dy in piece.footprint.y:
		for dx in piece.footprint.x:
			_put(cell + Vector2i(dx, dy), letter if dx == 0 and dy == 0 else "+")
			_piece_at[cell + Vector2i(dx, dy)] = piece
	_piece_origins.append([cell, piece])
	_reserve_rect(Rect2i(cell, piece.footprint))


## Each distinct piece used on this floor gets its own layout letter.
func _letter_for(piece: FurnitureData, on_wall: bool) -> String:
	if _piece_chars.has(piece):
		return _piece_chars[piece]
	var index: int = _piece_chars.size()
	var letter: String = CHAR_POOL[mini(index, CHAR_POOL.length() - 1)]
	_piece_chars[piece] = letter
	if on_wall:
		_wall_decor_legend[letter] = piece
	else:
		_furniture_legend[letter] = piece
	if piece.kind == FurnitureData.Kind.RUG:
		_walk_over[letter] = true
	return letter


func _area_free(area: Rect2i, room: Rect2i) -> bool:
	if not room.encloses(area):
		return false
	for cy in range(area.position.y, area.end.y):
		for cx in range(area.position.x, area.end.x):
			var cell := Vector2i(cx, cy)
			if _cell_at(cell) != "." or _reserved.has(cell):
				return false
	return true


## True if the whole width is backed by wall (not a doorway).
func _wall_above(x: int, y: int, width: int) -> bool:
	for dx in width:
		if _cell_at(Vector2i(x + dx, y - 1)) != "#":
			return false
	return true


func _reserve_rect(area: Rect2i) -> void:
	for cy in range(area.position.y, area.end.y):
		for cx in range(area.position.x, area.end.x):
			_reserved[Vector2i(cx, cy)] = true


func _shuffle(cells: Array[Vector2i]) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = cells[i]
		cells[i] = cells[j]
		cells[j] = tmp


func _clutter(room: Rect2i, kind: Kind) -> void:
	for corner in [Vector2i(room.position.x, room.end.y - 1), Vector2i(room.end.x - 1, room.end.y - 1)]:
		if _cell_at(corner) == "." and not _reserved.has(corner) and rng.randf() < 0.5:
			_put(corner, "o")
	for i in rng.randi_range(1, 3):
		var cell: Vector2i = _random_free_cell(room)
		if cell.x >= 0:
			_put(cell, "c" if kind == Kind.DARK or rng.randf() < 0.3 else ("n" if rng.randf() < 0.5 else "u"))


func _place_monsters(start_room: Rect2i, count: int, tier: int, kind: Kind, exit_room: Rect2i) -> void:
	var rooms: Array[Rect2i] = []
	for room in _leaves:
		if room != start_room and room != _shop_room:
			rooms.append(room)
	if rooms.is_empty():
		return
	# A jack-o'-lantern guards the exit on OVERLOAD floors: sprint past it when the door vanishes.
	if kind == Kind.OVERLOAD:
		var guard: Vector2i = _random_spawn_cell(exit_room)
		if guard.x >= 0:
			_put(guard, "j")
			count -= 1
	for i in count:
		# The next room in turn; if it's full, the one after it.
		var cell := Vector2i(-1, -1)
		for k in rooms.size():
			cell = _random_spawn_cell(rooms[(i + k) % rooms.size()])
			if cell.x >= 0:
				break
		if cell.x < 0:
			continue
		# Tougher monster types join the deeper you go.
		var pool: String = WANDERERS + ("j" if tier >= 1 else "") + ("G" if tier >= 3 else "")
		_put(cell, pool[rng.randi_range(0, pool.length() - 1)])


## A group of trick-or-treaters, all in one room (not the start room) so they stick together.
func _place_kids(start_room: Rect2i, count: int) -> void:
	var rooms: Array[Rect2i] = []
	for room in _leaves:
		if room != start_room and room != _shop_room:
			rooms.append(room)
	if rooms.is_empty():
		return
	var room: Rect2i = rooms[rng.randi_range(0, rooms.size() - 1)]
	for i in count:
		var cell: Vector2i = _random_spawn_cell(room)
		if cell.x >= 0:
			_put(cell, "&")


# ---------------------------------------------------------------- keys & traps

func _keys_for(tier: int) -> int:
	return clampi(1 + tier / 2, 1, 3)


## Puts the exit keys into searchable furniture (drawers, dressers...), each in a different
## room, preferring rooms far from the start. Fills in what every other drawer holds.
## False if the floor doesn't have enough drawers (the floor is then re-rolled).
func _hide_keys(start: Vector2i, start_room: Rect2i, keys: int, tier: int) -> bool:
	var dist: Dictionary = _distances_from(start)
	var drawers: Array = []   # [cell, room index, distance]
	for entry in _piece_origins:
		var piece: FurnitureData = entry[1]
		if not piece.searchable or piece.hideable:
			continue
		var cell: Vector2i = entry[0]
		var room_index: int = -1
		for i in _leaves.size():
			if _leaves[i].has_point(cell):
				room_index = i
		var below: Vector2i = cell + Vector2i(0, piece.footprint.y)  # where you stand to search
		if room_index >= 0 and _leaves[room_index] == _shop_room:
			# The shop room is calm: no keys, no scares - at most a little candy.
			_search_contents[cell] = Searchable.Contents.CANDY if rng.randf() < 0.4 else Searchable.Contents.NOTHING
			continue
		drawers.append([cell, room_index, dist.get(below, dist.get(cell, 0))])
	# Farthest first, at most one key per room (start room last resort).
	drawers.sort_custom(func(a: Array, b: Array) -> bool: return a[2] > b[2])
	var key_cells: Array[Vector2i] = []
	var used_rooms: Dictionary = {}
	for pass_index in 2:
		for d in drawers:
			if key_cells.size() >= keys:
				break
			var in_start: bool = d[1] >= 0 and _leaves[d[1]] == start_room
			if key_cells.has(d[0]) or (pass_index == 0 and (used_rooms.has(d[1]) or in_start)):
				continue
			# Not always THE farthest drawer: skip some, so keys don't always sit in the same spots.
			if pass_index == 0 and rng.randf() < 0.35:
				continue
			key_cells.append(d[0])
			used_rooms[d[1]] = true
	if key_cells.size() < keys:
		return false
	for d in drawers:
		var contents: int = Searchable.Contents.NOTHING
		if key_cells.has(d[0]):
			contents = Searchable.Contents.KEY
		else:
			var roll: float = rng.randf()
			if roll < 0.25:
				contents = Searchable.Contents.CANDY
			elif roll < 0.25 + minf(0.1 + 0.04 * tier, 0.3):
				contents = Searchable.Contents.SCARE
		_search_contents[d[0]] = contents
	return true


## Creaky boards and jumpscare spots go in doorways (you have to pass them); bear traps on
## the walkways in front of furniture. Never in the start room or right at the exit.
func _place_traps(start: Vector2i, start_room: Rect2i, tier: int) -> void:
	var door: Vector2i = _find("D")
	var used: Dictionary = {}
	var gates: Array[Vector2i] = []
	for cell in _doorways:
		if _cell_at(cell) == "." and not start_room.grow(1).has_point(cell) and not _shop_room.grow(2).has_point(cell) and _manhattan(cell, door) > 3:
			gates.append(cell)
	_shuffle(gates)
	var scares: int = clampi(1 + tier / 2, 1, 3)
	var creaks: int = clampi(2 + tier, 2, 8)
	for cell in gates:
		if _touches(used, cell):
			continue  # one trap per doorway
		if scares > 0:
			_traps.append([cell, "jumpscare"])
			scares -= 1
		elif creaks > 0:
			_traps.append([cell, "creak"])
			creaks -= 1
		else:
			break
		used[cell] = true

	var floor_cells: Array[Vector2i] = []
	for room in _leaves:
		if room == start_room:
			continue
		for cy in range(room.position.y, room.end.y):
			for cx in range(room.position.x, room.end.x):
				var c := Vector2i(cx, cy)
				if _cell_at(c) == "." and not _near_doorway(c) and _manhattan(c, door) > 3 and _manhattan(c, start) > 4:
					floor_cells.append(c)
	_shuffle(floor_cells)
	var bears: int = clampi(tier, 1, 6)
	for c in floor_cells:
		if bears <= 0 and creaks <= 0:
			break
		if _touches(used, c):
			continue
		if bears > 0:
			_traps.append([c, "bear"])
			bears -= 1
		else:
			_traps.append([c, "creak"])  # leftover boards go on the floor
			creaks -= 1
		used[c] = true


## True if `cell` or any of its 8 neighbours is in `used`.
func _touches(used: Dictionary, cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if used.has(cell + Vector2i(dx, dy)):
				return true
	return false


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


# ---------------------------------------------------------------- validation

## Everyone-walkable check: the exit is reachable, nothing is walled in, and on DARK
## floors the exit really needs the fake wall.
func _is_valid(kind: Kind) -> bool:
	var start: Vector2i = _find("P")
	var door: Vector2i = _find("D")
	var reach: Dictionary = _flood(start, true)
	if not reach.has(door):
		return false
	for y in _h:
		for x in _w:
			var cell := Vector2i(x, y)
			if _is_walkable(_cell_at(cell), true) and not reach.has(cell):
				return false
	if kind == Kind.DARK and _flood(start, false).has(door):
		return false
	return true


func _is_walkable(ch: String, fake_walls_open: bool) -> bool:
	if ch == "F":
		return fake_walls_open
	return ch in [".", "P", "D", "&"] or NPC_PATHS.has(ch) or FLOOR_ITEMS.has(ch) or LIGHT_ITEMS.has(ch) or _walk_over.has(ch)


func _flood(from: Vector2i, fake_walls_open: bool) -> Dictionary:
	var seen: Dictionary = {from: true}
	var todo: Array[Vector2i] = [from]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if n.x >= 0 and n.y >= 0 and n.x < _w and n.y < _h and not seen.has(n) and _is_walkable(_cell_at(n), fake_walls_open):
				seen[n] = true
				todo.append(n)
	return seen


## Walking distance (in tiles) from a cell to every reachable floor cell.
func _distances_from(from: Vector2i) -> Dictionary:
	var dist: Dictionary = {from: 0}
	var queue: Array[Vector2i] = [from]
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if not dist.has(n) and _cell_at(n) != "#" and n.x > 0 and n.y > 0 and n.x < _w - 1 and n.y < _h - 1:
				dist[n] = dist[c] + 1
				queue.append(n)
	return dist


# ---------------------------------------------------------------- output

func _settings(tier: int, kind: Kind, party_loot: float) -> Dictionary:
	var rows: PackedStringArray = []
	for row in _grid:
		rows.append("".join(row))
	var lines: Array[String] = []
	var title: String
	var settings: Dictionary = {
		"layout": "\n".join(rows),
		"npc_legend": _load_all(NPC_PATHS, ""),
		"hide_legend": {},
		"decor_legend": _load_all(DECOR_ITEMS, OBJ),
		"furniture_legend": _furniture_legend.duplicate(),
		"wall_decor_legend": _wall_decor_legend.duplicate(),
		"zones": _zones.duplicate(),
		"default_theme": _zones[0][1] if not _zones.is_empty() else null,
		"floor_decor_legend": _load_all(FLOOR_ITEMS, OBJ),
		"light_legend": _load_all(LIGHT_ITEMS, OBJ),
		"npc_windup_scale": maxf(0.55, 1.0 - 0.08 * tier),
		"npc_damage_scale": minf(1.0 + 0.12 * tier, 1.8),
		"npc_speed_scale": minf(1.0 + 0.1 * tier, 1.6),
		"keys_needed": _keys_for(tier),
		"search_contents": _search_contents.duplicate(),
		"traps": _traps.duplicate(),
		"stalker_speed": minf(90.0 + 6.0 * tier, 130.0),
		"npc_sight_scale": minf(1.0 + 0.06 * tier, 1.4),
		"sanity_regen_scale": maxf(0.35, 1.0 - 0.1 * tier),
		"shop_cell": _shop_cell,
		"shop_room": _shop_room,
	}
	if kind == Kind.DARK:
		title = DARK_TITLES[rng.randi_range(0, DARK_TITLES.size() - 1)]
		lines.append("%s. Lighting budget: zero." % title)
		lines.append("The exit is walled in. One of those walls is a bit buggy. Bugs are features. Walk into it.")
		lines.append(_keys_line(tier))
		settings.merge({
			"objective": "Find %s in the drawers (hold E). The exit is walled in - walk through the wall that glitches." % _keys_text(tier),
			"exit_requires_cpu_overload": false,
			"flashlight_works": false,
			"ambient_color": Color(0.06, 0.05, 0.1),
			"npc_load_radius": maxf(60.0, 90.0 - 5.0 * tier),  # deeper = monsters pop in later
			"npc_wander_scale": 1.0,
			"npcs_hide": true,
			"npcs_chase": true,
			"cpu_load_multiplier": 1.0,
		})
	else:
		title = PARTY_TITLES[rng.randi_range(0, PARTY_TITLES.size() - 1)]
		lines.append("%s. Someone invited far too many guests." % title)
		lines.append("Scares make the house glitch. Crash it to 100% and the exit door forgets to render.")
		lines.append(_keys_line(tier))
		settings.merge({
			"objective": "Find %s in the drawers (hold E), then crash the house (100%% GLITCH) so the exit stops rendering." % _keys_text(tier),
			"exit_requires_cpu_overload": true,
			"door_open_time": 6.0,
			"flashlight_works": true,
			"ambient_color": Color(0.05, 0.045, 0.08),
			"npc_load_radius": 0.0,
			"npc_wander_scale": 0.25,
			"npcs_hide": false,
			"npcs_chase": false,
			# One good chain reaction at the table should crash the house (with headroom for decay).
			"cpu_load_multiplier": clampf(150.0 / maxf(party_loot, 1.0), 1.0, 3.0),
		})
	if tier > 0:
		lines.append("Patch notes v1.%d: monsters %d%% faster, see %d%% further, scare %d%% harder. Sanity regen nerfed." % [
			tier, roundi((settings["npc_speed_scale"] - 1.0) * 100.0), roundi((settings["npc_sight_scale"] - 1.0) * 100.0),
			roundi((settings["npc_damage_scale"] - 1.0) * 100.0)])
	settings["room_title"] = title
	settings["intro_lines"] = lines
	return settings


func _keys_text(tier: int) -> String:
	var keys: int = _keys_for(tier)
	return "the key" if keys == 1 else "%d keys" % keys


func _keys_line(tier: int) -> String:
	return "The exit is locked. %s hidden in drawers and cabinets. Mind the floor - some of it bites." % (
		"The key is" if _keys_for(tier) == 1 else "%d keys are" % _keys_for(tier))


func _load_all(items: Dictionary, path_format: String) -> Dictionary:
	var out: Dictionary = {}
	for key in items:
		out[key] = load(items[key] if path_format.is_empty() else path_format % items[key])
	return out


# ---------------------------------------------------------------- helpers

func _loot_weight(npc_key: String) -> float:
	var data: NpcData = load(NPC_PATHS[npc_key])
	var total: float = 0.0
	for prop in data.loot:
		total += prop.load_weight
	return total


func _random_free_cell(room: Rect2i) -> Vector2i:
	var free: Array[Vector2i] = []
	for cy in range(room.position.y, room.end.y):
		for cx in range(room.position.x, room.end.x):
			var cell := Vector2i(cx, cy)
			if _cell_at(cell) == "." and not _reserved.has(cell):
				free.append(cell)
	if free.is_empty():
		return Vector2i(-1, -1)
	var pick: Vector2i = free[rng.randi_range(0, free.size() - 1)]
	_reserved[pick] = true
	return pick


## A cell for a monster or kid. Reserved cells only keep FURNITURE out of walkways, so when a
## room is full of furniture they may stand there - just not in a doorway or by the exit.
func _random_spawn_cell(room: Rect2i) -> Vector2i:
	var cell: Vector2i = _random_free_cell(room)
	if cell.x >= 0:
		return cell
	var door: Vector2i = _find("D")
	var options: Array[Vector2i] = []
	for cy in range(room.position.y, room.end.y):
		for cx in range(room.position.x, room.end.x):
			var c := Vector2i(cx, cy)
			if _cell_at(c) == "." and absi(c.x - door.x) + absi(c.y - door.y) > 3 and not _near_doorway(c):
				options.append(c)
	if options.is_empty():
		return Vector2i(-1, -1)
	return options[rng.randi_range(0, options.size() - 1)]


func _near_doorway(cell: Vector2i) -> bool:
	for d in _doorways:
		if absi(d.x - cell.x) <= 1 and absi(d.y - cell.y) <= 1:
			return true
	return false


func _reserve_around(cell: Vector2i) -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			_reserved[cell + Vector2i(dx, dy)] = true


func _center(room: Rect2i) -> Vector2i:
	return room.position + room.size / 2


func _find(ch: String) -> Vector2i:
	for y in _h:
		var x: int = _grid[y].find(ch)
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


func _cell_at(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= _w or cell.y >= _h:
		return "#"
	return _grid[cell.y][cell.x]


func _put(cell: Vector2i, ch: String) -> void:
	_grid[cell.y][cell.x] = ch

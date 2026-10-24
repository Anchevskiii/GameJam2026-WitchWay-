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
##   3. Furniture hugs the walls (every room gets at least one hiding spot), clutter goes
##      on the floor, monsters go everywhere except the start room.
##   4. Two kinds of "bug" level, alternating:
##        DARK      lights off, exit sealed behind magenta walls - one of them is fake.
##        OVERLOAD  a dinner party: crash the CPU to 100% so the exit door stops rendering.
##   5. Everything is flood-fill checked; a bad roll is simply re-rolled with the next seed.

enum Kind { DARK, OVERLOAD }

const MIN_ROOM_W: int = 6
const MIN_ROOM_H: int = 5
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
const HIDE_ITEMS: Dictionary = {"W": "cupboard", "K": "bookshelf", "C": "couch"}
const DECOR_ITEMS: Dictionary = {"t": "table", "A": "armchair", "L": "lamp", "Q": "plant", "Z": "crate", "O": "clock", "V": "tv", "T": "dining_table"}
const FLOOR_ITEMS: Dictionary = {"r": "rug", "o": "cobweb", "n": "bones", "u": "pumpkin"}
const LIGHT_ITEMS: Dictionary = {"c": "candles"}

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
	_h = 18 + mini(tier, 5) * 2
	_grid.clear()
	_leaves.clear()
	_doorways.clear()
	_reserved.clear()
	for y in _h:
		var row: Array = []
		for x in _w:
			row.append("#" if x == 0 or y == 0 or x == _w - 1 or y == _h - 1 else ".")
		_grid.append(row)

	_split(Rect2i(1, 1, _w - 2, _h - 2), 0)
	for cell in _doorways:
		_reserve_around(cell)

	var start_room: Rect2i = _leaves[rng.randi_range(0, _leaves.size() - 1)]
	var start: Vector2i = _center(start_room)
	_put(start, "P")
	_reserve_around(start)
	var exit_room_index: int = _place_exit(start, kind)
	if exit_room_index < 0:
		return {}
	if kind == Kind.DARK:
		_glitch_an_inner_wall()

	var npc_count: int = mini(4 + tier * 2, 14)
	var party_loot: float = 0.0
	if kind == Kind.OVERLOAD:
		party_loot = _place_party(start_room, tier)
		npc_count -= 6
	_furnish(start_room, kind)
	_place_monsters(start_room, maxi(npc_count, 2), tier, kind, _leaves[exit_room_index])
	_place_kids(start_room, 2 + mini(tier, 3))
	_place_hazards_and_lights(start_room, kind, tier)

	if not _is_valid(kind):
		return {}
	return _settings(tier, kind, party_loot)


# ---------------------------------------------------------------- layout

## Binary space partitioning: cut the rectangle with a wall (with a 2-tile doorway) and recurse.
func _split(rect: Rect2i, depth: int) -> void:
	var can_cut_vertical: bool = rect.size.x >= MIN_ROOM_W * 2 + 1
	var can_cut_horizontal: bool = rect.size.y >= MIN_ROOM_H * 2 + 1
	if (not can_cut_vertical and not can_cut_horizontal) or depth >= 4 or (depth >= 2 and rng.randf() < 0.3):
		_leaves.append(rect)
		return
	var vertical: bool = can_cut_vertical and (not can_cut_horizontal or rect.size.x >= rect.size.y)
	if vertical:
		var x: int = rng.randi_range(rect.position.x + MIN_ROOM_W, rect.end.x - MIN_ROOM_W - 1)
		for y in range(rect.position.y, rect.end.y):
			_put(Vector2i(x, y), "#")
		var gap: int = rng.randi_range(rect.position.y + 1, rect.end.y - 3)
		_open_doorway([Vector2i(x, gap), Vector2i(x, gap + 1)])
		_split(Rect2i(rect.position.x, rect.position.y, x - rect.position.x, rect.size.y), depth + 1)
		_split(Rect2i(x + 1, rect.position.y, rect.end.x - x - 1, rect.size.y), depth + 1)
	else:
		var y: int = rng.randi_range(rect.position.y + MIN_ROOM_H, rect.end.y - MIN_ROOM_H - 1)
		for x in range(rect.position.x, rect.end.x):
			_put(Vector2i(x, y), "#")
		var gap: int = rng.randi_range(rect.position.x + 1, rect.end.x - 3)
		_open_doorway([Vector2i(gap, y), Vector2i(gap + 1, y)])
		_split(Rect2i(rect.position.x, rect.position.y, rect.size.x, y - rect.position.y), depth + 1)
		_split(Rect2i(rect.position.x, y + 1, rect.size.x, rect.end.y - y - 1), depth + 1)


func _open_doorway(cells: Array) -> void:
	for cell in cells:
		_put(cell, ".")
		_doorways.append(cell)


## Puts the exit door in the outer wall of the room farthest from the start.
## DARK levels seal the door's alcove with magenta walls, exactly one of them fake.
func _place_exit(start: Vector2i, kind: Kind) -> int:
	var dist: Dictionary = _distances_from(start)
	var best: int = -1
	var best_dist: int = -1
	for i in _leaves.size():
		var room: Rect2i = _leaves[i]
		var touches_border: bool = room.position.x == 1 or room.position.y == 1 or room.end.x == _w - 1 or room.end.y == _h - 1
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
	if room.position.y == 1:
		options.append([Vector2i(rng.randi_range(room.position.x + 1, room.end.x - 2), 0), Vector2i.DOWN])
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
		var along: Vector2i = Vector2i.DOWN if _cell_at(cell + Vector2i.UP) == "#" and _cell_at(cell + Vector2i.DOWN) == "#" else Vector2i.RIGHT
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
		if room != start_room and room.get_area() > party_room.get_area() and room.size.x >= 7 and room.size.y >= 5:
			party_room = room
	if party_room.get_area() == 0:
		return 0.0
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
	for room in _leaves:
		var spots: Array[Vector2i] = _wall_hugging_cells(room)
		var count: int = clampi(room.get_area() / 12, 2, 6)
		var placed: int = 0
		for cell in spots:
			if placed >= count:
				break
			if _reserved.has(cell) or _cell_at(cell) != ".":
				continue
			# The first item in every room is a hiding spot.
			var key: String = _pick_key(HIDE_ITEMS) if placed == 0 or rng.randf() < 0.35 else _pick_key(DECOR_ITEMS, ["T"])
			_put(cell, key)
			_reserve_around(cell)
			placed += 1
		_clutter(room, kind)


func _clutter(room: Rect2i, kind: Kind) -> void:
	for corner in [room.position, Vector2i(room.end.x - 1, room.position.y)]:
		if _cell_at(corner) == "." and not _reserved.has(corner) and rng.randf() < 0.6:
			_put(corner, "o")
	if room.get_area() >= 30 and rng.randf() < 0.4 and _cell_at(_center(room)) == ".":
		_put(_center(room), "r")
	for i in rng.randi_range(1, 3):
		var cell: Vector2i = _random_free_cell(room)
		if cell.x >= 0:
			_put(cell, "c" if kind == Kind.DARK or rng.randf() < 0.3 else ("n" if rng.randf() < 0.5 else "u"))


func _place_monsters(start_room: Rect2i, count: int, tier: int, kind: Kind, exit_room: Rect2i) -> void:
	var rooms: Array[Rect2i] = []
	for room in _leaves:
		if room != start_room:
			rooms.append(room)
	if rooms.is_empty():
		return
	# A jack-o'-lantern guards the exit on OVERLOAD floors: sprint past it when the door vanishes.
	if kind == Kind.OVERLOAD:
		var guard: Vector2i = _random_free_cell(exit_room)
		if guard.x >= 0:
			_put(guard, "j")
			count -= 1
	for i in count:
		var cell: Vector2i = _random_free_cell(rooms[i % rooms.size()])
		if cell.x < 0:
			continue
		var pool: String = WANDERERS + ("j" if tier >= 1 else "")
		_put(cell, pool[rng.randi_range(0, pool.length() - 1)])


## A group of trick-or-treaters, all in one room (not the start room) so they stick together.
func _place_kids(start_room: Rect2i, count: int) -> void:
	var rooms: Array[Rect2i] = []
	for room in _leaves:
		if room != start_room:
			rooms.append(room)
	if rooms.is_empty():
		return
	var room: Rect2i = rooms[rng.randi_range(0, rooms.size() - 1)]
	for i in count:
		var cell: Vector2i = _random_free_cell(room)
		if cell.x >= 0:
			_put(cell, "&")


func _place_hazards_and_lights(start_room: Rect2i, kind: Kind, tier: int) -> void:
	# Place wall lamps in some rooms, leaving others pitch black or dimly lit
	for room in _leaves:
		var lamp_chance: float = 0.15 if kind == Kind.DARK else 0.45
		if room == start_room or rng.randf() < lamp_chance:
			var spots: Array[Vector2i] = _wall_hugging_cells(room)
			for cell in spots:
				if _cell_at(cell) == "." and not _reserved.has(cell):
					_reserved[cell] = true
					_put(cell, "l")
					break

	# Air vents in narrow doorways/corridors
	for doorway in _doorways:
		if _cell_at(doorway) == "." and not _reserved.has(doorway) and rng.randf() < 0.2:
			_put(doorway, "v")

	# Disguise Mask pickup spawns from Floor 3+ (tier >= 1)
	if tier >= 1:
		for room in _leaves:
			if room != start_room:
				var mask_cell: Vector2i = _random_free_cell(room)
				if mask_cell.x >= 0:
					_put(mask_cell, "M")
					break


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
	return ch in [".", "P", "D", "&", "l", "v", "M"] or NPC_PATHS.has(ch) or FLOOR_ITEMS.has(ch) or LIGHT_ITEMS.has(ch)


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
		"hide_legend": _load_all(HIDE_ITEMS, OBJ),
		"decor_legend": _load_all(DECOR_ITEMS, OBJ),
		"floor_decor_legend": _load_all(FLOOR_ITEMS, OBJ),
		"light_legend": _load_all(LIGHT_ITEMS, OBJ),
		"npc_windup_scale": maxf(0.55, 1.0 - 0.08 * tier),
		"npc_damage_scale": minf(1.0 + 0.12 * tier, 1.8),
	}
	if kind == Kind.DARK:
		title = DARK_TITLES[rng.randi_range(0, DARK_TITLES.size() - 1)]
		lines.append("%s. Lighting budget: zero." % title)
		lines.append("The exit is boxed in by missing textures. One of them is not actually there.")
		settings.merge({
			"objective": "Find the exit. It's sealed behind magenta walls - one of them is fake.",
			"exit_requires_cpu_overload": false,
			"flashlight_works": false,
			"ambient_color": Color(0.06, 0.05, 0.1),
			"npc_load_radius": 90.0,
			"npc_wander_scale": 1.0,
			"npcs_hide": true,
			"npcs_chase": true,
			"cpu_load_multiplier": 1.0,
		})
	else:
		title = PARTY_TITLES[rng.randi_range(0, PARTY_TITLES.size() - 1)]
		lines.append("%s. Someone invited far too many guests." % title)
		lines.append("Scares make the house glitch. Crash it to 100% and the exit door forgets to render.")
		settings.merge({
			"objective": "Scares make the house GLITCH. Crash it (100%) so the exit door stops rendering. Surprise the party!",
			"exit_requires_cpu_overload": true,
			"door_open_time": 6.0,
			"flashlight_works": true,
			"ambient_color": Color(0.82, 0.76, 0.88),
			"npc_load_radius": 0.0,
			"npc_wander_scale": 0.25,
			"npcs_hide": false,
			"npcs_chase": false,
			# One good chain reaction at the table should crash the house (with headroom for decay).
			"cpu_load_multiplier": clampf(150.0 / maxf(party_loot, 1.0), 1.0, 3.0),
		})
	settings["room_title"] = title
	settings["intro_lines"] = lines
	return settings


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


func _wall_hugging_cells(room: Rect2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			var cell := Vector2i(x, y)
			if x == room.position.x or y == room.position.y or x == room.end.x - 1 or y == room.end.y - 1:
				cells.append(cell)
	# Fisher-Yates with our own rng so a seed always gives the same house.
	for i in range(cells.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
	return cells


func _random_free_cell(room: Rect2i) -> Vector2i:
	for attempt in 25:
		var cell := Vector2i(rng.randi_range(room.position.x, room.end.x - 1), rng.randi_range(room.position.y, room.end.y - 1))
		if _cell_at(cell) == "." and not _reserved.has(cell):
			_reserved[cell] = true
			return cell
	return Vector2i(-1, -1)


func _pick_key(items: Dictionary, exclude: Array = []) -> String:
	var keys: Array = items.keys().filter(func(k: String) -> bool: return not exclude.has(k))
	return keys[rng.randi_range(0, keys.size() - 1)]


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

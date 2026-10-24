class_name HouseGenerator
extends RefCounted

## Generates organic haunted mansion floors with authentic room layouts,
## dedicated Safe Rooms, interior doors, wall air vents, furniture, and intentional bug mechanics.
##
## Floor structure:
##   - Room 0: SAFE ROOM (Player start 'P', warm lamp 'l', rug 'r', GUARANTEED 0 monsters).
##   - Themed Rooms: Master Bedroom ('B', 'W'), Grand Library ('S', 't'), Dining Hall ('T'),
##                   Parlor ('C', 'A'), and Wine Cellar ('Z', 'o', 'n').
##   - Interconnected architecture: Rooms share interior walls with 2-tile wide open archways.
##   - Wall Hazards: Air Vents ('a') mounted on corridor walls blowing air into hallways.
##   - Level Bugs (alternating per floor):
##       1. KEY_HUNT (Floor 1): Exit door locked; Golden Skeleton Key ('K') hidden in the Library/Study.
##       2. PHASE_WALL (Floor 2): Exit sealed behind brick wall; exactly one tile is 'F' (flickering, no shadow).
##       3. OVERLOAD (Floor 3): Exit door glitch; push GLITCH meter to 100% to un-render the exit.

enum Kind { PHASE_WALL, KEY_HUNT, OVERLOAD }

const MAX_ATTEMPTS: int = 50

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
const OBJ: String = "res://assets/sprites/objects/%s.png"
const HIDE_ITEMS: Dictionary = {"W": "cupboard", "S": "bookshelf", "C": "couch"}
const DECOR_ITEMS: Dictionary = {"t": "table", "A": "armchair", "L": "lamp", "Q": "plant", "Z": "crate", "O": "clock", "V": "tv", "T": "dining_table"}
const FLOOR_ITEMS: Dictionary = {"r": "rug", "o": "cobweb", "n": "bones", "u": "pumpkin"}
const LIGHT_ITEMS: Dictionary = {"c": "candles"}

const TITLES_PHASE: Array[String] = [
	"The Phantom Wing", "The Whispering Gallery", "The Cellar of Broken Collisions",
	"The East Corridors", "The Forgotten Hallway", "The Shimmering Crypt"
]
const TITLES_KEY: Array[String] = [
	"The Master's Quarters", "The Locked Grand Library", "The Forbidden Study",
	"The Royal Bedchamber", "The Keeper's Sanctum", "The Private Archive"
]
const TITLES_OVERLOAD: Array[String] = [
	"The Grand Banquet Hall (Unoptimized)", "The Haunted Ballroom",
	"The Witch's Great Kitchen", "The Overclocked Gallery", "The Cluttered Parlor"
]

var rng := RandomNumberGenerator.new()

var _w: int
var _h: int
var _grid: Array = []              # _grid[y][x] -> single character
var _rooms: Array[Dictionary] = [] # dict with x, y, w, h, cx, cy, type
var _reserved: Dictionary = {}


## Generates and returns Room properties dictionary for the given floor level.
func generate(level: int, seed_value: int) -> Dictionary:
	# Level 0 is the meticulously crafted Victorian Ground Floor
	if level == 0:
		return _build_ground_floor()

	var tier: int = level / 3
	var bug_cycle: int = level % 3
	var kind: Kind = Kind.KEY_HUNT
	if bug_cycle == 1:
		kind = Kind.PHASE_WALL
	elif bug_cycle == 2:
		kind = Kind.OVERLOAD

	for attempt in MAX_ATTEMPTS:
		rng.seed = seed_value + attempt * 7919
		var settings: Dictionary = _try_generate(tier, kind)
		if not settings.is_empty():
			return settings
			
	push_error("HouseGenerator: failed to generate valid mansion after %d attempts" % MAX_ATTEMPTS)
	return {}


func _try_generate(tier: int, kind: Kind) -> Dictionary:
	var cols: int = 2 if tier == 0 else 3
	var rows: int = 2 if tier < 2 else 3
	var room_w: int = 9 + mini(tier, 2)
	var room_h: int = 7 + mini(tier, 2)
	_w = cols * room_w + (cols + 1)
	_h = rows * room_h + (rows + 1)
	_grid.clear()
	_rooms.clear()
	_reserved.clear()

	# Initialize solid mansion walls
	for y in _h:
		var row: Array = []
		for x in _w:
			row.append("#")
		_grid.append(row)

	# 1. Carve adjacent rooms that share walls
	var room_types: Array[String] = ["safe", "bedroom", "library", "dining", "parlor", "cellar", "exit"]
	var room_idx: int = 0
	for r in rows:
		for c in cols:
			var rx: int = 1 + c * (room_w + 1)
			var ry: int = 1 + r * (room_h + 1)
			for y in range(ry, ry + room_h):
				for x in range(rx, rx + room_w):
					_grid[y][x] = "."
			var r_type: String = "parlor"
			if r == rows - 1 and c == 0:
				r_type = "safe" # South-west = Entrance Foyer (Safe Room)
			elif r == 0 and c == cols - 1:
				r_type = "exit" # North-east = Exit Sanctuary
			else:
				r_type = room_types[clampi(1 + (room_idx % 5), 1, 5)]
			
			_rooms.append({
				"c": c, "r": r,
				"x": rx, "y": ry,
				"w": room_w, "h": room_h,
				"cx": rx + room_w / 2, "cy": ry + room_h / 2,
				"type": r_type
			})
			room_idx += 1

	# Order rooms so Safe Room is index 0 and Exit Room is last
	var safe_room: Dictionary = {}
	var exit_room: Dictionary = {}
	var other_rooms: Array[Dictionary] = []
	for rm in _rooms:
		if rm.type == "safe":
			safe_room = rm
		elif rm.type == "exit":
			exit_room = rm
		else:
			other_rooms.append(rm)
	_rooms.clear()
	_rooms.append(safe_room)
	_rooms.append_array(other_rooms)
	_rooms.append(exit_room)

	# 2. Carve 2-tile wide open archways between horizontal neighbors
	for r in rows:
		for c in range(cols - 1):
			var wall_x: int = 1 + c * (room_w + 1) + room_w
			var mid_y: int = 1 + r * (room_h + 1) + room_h / 2
			_put(Vector2i(wall_x, mid_y), ".")
			_put(Vector2i(wall_x, mid_y + 1), ".")

	# 3. Carve 2-tile wide open archways between vertical neighbors
	for c in cols:
		for r in range(rows - 1):
			var wall_y: int = 1 + r * (room_h + 1) + room_h
			var mid_x: int = 1 + c * (room_w + 1) + room_w / 2
			_put(Vector2i(mid_x, wall_y), ".")
			_put(Vector2i(mid_x + 1, wall_y), ".")

	# 4. Furnish the Safe Room (Entrance Foyer)
	var safe_start := Vector2i(safe_room.cx, safe_room.cy)
	_put(safe_start, "P")
	_reserve_around(safe_start)
	_put(Vector2i(safe_room.cx, safe_room.y), "l")
	_put(Vector2i(safe_room.cx, safe_room.cy + 1), "r")

	# 5. Setup Exit Door on North Wall and Bug
	var exit_placed: bool = _setup_exit_and_bug(exit_room, kind)
	if not exit_placed:
		return {}

	# 6. Furnish other rooms
	for i in range(1, _rooms.size() - 1):
		_furnish_themed_room(_rooms[i], tier)

	# 7. Place wall-mounted air vents
	_place_wall_air_vents(tier)

	# 8. Place monsters in non-safe rooms (gentle start on early tiers!)
	var monster_count: int = 1 + mini(tier, 3)
	_place_monsters(monster_count, tier, kind)

	# 9. Place masks & kids (masks spawn frequently!)
	_place_masks()
	if tier >= 1:
		_place_kids()

	# 10. Validate reachability
	if not _is_valid(kind):
		return {}

	return _build_settings(tier, kind)


# ---------------------------------------------------------------- Level 0 Ground Floor

func _build_ground_floor() -> Dictionary:
	var rows: Array[String] = [
		"################D#######",
		"#o..Z..o#..............#",
		"#.......#......c.......#",
		"#...Z...#..............#",
		"#a......F..............#",
		"#...n...#..............#",
		"#.......#......c.......#",
		"#o.....o#..............#",
		"#####..###########..####",
		"#o..l..o#o...S..o#.....#",
		"#.......#..S...S.#.....#",
		"#...r...#....K...#.....#",
		"#..................M...#",
		"#...P........t...#.....#",
		"#............A...#..g..#",
		"#o.....o#o...c..o#.....#",
		"########################"
	]
	return {
		"room_title": "The Haunted Manor: Ground Floor",
		"objective": "Explore the Study for the Golden Key and unlock the North Exit Door.",
		"layout": "\n".join(rows),
		"npc_legend": _load_all(NPC_PATHS, ""),
		"hide_legend": _load_all(HIDE_ITEMS, OBJ),
		"decor_legend": _load_all(DECOR_ITEMS, OBJ),
		"floor_decor_legend": _load_all(FLOOR_ITEMS, OBJ),
		"light_legend": _load_all(LIGHT_ITEMS, OBJ),
		"exit_requires_cpu_overload": false,
		"exit_requires_key": true,
		"door_open_time": 6.0,
		"flashlight_works": true,
		"ambient_color": Color(0.025, 0.025, 0.04),
		"npc_load_radius": 100.0,
		"npc_wander_scale": 0.65,
		"npcs_hide": true,
		"npcs_chase": true,
		"npc_windup_scale": 0.95,
		"npc_damage_scale": 1.0,
		"cpu_load_multiplier": 1.0,
		"intro_lines": [
			"Floor 1: The Haunted Manor Ground Floor. You start safely in the entrance foyer.",
			"Explore the Study for the Golden Key [K] and Disguise Mask [M] to unlock the North Exit Door."
		]
	}


# ---------------------------------------------------------------- exit & bug

func _setup_exit_and_bug(exit_room: Dictionary, kind: Kind) -> bool:
	var exit_pos := Vector2i(exit_room.cx, exit_room.y - 1)
	_put(exit_pos, "D")
	_reserve_around(exit_pos)
	
	var front_pos := Vector2i(exit_room.cx, exit_room.y)
	_put(front_pos, ".")
	_reserved[front_pos] = true

	match kind:
		Kind.PHASE_WALL:
			# Seal the exit door behind a brick wall partition; exactly ONE tile is 'F' (phasable)
			var seal_y: int = exit_room.y + 2
			var fake_x: int = exit_room.cx
			for x in range(exit_room.x, exit_room.x + exit_room.w):
				if x == fake_x:
					_put(Vector2i(x, seal_y), "F")
				else:
					_put(Vector2i(x, seal_y), "#")
			_put(Vector2i(exit_room.x + 1, exit_room.y), "c")

		Kind.KEY_HUNT:
			# Exit door is locked: place key 'K' in Bedroom or Library
			var key_room: Dictionary = _rooms[1]
			var key_pos := Vector2i(key_room.cx, key_room.cy)
			_put(key_pos, "K")
			_put(Vector2i(exit_room.x + 1, exit_room.y), "c")

		Kind.OVERLOAD:
			# Exit door requires 100% CPU overload: decorate with candles
			_put(Vector2i(exit_room.x + 1, exit_room.y), "c")
			
	return true


# ---------------------------------------------------------------- furnishing

func _furnish_themed_room(room: Dictionary, _tier: int) -> void:
	match room.type:
		"bedroom":
			# Bed, Wardrobe (hide spot), Crate, Rug
			_put_safe(Vector2i(room.x + 1, room.y + 1), "B")  # Victorian Bed
			_put_safe(Vector2i(room.x + room.w - 2, room.y + 1), "W")  # Wardrobe
			_put_safe(Vector2i(room.cx, room.cy), "r")  # Rug
			_put_safe(Vector2i(room.x + room.w - 2, room.y + room.h - 2), "Z")  # Crate
		"library":
			# Bookshelves, Desk, Armchair, Candles
			_put_safe(Vector2i(room.x + 1, room.y + 1), "S")  # Bookshelf
			_put_safe(Vector2i(room.x + room.w - 2, room.y + 1), "S")  # Bookshelf
			_put_safe(Vector2i(room.cx, room.cy), "t")  # Study desk
			_put_safe(Vector2i(room.cx + 1, room.cy), "A")  # Armchair
			_put_safe(Vector2i(room.x + 1, room.y + room.h - 2), "c")  # Candles
		"dining":
			# Dining Table, Chairs, Candelabra, Wall Lamp
			_put_safe(Vector2i(room.cx, room.cy), "T")  # Dining table
			_put_safe(Vector2i(room.cx - 1, room.cy), "A")
			_put_safe(Vector2i(room.cx + 1, room.cy), "A")
			_put_safe(Vector2i(room.cx, room.y), "l")  # Wall Lamp
			_put_safe(Vector2i(room.x + 1, room.y + room.h - 2), "c")
		"parlor":
			# Couch, TV, Grandfather Clock, Armchair
			_put_safe(Vector2i(room.x + 1, room.y + 1), "C")  # Couch
			_put_safe(Vector2i(room.x + room.w - 2, room.y + 1), "O")  # Clock
			_put_safe(Vector2i(room.cx, room.cy), "V")  # TV
			_put_safe(Vector2i(room.cx, room.cy + 1), "r")  # Rug
		"cellar":
			# Crates, Cobwebs, Bones
			_put_safe(Vector2i(room.x + 1, room.y + 1), "o")  # Cobweb
			_put_safe(Vector2i(room.x + room.w - 2, room.y + 1), "o")
			_put_safe(Vector2i(room.x + 1, room.y + room.h - 2), "Z")  # Crate
			_put_safe(Vector2i(room.cx, room.cy), "n")  # Bones
		_:
			_put_safe(Vector2i(room.x + 1, room.y + 1), "W")


func _put_safe(pos: Vector2i, ch: String) -> void:
	if _cell_at(pos) == "." and not _reserved.has(pos):
		_put(pos, ch)
		_reserved[pos] = true


# ---------------------------------------------------------------- air vents

func _place_wall_air_vents(tier: int) -> void:
	var vent_count: int = 1 + mini(tier, 2)
	var placed: int = 0
	
	# Search for interior wall tiles directly adjacent to open floor
	for y in range(2, _h - 2):
		if placed >= vent_count:
			break
		for x in range(2, _w - 2):
			if placed >= vent_count:
				break
			var cell := Vector2i(x, y)
			if _cell_at(cell) == "#" and not _reserved.has(cell):
				# Must be adjacent to walkable floor
				for dir in [Vector2i.DOWN, Vector2i.UP, Vector2i.RIGHT, Vector2i.LEFT]:
					var neighbor: Vector2i = cell + dir
					if _cell_at(neighbor) == "." and not _reserved.has(neighbor):
						_put(cell, "a")
						_reserved[cell] = true
						placed += 1
						break


# ---------------------------------------------------------------- monsters

func _place_monsters(count: int, tier: int, _kind: Kind) -> void:
	# Rooms 1..N-1 (NEVER in Room 0: Safe Room!)
	var candidate_rooms: Array[Dictionary] = []
	for i in range(1, _rooms.size()):
		candidate_rooms.append(_rooms[i])

	var pool: String = "gh"  # ghost and witch
	if tier >= 1:
		pool += "mw"  # vampire and werewolf
	if tier >= 2:
		pool += "jG"  # jack-o'-lantern and big jack

	for i in count:
		var r: Dictionary = candidate_rooms[i % candidate_rooms.size()]
		var free_cell: Vector2i = _random_free_room_cell(r)
		if free_cell.x >= 0:
			var m_char: String = pool[rng.randi_range(0, pool.length() - 1)]
			_put(free_cell, m_char)


func _place_kids() -> void:
	if _rooms.size() <= 2:
		return
	var kid_room: Dictionary = _rooms[rng.randi_range(1, _rooms.size() - 2)]
	var cell: Vector2i = _random_free_room_cell(kid_room)
	if cell.x >= 0:
		_put(cell, "&")


func _place_masks() -> void:
	var mask_count: int = clampi(2 + _rooms.size() / 3, 2, 4)
	var placed: int = 0
	for i in range(1, _rooms.size()):
		if placed >= mask_count:
			break
		var cell: Vector2i = _random_free_room_cell(_rooms[i])
		if cell.x >= 0:
			_put(cell, "M")
			placed += 1


func _random_free_room_cell(room: Dictionary) -> Vector2i:
	for attempt in 30:
		var cx: int = rng.randi_range(room.x, room.x + room.w - 1)
		var cy: int = rng.randi_range(room.y, room.y + room.h - 1)
		var cell := Vector2i(cx, cy)
		if _cell_at(cell) == "." and not _reserved.has(cell):
			return cell
	return Vector2i(-1, -1)


# ---------------------------------------------------------------- validation

func _is_valid(kind: Kind) -> bool:
	var start: Vector2i = _find("P")
	var exit: Vector2i = _find("D")
	if start.x < 0 or exit.x < 0:
		return false

	var exit_front: Vector2i = exit + Vector2i.DOWN

	# Check reachable with fake walls open
	var reach: Dictionary = _flood(start, true)
	if not reach.has(exit_front):
		return false

	# For Phase Wall levels: exit front MUST NOT be reachable without phasing through 'F'!
	if kind == Kind.PHASE_WALL:
		var reach_solid: Dictionary = _flood(start, false)
		if reach_solid.has(exit_front):
			return false

	# For Key Hunt levels: key 'K' must also be reachable
	if kind == Kind.KEY_HUNT:
		var key_pos: Vector2i = _find("K")
		if key_pos.x >= 0 and not reach.has(key_pos):
			return false

	return true


func _flood(from: Vector2i, fake_open: bool) -> Dictionary:
	var seen: Dictionary = {from: true}
	var queue: Array[Vector2i] = [from]
	var head: int = 0
	
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if n.x >= 0 and n.y >= 0 and n.x < _w and n.y < _h and not seen.has(n):
				var ch: String = _cell_at(n)
				if _is_traversable(ch, fake_open):
					seen[n] = true
					queue.append(n)
	return seen


func _is_traversable(ch: String, fake_open: bool) -> bool:
	if ch == "F":
		return fake_open
	if ch == "#" or ch == " " or ch == "a" or ch == "v" or ch == "D" or ch == "B" or ch == "W" or ch == "S" or ch == "C" or ch == "t" or ch == "T" or ch == "Z" or ch == "V" or ch == "O":
		return false
	return true


# ---------------------------------------------------------------- helpers

func _cell_at(pos: Vector2i) -> String:
	if pos.y < 0 or pos.y >= _grid.size() or pos.x < 0 or pos.x >= _grid[pos.y].size():
		return " "
	return _grid[pos.y][pos.x]


func _put(pos: Vector2i, ch: String) -> void:
	if pos.y >= 0 and pos.y < _grid.size() and pos.x >= 0 and pos.x < _grid[pos.y].size():
		_grid[pos.y][pos.x] = ch


func _reserve_around(pos: Vector2i) -> void:
	_reserved[pos] = true
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		_reserved[pos + d] = true


func _find(ch: String) -> Vector2i:
	for y in _h:
		for x in _w:
			if _grid[y][x] == ch:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _load_all(dict: Dictionary, pattern: String) -> Dictionary:
	var res: Dictionary = {}
	for k in dict:
		var path: String = dict[k] if pattern.is_empty() else (pattern % dict[k])
		res[k] = load(path)
	return res


# ---------------------------------------------------------------- settings output

func _build_settings(tier: int, kind: Kind) -> Dictionary:
	var rows: PackedStringArray = []
	for row in _grid:
		rows.append("".join(row))

	var title: String = ""
	var objective: String = ""
	var exit_req_overload: bool = false
	var exit_req_key: bool = false
	var intro: Array[String] = []

	match kind:
		Kind.PHASE_WALL:
			title = TITLES_PHASE[rng.randi_range(0, TITLES_PHASE.size() - 1)]
			objective = "Find the Exit Door! The chamber is sealed, but one wall flickers and has no shadow—walk through it."
			intro = [
				"%s. You start safely in the entrance foyer." % title,
				"The exit is sealed behind brick walls. Find the bugged wall—it subtly flickers and has no shadow."
			]

		Kind.KEY_HUNT:
			title = TITLES_KEY[rng.randi_range(0, TITLES_KEY.size() - 1)]
			objective = "Search the dark rooms for the Golden Key to unlock the Exit Door."
			exit_req_key = true
			intro = [
				"%s. Heavy doors lock the way forward." % title,
				"Explore with your flashlight to locate the Golden Key, then unlock the Exit Door."
			]

		Kind.OVERLOAD:
			title = TITLES_OVERLOAD[rng.randi_range(0, TITLES_OVERLOAD.size() - 1)]
			objective = "Ambush entities from hiding or scare trick-or-treaters to push GLITCH to 100% and un-render the Exit!"
			exit_req_overload = true
			intro = [
				"%s. The house is unstable." % title,
				"Scare entities or ambush from wardrobes to push GLITCH to 100% and un-render the Exit Door!"
			]

	return {
		"room_title": title,
		"objective": objective,
		"layout": "\n".join(rows),
		"npc_legend": _load_all(NPC_PATHS, ""),
		"hide_legend": _load_all(HIDE_ITEMS, OBJ),
		"decor_legend": _load_all(DECOR_ITEMS, OBJ),
		"floor_decor_legend": _load_all(FLOOR_ITEMS, OBJ),
		"light_legend": _load_all(LIGHT_ITEMS, OBJ),
		"exit_requires_cpu_overload": exit_req_overload,
		"exit_requires_key": exit_req_key,
		"door_open_time": 6.0,
		"flashlight_works": true,
		"ambient_color": Color(0.025, 0.025, 0.04),
		"npc_load_radius": 100.0,
		"npc_wander_scale": 0.75,
		"npcs_hide": true,
		"npcs_chase": true,
		"npc_windup_scale": maxf(0.5, 0.95 - 0.08 * tier),
		"npc_damage_scale": minf(1.0 + 0.15 * tier, 2.0),
		"cpu_load_multiplier": 1.1,
		"intro_lines": intro
	}

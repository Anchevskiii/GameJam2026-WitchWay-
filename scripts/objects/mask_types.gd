class_name MaskTypes
extends RefCounted

## Procedurally drawn pixel masks worn on the player's face (or, for the jack-o'-lantern,
## replacing the whole head). Used by the pickup icon and by PlayerController.

enum Type { GHOST, JACK, SKULL, DEVIL }

const NAMES: Dictionary = {
	Type.GHOST: "GHOST MASK",
	Type.JACK: "JACK-O'-LANTERN MASK",
	Type.SKULL: "SKULL MASK",
	Type.DEVIL: "DEVIL MASK",
}

const COLORS: Dictionary = {
	"w": Color(0.94, 0.96, 1.0),
	"g": Color(0.65, 0.72, 0.85),
	"k": Color(0.05, 0.05, 0.1),
	"r": Color(0.82, 0.1, 0.1),
	"y": Color(1.0, 0.85, 0.2),
}

const GHOST_ROWS: Array[String] = [
	"...wwwwww...",
	"..wwwwwwww..",
	".wwwwwwwwww.",
	".wwkkwwkkww.",
	".wwkkwwkkww.",
	".wwkkwwkkww.",
	".wwwwwwwwww.",
	".wwwwkkwwww.",
	".wwwkkkkwww.",
	".wwwkkkkwww.",
	".wwwwkkwwww.",
	".wgwwwwwwgw.",
	".wg.wwww.gw.",
]
const SKULL_ROWS: Array[String] = [
	"..wwwwww..",
	".wwwwwwww.",
	"wwwwwwwwww",
	"wwkkwwkkww",
	"wkkkwwkkkw",
	"wkkkwwkkkw",
	"wwkkwwkkww",
	"wwwwkkwwww",
	".wwwwwwww.",
	".wkwkwkwk.",
	".wwwwwwww.",
]
const DEVIL_ROWS: Array[String] = [
	"kk........kk",
	"krr......rrk",
	".rrrrrrrrrr.",
	"rrrrrrrrrrrr",
	"rrykrrrrkyrr",
	"rrrkrrrrkrrr",
	"rrrrrrrrrrrr",
	"rrrrrkkrrrrr",
	"rrkrrrrrrkrr",
	".rrkkkkkkrr.",
	"..rrrrrrrr..",
]

static var _cache: Dictionary = {}


static func random_type() -> int:
	return randi() % Type.size()


## True for masks that cover the entire head instead of just the face.
static func covers_head(type: int) -> bool:
	return type == Type.JACK


## Vertical offset relative to the sprite node, whose origin is at the FEET (StumbleAnimator pins it\n## there): the head spans y -32..-16, so these centre the mask on the face / head.
static func offset_y(type: int) -> float:
	return -24.0 if type == Type.JACK else -22.0


static func texture(type: int) -> Texture2D:
	if not _cache.has(type):
		var img: Image
		match type:
			Type.GHOST:
				img = _from_rows(GHOST_ROWS)
			Type.SKULL:
				img = _from_rows(SKULL_ROWS)
			Type.DEVIL:
				img = _from_rows(DEVIL_ROWS)
			_:
				img = _jack_image()
		_cache[type] = ImageTexture.create_from_image(img)
	return _cache[type]


static func _from_rows(rows: Array[String]) -> Image:
	var img := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in rows[y].length():
			var ch: String = rows[y][x]
			if COLORS.has(ch):
				img.set_pixel(x, y, COLORS[ch])
	return img


static func _jack_image() -> Image:
	var img := Image.create(18, 16, false, Image.FORMAT_RGBA8)
	var orange := Color(0.96, 0.5, 0.08)
	var dark := Color(0.7, 0.3, 0.05)
	var green := Color(0.25, 0.6, 0.15)
	var glow: Color = COLORS["y"]
	for y in 16:
		for x in 18:
			var nx: float = (x - 8.5) / 9.0
			var ny: float = (y - 8.5) / 7.5
			var d: float = nx * nx + ny * ny
			if d > 1.0:
				continue
			var col: Color = dark if (d > 0.82 or x == 4 or x == 8 or x == 9 or x == 13) else orange
			img.set_pixel(x, y, col)
	for y in range(0, 3):
		for x in [8, 9]:
			img.set_pixel(x, y, green)
	img.set_pixel(10, 1, green)
	# Glowing triangle eyes
	for i in 3:
		for x in range(5 - i, 6 + i):
			img.set_pixel(x, 5 + i, glow)
		for x in range(12 - i, 13 + i):
			img.set_pixel(x, 5 + i, glow)
	# Jagged grin
	for x in range(4, 14):
		img.set_pixel(x, 10, glow)
		if x % 3 != 0:
			img.set_pixel(x, 11, glow)
		if x > 4 and x < 13 and x % 3 == 1:
			img.set_pixel(x, 12, glow)
	return img

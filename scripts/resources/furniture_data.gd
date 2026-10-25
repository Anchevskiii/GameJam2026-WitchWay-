class_name FurnitureData
extends Resource

## One piece of furniture or decoration from the interior sprite sheet (LimeZu Modern Interiors).
## Saved as .tres files in data/furniture/ and used by Room legends and RoomTheme lists.
##
## Placement in a layout: the letter marks the TOP-LEFT tile of the footprint; the other
## footprint tiles are written as "+" (blocked filler). The sprite stands on the footprint's
## bottom edge and may be taller than it (3/4 view: tall pieces overlap the wall behind them).

enum Kind {
	NORTH,   ## big piece that stands against the back wall (bookshelf, wardrobe, fireplace)
	SIDE,    ## one-tile piece along the walls (lamp, plant, chair, vase)
	CENTER,  ## middle of the room (table, desk)
	RUG,     ## walk over it, drawn on the floor
	WALL,    ## hangs on a wall face (window, painting, mirror) - goes on a "#" tile
}

@export var display_name: String = ""
## AtlasTexture: a region of the interior sprite sheet.
@export var texture: Texture2D
@export var kind: Kind = Kind.SIDE
## Tiles it covers. Rugs and wall decorations don't block anything.
@export var footprint: Vector2i = Vector2i.ONE
## The player (and sneaky monsters) can hide in/behind it.
@export var hideable: bool = false
## Drawers, dressers, cabinets: the player can search it (hold E) - keys hide in these.
@export var searchable: bool = false
## Alpha > 0 means it glows (lamps, fireplace, stove).
@export var light_color: Color = Color(0, 0, 0, 0)


func blocks_movement() -> bool:
	return kind != Kind.RUG and kind != Kind.WALL


func emits_light() -> bool:
	return light_color.a > 0.0

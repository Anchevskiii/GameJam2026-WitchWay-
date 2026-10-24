class_name RoomTheme
extends Resource

## The look and furniture set of one kind of room (Library, Bedroom, Kitchen...).
## Saved as .tres files in data/themes/. Hand-made rooms use one as their default_theme;
## HouseGenerator picks one per room of a generated floor and furnishes it from these lists.

@export var display_name: String = "Room"
## Wall face pattern (rows of assets/sprites/interiors/house_interior.png).
@export_enum("red", "yellow", "mint", "wood_light", "wood_mid", "wood_red", "grey", "beige", "stripes_brown", "stripes_purple") var wallpaper: int = 8
@export_enum("checker_brown", "checker_dark", "herringbone", "grey_tiles", "red_brick", "teal_tiles", "yellow_tiles", "stone", "old_wood") var floor_pattern: int = 0

@export_group("Furniture")
## Big pieces against the back wall. The first hideable one is always used once.
@export var north_pieces: Array[FurnitureData] = []
## Windows, paintings, mirrors on the back wall.
@export var wall_decor: Array[FurnitureData] = []
## One-tile pieces along the side and bottom walls.
@export var side_pieces: Array[FurnitureData] = []
## Table/desk in the middle of bigger rooms.
@export var center_pieces: Array[FurnitureData] = []
@export var rugs: Array[FurnitureData] = []

@export_group("Arrangement")
## The room's showpiece, centred on the back wall (fireplace, bed, stove). Optional.
@export var feature_pieces: Array[FurnitureData] = []
## Small pieces put right beside the showpiece (nightstands, lamps).
@export var feature_flank: Array[FurnitureData] = []
## One-tile pieces mixed in between the back-wall furniture and put in corners (plants, lamps).
@export var accent_pieces: Array[FurnitureData] = []
## true: the table set (or just its rug) goes right in front of the showpiece (armchairs by the
## fireplace, a rug at the foot of the bed). false: it goes in the middle of the room.
@export var set_in_front_of_feature: bool = false
## Chairs around the table (a center_pieces entry), by the side of the table they stand on.
## Each one faces the table: the west chair faces right, the north chair faces down...
@export var seat_west: FurnitureData
@export var seat_east: FurnitureData
@export var seat_north: FurnitureData
@export var seat_south: FurnitureData
## Walk-over clutter scattered on the floor (cushions, books).
@export var floor_clutter: Array[FurnitureData] = []

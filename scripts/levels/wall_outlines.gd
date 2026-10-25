class_name WallOutlines
extends Node2D

## Draws the dark outline around the tops of the walls (the lavender ceiling) as one overlay.
## Room works out the rectangles from the layout (see Room._build_wall_outlines), so every
## joint - T, L, crossings, inside and outside corners - closes up properly.
## Created by Room after the walls are painted.

const COLOR: Color = Color8(62, 60, 88)

var rects: Array[Rect2] = []


func _draw() -> void:
	for r in rects:
		draw_rect(r, COLOR)

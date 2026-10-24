class_name PropData
extends Resource

## One kind of droppable prop (sock, rubber duck, cauldron...).
## Saved as .tres files in data/props/. Every spawned prop adds `load_weight` to the CPU meter.

## Props at or above this weight count as "heavy": thud sound + the Narrator complains.
const HEAVY_THRESHOLD: float = 8.0

@export var prop_name: String = "Sock"
@export var texture: Texture2D
## Glitch added when this prop spawns. Light 1-2, medium 3-5, heavy 8-12.
@export_range(0.0, 20.0, 0.5) var load_weight: float = 1.0
@export var sprite_scale: float = 2.0
## Heavier props roll further and knock NPCs over more easily.
@export var mass: float = 1.0
## > 0: the player picks this up by walking over it and gets this much sanity back (candy!).
@export var sanity_restore: float = 0.0


func is_heavy() -> bool:
	return load_weight >= HEAVY_THRESHOLD

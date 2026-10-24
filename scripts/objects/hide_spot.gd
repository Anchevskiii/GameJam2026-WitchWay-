class_name HideSpot
extends Node2D

## A cupboard / bookshelf / couch someone can hide in. Both the player (E) and some
## monsters use them. Whoever is inside peeks out now and then (a head sliding out from
## the side), so hiding is never invisible - you can spot a monster lying in wait.
## Created by Room for every letter in its hide_legend (as a child of the furniture body).

## How close (pixels, from the furniture's centre) someone must be to hide here.
@export var reach: float = 48.0
## Seconds between peeks, and how long a peek lasts.
@export var peek_interval_min: float = 1.2
@export var peek_interval_max: float = 2.8
@export var peek_duration: float = 0.9
## Fraction of the occupant's sprite (from the top) shown when peeking: the head.
@export var head_fraction: float = 0.45

var occupied: bool = false
## Who is inside (the player or an Npc). null when empty.
var occupant: Node2D = null
## An NPC walking over to hide here. Other NPCs pick a different spot.
var reserved_by: Node = null

var _prompt: Label
var _peek: Sprite2D
var _peek_timer: float = 0.0
var _peek_side: float = 1.0
var _player: Node2D = null


func _ready() -> void:
	add_to_group("hide_spots")
	_prompt = Label.new()
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_prompt.material = unshaded
	_prompt.add_theme_font_size_override("font_size", 18)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 5)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(260, 24)
	_prompt.position = Vector2(-130, -58)
	_prompt.z_index = 30
	_prompt.visible = false
	add_child(_prompt)

	# The peeking head: drawn BEHIND the furniture sprite and slid out sideways.
	_peek = Sprite2D.new()
	_peek.z_index = -1
	_peek.region_enabled = true
	_peek.visible = false
	add_child(_peek)


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	_update_prompt()
	if occupied:
		_update_peek(delta)


func is_player_in_reach() -> bool:
	return _player != null and global_position.distance_to(_player.global_position) <= reach


## True if `who` may start walking here / hide here.
func is_free_for(who: Node) -> bool:
	return not occupied and (reserved_by == null or reserved_by == who or not is_instance_valid(reserved_by))


func set_occupied(value: bool, who: Node2D = null) -> void:
	occupied = value
	occupant = who if value else null
	reserved_by = null
	_peek.visible = false
	_peek_timer = randf_range(0.3, 0.8)  # first peek comes quickly so it's noticeable
	_wobble()


# ---------------------------------------------------------------- peeking

func _update_peek(delta: float) -> void:
	_peek_timer -= delta
	if _peek_timer > 0.0:
		return
	if _peek.visible:
		_peek.visible = false
		_peek_timer = randf_range(peek_interval_min, peek_interval_max)
	else:
		_start_peek()
		_peek_timer = peek_duration


func _start_peek() -> void:
	var occupant_sprite: Sprite2D = _find_sprite(occupant)
	var furniture_sprite: Sprite2D = _find_sprite(get_parent())
	if occupant_sprite == null or occupant_sprite.texture == null or furniture_sprite == null:
		return
	var tex: Texture2D = occupant_sprite.texture
	var head_height: float = roundf(tex.get_height() * head_fraction)
	_peek.texture = tex
	_peek.region_rect = Rect2(0, 0, tex.get_width(), head_height)
	_peek.modulate = occupant_sprite.modulate
	_peek.modulate.a = 1.0
	_peek.scale = occupant_sprite.scale.abs()
	_peek_side = -_peek_side if randf() < 0.5 else _peek_side
	_peek.flip_h = _peek_side < 0.0

	# Start hidden behind the furniture, slide out past its edge, hold, slide back in.
	# Work in this node's space: the furniture sprite may be offset (3/4-view furniture
	# stands on its footprint and rises above it).
	var rect: Rect2 = furniture_sprite.get_rect()
	rect.position += furniture_sprite.global_position - global_position
	var center_x: float = rect.get_center().x
	var half_w: float = rect.size.x * 0.5
	var top_y: float = rect.position.y + head_height * _peek.scale.y * 0.5 + 2.0
	var hidden_x: float = center_x + _peek_side * (half_w - tex.get_width() * 0.5 * _peek.scale.x)
	# Slide out until most of the head is past the edge - it should be noticeable.
	var out_x: float = center_x + _peek_side * (half_w + tex.get_width() * 0.3 * _peek.scale.x)
	_peek.position = Vector2(hidden_x, top_y)
	_peek.visible = true
	var tween: Tween = _peek.create_tween()
	tween.tween_property(_peek, "position:x", out_x, 0.15)
	tween.tween_interval(peek_duration - 0.3)
	tween.tween_property(_peek, "position:x", hidden_x, 0.15)


func _find_sprite(node: Node) -> Sprite2D:
	if node == null:
		return null
	for child in node.get_children():
		if child is Sprite2D and child != _peek:
			return child
	return null


# ---------------------------------------------------------------- prompt / wobble

## True when PlayerController picks this HideSpot as the single active interaction target.
var is_active_target: bool = false

func _update_prompt() -> void:
	if _player == null:
		return
	var player_hidden_here: bool = occupied and occupant == _player
	if player_hidden_here:
		_prompt.text = "[SPACE] JUMP OUT   [E] SNEAK OUT"
		_prompt.visible = true
	else:
		_prompt.text = "[E] HIDE"
		_prompt.visible = is_active_target and not _player.get("is_hidden")


## Little wobble of the furniture so it's clear someone just moved in/out.
func _wobble() -> void:
	var furniture: Node2D = get_parent() as Node2D
	if furniture == null or not furniture.is_inside_tree():
		return
	var tween: Tween = furniture.create_tween()
	tween.tween_property(furniture, "rotation", 0.08, 0.06)
	tween.tween_property(furniture, "rotation", -0.06, 0.08)
	tween.tween_property(furniture, "rotation", 0.0, 0.06)

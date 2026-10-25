class_name Searchable
extends Node2D

## Drawers, dressers, cabinets: hold E next to one to search it (you stand still meanwhile,
## so keep an eye out). Inside: a key for the exit, candy, nothing... or something that
## grabs you. Each piece can be searched once.
## Created by Room as a child of every searchable piece of furniture.

enum Contents { NOTHING, CANDY, KEY, SCARE }

const CANDY: PropData = preload("res://data/props/candy.tres")
const KEY_TEXTURE: Texture2D = preload("res://assets/sprites/objects/key.png")

@export var contents: Contents = Contents.NOTHING
## How close (pixels, from the furniture's centre) the player must be.
@export var reach: float = 52.0
## Seconds of holding E.
@export var search_time: float = 1.1
@export var scare_damage: float = 14.0

var searched: bool = false
## 0..1 while the player is searching (drawn as a ring).
var progress: float = 0.0

var _prompt: Label
var _player: Node2D = null


func _ready() -> void:
	add_to_group("searchables")
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	z_index = 60
	_prompt = Label.new()
	_prompt.material = unshaded
	_prompt.add_theme_font_size_override("font_size", 17)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.98, 0.78))
	_prompt.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(200, 22)
	_prompt.position = Vector2(-100, -54)
	_prompt.z_index = 60
	_prompt.visible = false
	add_child(_prompt)


## True when PlayerController picks this Searchable as the single active interaction target.
var is_active_target: bool = false

func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	_prompt.visible = not searched and (is_active_target or progress > 0.0)
	_prompt.text = "SEARCHING..." if progress > 0.0 else "Hold E: search"
	queue_redraw()


func is_player_in_reach() -> bool:
	return _player != null and _player.visible and global_position.distance_to(_player.global_position) <= reach


func _draw() -> void:
	if progress > 0.0 and not searched:
		draw_circle(Vector2(0, -30), 12.0, Color(0.0, 0.0, 0.0, 0.65))
		draw_arc(Vector2(0, -30), 12.0, 0.0, TAU, 24, Color(0.0, 0.0, 0.0, 0.95), 5.5)
		draw_arc(Vector2(0, -30), 12.0, -PI / 2, -PI / 2 + TAU * progress, 24, Color(1.0, 0.96, 0.45, 1.0), 3.8)


## Called by the player when the search is done.
func open() -> void:
	searched = true
	progress = 0.0
	var top: Vector2 = global_position + Vector2(0, -24)
	match contents:
		Contents.KEY:
			GameManager.add_key()
			AudioManager.play("key")
			FloatingText.spawn(self, top, "KEY %d/%d" % [GameManager.keys_found, GameManager.keys_needed], Color(1.0, 0.85, 0.3), 22)
			_show_key(top)
			Narrator.say_event("key_found" if not GameManager.has_all_keys() else "last_key", {}, true)
		Contents.CANDY:
			AudioManager.play("pop", -3.0, 1.15)
			for i in 2:
				Prop.spawn(CANDY, top + Vector2(0, 30), Vector2(randf_range(-60, 60), randf_range(40, 90)), get_tree())
			FloatingText.spawn(self, top, "candy!", Color(1.0, 0.6, 0.85), 16)
		Contents.SCARE:
			EventBus.jumpscare_requested.emit("ghoul", scare_damage)
			EventBus.noise_made.emit(global_position, 200.0)
		_:
			if randf() < 0.30:
				AudioManager.play("poltergeist", -3.5, randf_range(0.96, 1.04))
			FloatingText.spawn(self, top, "nothing...", Color(0.7, 0.7, 0.75), 14)


func _show_key(at: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = KEY_TEXTURE
	sprite.scale = Vector2.ONE * 2.0
	sprite.z_index = 30
	sprite.global_position = at
	get_tree().get_first_node_in_group("prop_layer").add_child(sprite)
	var tween: Tween = sprite.create_tween()
	tween.tween_property(sprite, "global_position:y", at.y - 30.0, 0.8)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.4).set_delay(0.5)
	tween.tween_callback(sprite.queue_free)

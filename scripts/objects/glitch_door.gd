class_name GlitchDoor
extends StaticBody2D

## Exit door of a room. Walking into the open doorway finishes the level (EventBus.level_completed).
## Attached to: StaticBody2D root of scenes/objects/bugs/glitch_door.tscn
##
## requires_cpu_overload = false: a normal open doorway.
## requires_cpu_overload = true: the door "fails to render" as CPU load climbs:
##   50% flicker -> 75% missing texture -> 90% jitter/z-fight -> 100% GONE (walkable)
## (GONE is triggered by EventBus.glitch_mode_toggled, emitted the moment load hits 100%.)
## Locked: on floors with keys (GameManager.keys_needed) the exit stays shut - and an
## overloaded door refuses to vanish - until every key has been found.
## After `rerender_delay` seconds it comes back solid - or later, if the player is far away:
## the timer always covers the walk from where the player is when the door vanishes. It re-arms once load drops
## below `rearm_below_load`, so the player has to push the meter up again.

enum Stage { NORMAL, FLICKER, MISSING, JITTER, GONE }

const DOOR_TEXTURE: Texture2D = preload("res://assets/sprites/environment/door.png")
const MISSING_TEXTURE: Texture2D = preload("res://assets/sprites/environment/missing_texture.png")

@export var requires_cpu_overload: bool = true
@export var flicker_at: float = 50.0
@export var missing_texture_at: float = 75.0
@export var jitter_at: float = 90.0
## Seconds the door stays gone before it re-renders.
@export var rerender_delay: float = 4.0
@export var rearm_below_load: float = 70.0
## Extra time on top of the walk: detours around furniture and monsters (x) plus a flat bonus.
@export var walk_time_factor: float = 1.6
@export var walk_time_bonus: float = 2.5

## Set by Room; used to measure the walk from the player to this door.
var room: Room = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var exit_area: Area2D = $ExitArea
@onready var countdown_label: Label = $CountdownLabel

var stage: Stage = Stage.NORMAL
var _gone_time_left: float = 0.0
var _armed: bool = true
var _used: bool = false


func _ready() -> void:
	countdown_label.visible = false
	exit_area.body_entered.connect(_on_exit_area_body_entered)
	# React to the moment load HITS 100% (an event). Polling the value would miss it,
	# because GameManager starts decaying it again in the very same frame.
	EventBus.glitch_mode_toggled.connect(_on_glitch_mode_toggled)
	EventBus.keys_changed.connect(_on_keys_changed)
	if not requires_cpu_overload and GameManager.has_all_keys():
		_show_as_open_doorway()
	_update_lock_label()


func _process(delta: float) -> void:
	if not requires_cpu_overload:
		return
	if stage == Stage.GONE:
		_gone_time_left -= delta
		countdown_label.text = "RE-RENDERING IN %d" % ceili(_gone_time_left)
		if _gone_time_left <= 0.0:
			_rerender()
		return

	var load_pct: float = GameManager.current_cpu_overload
	if not _armed:
		if load_pct < rearm_below_load:
			_armed = true
		_set_stage(Stage.NORMAL)
	elif load_pct >= jitter_at:
		_set_stage(Stage.JITTER)
	elif load_pct >= missing_texture_at:
		_set_stage(Stage.MISSING)
	elif load_pct >= flicker_at:
		_set_stage(Stage.FLICKER)
	else:
		_set_stage(Stage.NORMAL)
	_animate_stage()


func _set_stage(new_stage: Stage) -> void:
	if new_stage == stage:
		return
	var got_worse: bool = new_stage > stage
	stage = new_stage
	sprite.texture = MISSING_TEXTURE if stage >= Stage.MISSING else DOOR_TEXTURE
	sprite.offset = Vector2.ZERO
	sprite.visible = true
	if not got_worse:
		return
	AudioManager.play("flicker", -4.0)
	match stage:
		Stage.FLICKER:
			Narrator.say_event("door_flicker")
		Stage.MISSING:
			Narrator.say_event("door_missing_texture")
		Stage.JITTER:
			Narrator.say_event("door_jitter")


func _animate_stage() -> void:
	match stage:
		Stage.FLICKER:
			sprite.visible = randf() > 0.12
		Stage.MISSING:
			sprite.visible = randf() > 0.06
		Stage.JITTER:
			sprite.offset = Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0))
			z_index = 1 if randf() > 0.5 else -1  # z-fighting with the wall


func _on_glitch_mode_toggled(is_active: bool) -> void:
	if not (is_active and requires_cpu_overload and _armed and stage != Stage.GONE):
		return
	if not GameManager.has_all_keys():
		Narrator.say_event("door_locked", {}, true)  # the crash doesn't help a locked door
		return
	_vanish()


func _on_keys_changed(_found: int, _needed: int) -> void:
	_update_lock_label()
	if GameManager.has_all_keys() and not requires_cpu_overload and collision and not collision.disabled:
		AudioManager.play("creak", 0.0, 0.7)
		_show_as_open_doorway()
		for body in exit_area.get_overlapping_bodies():
			_on_exit_area_body_entered(body)  # already standing in the doorway


## "LOCKED 1/3" over the door while keys are missing.
func _update_lock_label() -> void:
	if stage == Stage.GONE:
		return
	countdown_label.visible = not GameManager.has_all_keys()
	countdown_label.text = "LOCKED %d/%d KEYS" % [GameManager.keys_found, GameManager.keys_needed]


func _vanish() -> void:
	stage = Stage.GONE
	_gone_time_left = maxf(rerender_delay, _time_to_reach())
	sprite.visible = false
	collision.set_deferred("disabled", true)
	countdown_label.visible = true
	AudioManager.play("glitch")
	EventBus.bug_triggered.emit("door_not_rendered")
	Narrator.say_event("door_gone", {}, true)


## Seconds a player walking (not sprinting) needs to get here, with some slack.
func _time_to_reach() -> float:
	var player: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController
	if room == null or player == null:
		return 0.0
	var tiles: int = room.walking_tiles(player.global_position, global_position)
	if tiles < 0:
		return 0.0
	return tiles * Room.TILE_SIZE / player.walk_speed * walk_time_factor + walk_time_bonus


func _rerender() -> void:
	stage = Stage.NORMAL
	_armed = false
	z_index = 0
	sprite.visible = true
	sprite.texture = DOOR_TEXTURE
	sprite.offset = Vector2.ZERO
	collision.set_deferred("disabled", false)
	countdown_label.visible = false
	_update_lock_label()
	AudioManager.play("rerender")
	Narrator.say_event("door_back")


func _show_as_open_doorway() -> void:
	# Door swung open against the frame: squash it to a thin strip on the hinge side.
	collision.set_deferred("disabled", true)
	sprite.scale = Vector2(0.2, 1.0)
	sprite.position = Vector2(-13.0, 0.0)
	sprite.modulate = Color(0.8, 0.8, 0.8)


func is_passable() -> bool:
	return GameManager.has_all_keys() and (not requires_cpu_overload or stage == Stage.GONE)


func _on_exit_area_body_entered(body: Node2D) -> void:
	if _used or not body.is_in_group("player") or not is_passable():
		return
	_used = true
	EventBus.level_completed.emit()

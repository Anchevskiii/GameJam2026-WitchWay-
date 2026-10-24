class_name Dread
extends Node

## The house gets in your head. Below `heartbeat_below` sanity (or with the Stalker near)
## a heartbeat thumps, faster the worse it gets. Below `hallucinate_below` you hear whispers
## and glimpse shadow figures standing near you that vanish a moment later.
## Created by Room (one per room). Safe rooms stay calm.

const SHADOW_TEXTURE: Texture2D = preload("res://assets/sprites/characters/stalker.png")

@export var heartbeat_below: float = 45.0
@export var hallucinate_below: float = 30.0
## The Stalker counts as "close" within this many pixels.
@export var stalker_near: float = 360.0

var _beat_left: float = 1.0
var _vision_left: float = 6.0


func _process(delta: float) -> void:
	if GameManager.is_safe_room or GameManager.is_game_over or not GameManager.is_game_active:
		return
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var sanity_pct: float = GameManager.current_sanity / GameManager.max_sanity * 100.0
	var fear: float = clampf(1.0 - sanity_pct / heartbeat_below, 0.0, 1.0)
	for stalker in get_tree().get_nodes_in_group("stalker"):
		var dist: float = (stalker as Node2D).global_position.distance_to(player.global_position)
		fear = maxf(fear, clampf(1.0 - dist / stalker_near, 0.0, 1.0))

	if fear > 0.0:
		_beat_left -= delta
		if _beat_left <= 0.0:
			_beat_left = lerpf(1.3, 0.45, fear)
			AudioManager.play("heartbeat", lerpf(-16.0, 0.0, fear))

	if sanity_pct < hallucinate_below:
		_vision_left -= delta
		if _vision_left <= 0.0:
			_vision_left = randf_range(5.0, 11.0)
			_show_shadow(player)


## A dark figure standing a few steps away - gone before you can look properly.
func _show_shadow(player: Node2D) -> void:
	var shadow := Sprite2D.new()
	shadow.texture = SHADOW_TEXTURE
	shadow.offset = Vector2(0, -SHADOW_TEXTURE.get_height() * 0.5)
	shadow.modulate = Color(0, 0, 0, 0)
	shadow.global_position = player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(150.0, 230.0)
	player.get_parent().add_child(shadow)
	AudioManager.play("whisper", -6.0)
	var tween: Tween = shadow.create_tween()
	tween.tween_property(shadow, "modulate:a", 0.6, 0.25)
	tween.tween_interval(0.5)
	tween.tween_property(shadow, "modulate:a", 0.0, 0.15)
	tween.tween_callback(shadow.queue_free)

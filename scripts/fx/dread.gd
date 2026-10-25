class_name Dread
extends Node

## The house gets in your head:
##   - Random distant ambient horror sounds (a woman screaming in another room, hysterical
##     clown/evil laughter, a poltergeist sting, something haunted passing by, creaking doors,
##     ghostly whispers) played through AudioManager.play_ambient() so they NEVER overlap!
##   - Below `heartbeat_below` sanity (or with the Stalker near) a heartbeat thumps.
##   - Below `hallucinate_below` you glimpse shadow figures standing near you that vanish.
## Created by Room (one per room). Safe rooms stay calm.

const SHADOW_TEXTURE: Texture2D = preload("res://assets/sprites/characters/stalker.png")
const AMBIENT_POOL: Array[String] = [
	"woman_scream",
	"evil_laugh",
	"evil_laugh_deep",
	"poltergeist",
	"haunted_pass",
	"creak_door",
	"whisper_ghost",
	"whisper_ghost_2",
]

@export var heartbeat_below: float = 45.0
@export var hallucinate_below: float = 35.0
## The Stalker counts as "close" within this many pixels.
@export var stalker_near: float = 360.0

var _beat_left: float = 1.0
var _vision_left: float = 6.0
var _ambient_left: float = 9.0
var _last_ambient: String = ""


func _ready() -> void:
	_ambient_left = randf_range(7.0, 14.0)


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

	# Random distant horror sounds from other rooms (never overlapping thanks to play_ambient)
	_ambient_left -= delta
	if _ambient_left <= 0.0:
		var pick: String = AMBIENT_POOL[randi() % AMBIENT_POOL.size()]
		if pick == _last_ambient:
			pick = AMBIENT_POOL[randi() % AMBIENT_POOL.size()]
		var vol_db: float = randf_range(-7.5, -2.5)
		var pitch: float = randf_range(0.88, 1.08)
		if AudioManager.play_ambient(pick, vol_db, pitch):
			_last_ambient = pick
			# More frequent as sanity drops, but always with plenty of breathing room
			var min_wait: float = lerpf(8.5, 13.0, clampf(sanity_pct / 100.0, 0.0, 1.0))
			var max_wait: float = lerpf(15.0, 23.0, clampf(sanity_pct / 100.0, 0.0, 1.0))
			_ambient_left = randf_range(min_wait, max_wait)
		else:
			_ambient_left = randf_range(4.0, 7.0)

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
	var shadow_sfx: String = "haunted_pass" if randf() < 0.5 else "whisper_ghost"
	AudioManager.play_ambient(shadow_sfx, -3.5, randf_range(0.92, 1.06))
	var tween: Tween = shadow.create_tween()
	tween.tween_property(shadow, "modulate:a", 0.6, 0.25)
	tween.tween_interval(0.5)
	tween.tween_property(shadow, "modulate:a", 0.0, 0.15)
	tween.tween_callback(shadow.queue_free)

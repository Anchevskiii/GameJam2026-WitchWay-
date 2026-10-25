class_name Dread
extends Node

## The house gets in your head:
##   - Random distant muffled horror sounds from other rooms across the house:
##     `woman_scream`, `evil_laugh`, and `evil_laugh_deep` (uncut, played through the
##     MuffledRoom low-pass + reverb bus so they sound like they come through walls),
##     plus occasional creaking doors (`creak_door`) at a low frequency.
##   - Below `heartbeat_below` sanity (or with the Stalker near) a heartbeat thumps.
##   - Below `hallucinate_below` you glimpse shadow figures standing near you that vanish.
## Created by Room (one per room). Safe rooms stay calm.

const SHADOW_TEXTURE: Texture2D = preload("res://assets/sprites/characters/stalker.png")
const MUFFLED_DISTANT_POOL: Array[String] = [
	"woman_scream",
	"evil_laugh",
	"evil_laugh_deep",
]

@export var heartbeat_below: float = 45.0
@export var hallucinate_below: float = 35.0
## The Stalker counts as "close" within this many pixels.
@export var stalker_near: float = 360.0

var _beat_left: float = 1.0
var _vision_left: float = 6.0
var _distant_left: float = 14.0
var _creak_left: float = 28.0
var _last_distant: String = ""


func _ready() -> void:
	_distant_left = randf_range(12.0, 22.0)
	_creak_left = randf_range(24.0, 42.0)


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

	# Distant muffled screams & evil laughs from another room across the house (uncut, never overlapping)
	_distant_left -= delta
	if _distant_left <= 0.0:
		var pick: String = MUFFLED_DISTANT_POOL[randi() % MUFFLED_DISTANT_POOL.size()]
		if pick == _last_distant:
			pick = MUFFLED_DISTANT_POOL[randi() % MUFFLED_DISTANT_POOL.size()]
		var vol_db: float = randf_range(-4.0, 0.0)
		var pitch: float = randf_range(0.94, 1.04)
		if AudioManager.play_muffled_distant(pick, vol_db, pitch):
			_last_distant = pick
			var min_wait: float = lerpf(14.0, 22.0, clampf(sanity_pct / 100.0, 0.0, 1.0))
			var max_wait: float = lerpf(24.0, 36.0, clampf(sanity_pct / 100.0, 0.0, 1.0))
			_distant_left = randf_range(min_wait, max_wait)
		else:
			_distant_left = randf_range(6.0, 10.0)

	# Occasional creaking door in the distance (low frequency)
	_creak_left -= delta
	if _creak_left <= 0.0:
		_creak_left = randf_range(26.0, 48.0)
		AudioManager.play_muffled_distant("creak_door", randf_range(-5.0, -1.5), randf_range(0.9, 1.08))

	if sanity_pct < hallucinate_below:
		_vision_left -= delta
		if _vision_left <= 0.0:
			_vision_left = randf_range(6.0, 12.0)
			_show_shadow(player)


## A dark figure standing a few steps away - gone before you can look properly.
func _show_shadow(player: Node2D) -> void:
	var shadow := Sprite2D.new()
	shadow.texture = SHADOW_TEXTURE
	shadow.offset = Vector2(0, -SHADOW_TEXTURE.get_height() * 0.5)
	shadow.modulate = Color(0, 0, 0, 0)
	shadow.global_position = player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(150.0, 230.0)
	player.get_parent().add_child(shadow)
	var tween: Tween = shadow.create_tween()
	tween.tween_property(shadow, "modulate:a", 0.6, 0.25)
	tween.tween_interval(0.5)
	tween.tween_property(shadow, "modulate:a", 0.0, 0.15)
	tween.tween_callback(shadow.queue_free)

class_name SanityComponent
extends Node

## Player-side sanity logic. The actual value lives in GameManager (current_sanity,
## 100 = calm, 0 = pants peed). This component handles passive regeneration:
## standing still (hiding) slowly restores sanity, so the player is pulled between
## moving and hiding.
## Attached to: Player (CharacterBody2D) in scenes/actors/player.tscn

## Sanity restored per second while standing still.
@export var still_regen_rate: float = 18.0
## Regeneration multiplier while hiding in a cupboard.
@export var hidden_regen_multiplier: float = 2.0
## Seconds the player must stand still before regeneration starts.
@export var still_delay: float = 0.6
## Below this speed the player counts as "standing still".
@export var still_speed_threshold: float = 8.0

var _still_time: float = 0.0

@onready var _body: CharacterBody2D = get_parent() as CharacterBody2D


func _process(delta: float) -> void:
	if GameManager.is_game_over or _body == null:
		return
	if _body.velocity.length() < still_speed_threshold:
		_still_time += delta
		if _still_time >= still_delay and GameManager.current_sanity < GameManager.max_sanity:
			var rate: float = still_regen_rate * (hidden_regen_multiplier if _body.get("is_hidden") else 1.0)
			GameManager.restore_sanity(rate * GameManager.sanity_regen_scale * delta)
	else:
		_still_time = 0.0


## Kept for older callers: a positive amount is fear (sanity lost).
func apply_sanity_change(amount: float, source_name: String = "") -> void:
	if amount > 0.0:
		GameManager.scare_player(amount, source_name)
	else:
		GameManager.restore_sanity(-amount)

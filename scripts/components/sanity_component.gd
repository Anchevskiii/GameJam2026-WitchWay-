class_name SanityComponent
extends Node

## Manages player fear, panic accumulation, and passive recovery
## Attached to: Player (CharacterBody2D) in scenes/actors/player.tscn

@export var max_sanity: float = 100.0
@export var passive_calm_rate: float = 1.5
@export var enable_passive_recovery: bool = true

var current_sanity: float = 0.0
var _is_panicking: bool = false

func _ready() -> void:
	current_sanity = 0.0
	EventBus.sanity_changed.emit(current_sanity, max_sanity)

func _process(delta: float) -> void:
	if enable_passive_recovery and current_sanity > 0.0 and not GameManager.is_game_over:
		apply_sanity_change(-passive_calm_rate * delta)

func apply_sanity_change(amount: float, source_name: String = "") -> void:
	if GameManager.is_game_over:
		return
	
	current_sanity = clampf(current_sanity + amount, 0.0, max_sanity)
	GameManager.current_sanity = current_sanity
	EventBus.sanity_changed.emit(current_sanity, max_sanity)
	
	if amount > 0.0 and source_name != "":
		EventBus.player_scared.emit(amount, source_name)
	
	if current_sanity >= max_sanity and not GameManager.is_game_over:
		GameManager.trigger_game_over()

func reset_sanity() -> void:
	current_sanity = 0.0
	GameManager.current_sanity = 0.0
	EventBus.sanity_changed.emit(current_sanity, max_sanity)

class_name ScareSource
extends Area2D

## Emits fear to the player upon contact or continuous proximity
## Attach to: Monsters, traps, spooky furniture, or jump-scare zones

@export var source_name: String = "Spooky Presence"
@export var instant_scare_amount: float = 15.0
@export var is_continuous: bool = true
@export var continuous_scare_rate: float = 12.0

var _player_in_range: CharacterBody2D = null
var _sanity_component: SanityComponent = null

func _ready() -> void:
	collision_layer = 4 # Hazard/Trigger layer
	collision_mask = 2  # Player layer
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if is_continuous and _player_in_range and _sanity_component:
		_sanity_component.apply_sanity_change(continuous_scare_rate * delta, source_name)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_in_range = body as CharacterBody2D
		_sanity_component = body.get_node_or_null("SanityComponent") as SanityComponent
		
		if instant_scare_amount > 0.0:
			if _sanity_component:
				_sanity_component.apply_sanity_change(instant_scare_amount, source_name)
			else:
				GameManager.add_sanity(instant_scare_amount, source_name)

func _on_body_exited(body: Node2D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		_sanity_component = null

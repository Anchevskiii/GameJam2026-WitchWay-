extends Node

## Simple interaction logic for searching the wardrobe in the tutorial room
## Attached to: Props/Wardrobe in scenes/levels/tutorial_room.tscn

@onready var interactable: Interactable = $Interactable

var _is_opened: bool = false

func _ready() -> void:
	if interactable:
		interactable.interacted.connect(_on_interacted)

func _on_interacted(_player: CharacterBody2D) -> void:
	if not _is_opened:
		_is_opened = true
		interactable.set_prompt("Wardrobe is empty (only cobwebs).")
		EventBus.item_collected.emit("Rusted Key")

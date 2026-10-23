extends Node

## Central Event Bus for decoupled communication between game systems
## Attached as Autoload singleton: EventBus

# Sanity & Player State signals
signal sanity_changed(current: float, max_sanity: float)
signal player_scared(amount: float, source_name: String)
signal game_over_triggered()

# CPU Overload / Glitch mode signals
signal cpu_overload_changed(current: float, max_val: float)
signal glitch_mode_toggled(is_active: bool)

# Bug mechanic signals
signal bug_triggered(bug_type: String)

# Item and progression signals
signal item_collected(item_name: String)
signal level_completed()
signal checkpoint_saved()

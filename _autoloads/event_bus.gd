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
## Emitted by LagController when the world picture freezes (true) and resumes (false).
signal lag_freeze_changed(is_frozen: bool)

# Bug mechanic signals
signal bug_triggered(bug_type: String)

# Player scare: the masked BOO. Only works on monsters that don't see it coming
# (from behind, around a corner) - or on anyone when jumping out of a hiding spot.
signal player_booed(origin: Vector2, boo_range: float, from_hiding: bool)
signal npc_scared(npc_name: String)
signal kid_scared(times: int, max_times: int)
signal prop_spawned(prop_name: String, load_weight: float)

# Narrator ("Haunted House Management") text box. Empty text = hide the box.
signal narrator_line_changed(text: String)

# Rooms
signal room_entered(room_title: String, objective: String)
## Ask Main to swap the current room. Path to a .tscn file.
signal room_change_requested(scene_path: String)

# Item and progression signals
signal item_collected(item_name: String)
signal key_collected()
signal level_completed()
signal checkpoint_saved()

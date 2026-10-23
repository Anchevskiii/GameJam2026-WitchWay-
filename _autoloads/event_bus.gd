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

# Player scare tool: the rubber chicken honk.
## origin/direction in world space; NPCs check if they are inside the cone.
signal player_honked(origin: Vector2, direction: Vector2, honk_range: float, half_angle_deg: float)
signal npc_scared(npc_name: String)
signal prop_spawned(prop_name: String, load_weight: float)

# Narrator ("Haunted House Management") text box. Empty text = hide the box.
signal narrator_line_changed(text: String)

# Rooms
signal room_entered(room_title: String, objective: String)
## Ask Main to swap the current room. Path to a .tscn file.
signal room_change_requested(scene_path: String)

# Item and progression signals
signal item_collected(item_name: String)
signal level_completed()
signal checkpoint_saved()

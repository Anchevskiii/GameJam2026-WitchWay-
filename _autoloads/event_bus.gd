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
signal level_completed()

# Haunted house signals (traps, jumpscares, the escape)
## Something loud happened (creaky board, snapping trap): monsters within `radius` come to look.
signal noise_made(position: Vector2, radius: float)
## Show a full-screen jumpscare. `face` = file name in assets/sprites/ui/ (jumpscare_<face>.png).
signal jumpscare_requested(face: String, damage: float)
signal keys_changed(found: int, needed: int)
## The last key was taken: the house wakes up and the Stalker comes for you.
signal house_awakened()
signal checkpoint_saved()

extends Node

## Manages core game state: Sanity (player "health") and the fake CPU load meter.
## Attached as Autoload singleton: GameManager
##
## Sanity: starts full (100) and drains when the player gets scared. At 0 the player
## pees their pants (game over). Regenerates slowly while standing still (see SanityComponent).
## GLITCH meter (current_cpu_overload, shown as "GLITCH" in the HUD): scaring things makes the
## house glitch. Every scare adds glitch (shown as "+N GLITCH" where it happened). It holds for
## a few seconds, then drains - so chain scares quickly. At 100% the house crashes: the
## exit door on OVERLOAD floors fails to render, and the screen glitches hardest.

@export var max_sanity: float = 100.0
@export var max_cpu_overload: float = 100.0
## How fast the glitch meter drains per second once it starts draining.
@export var cpu_decay_rate: float = 6.0
## Seconds the meter holds after the last gain before it starts draining.
@export var glitch_hold_time: float = 2.5

@export_group("Glitch Display")
## The GLITCH bar never reads 0: the house is always a little broken.
@export var min_glitch_display: float = 10.0
## The GLITCH bar moves in steps of this many percent.
@export var glitch_display_step: float = 5.0

@export_group("Difficulty")
## Every monster's wind-up is multiplied by this (lower = they scare you faster).
@export var monster_windup_scale: float = 0.7
## Every monster sees this much further than its NpcData says.
@export var monster_sight_scale: float = 1.25

## Endless run: level 0, 3, 6, ... are the Living Room (safe room + checkpoint).
## Levels 1 and 2 are the hand-made Dark Hallway and Dining Room; every other level is generated.
const LIVING_ROOM_EVERY: int = 3
const LIVING_ROOM_SCENE: String = "res://scenes/levels/living_room.tscn"
const HANDMADE_LEVELS: Dictionary = {
	1: "res://scenes/levels/dark_hallway.tscn",
	2: "res://scenes/levels/dining_room.tscn",
}
const GENERATED_SCENE: String = "res://scenes/levels/generated_room.tscn"

var current_level: int = 0
## The last Living Room reached. Dying sends the player back here.
var checkpoint_level: int = 0
var best_level: int = 0
var current_sanity: float = 100.0
var current_cpu_overload: float = 0.0
var is_glitch_mode: bool = false
var is_game_over: bool = false
var is_game_active: bool = false

## Set by the current Room. Safe rooms (Living Room) ignore scares and keep sanity full.
var is_safe_room: bool = false
## Set by the current Room. Multiplies every prop's load weight ("this room is unoptimized").
var cpu_load_multiplier: float = 1.0
## Set by the current Room. Deeper floors restore sanity more slowly.
var sanity_regen_scale: float = 1.0
## Keys the exit needs on this floor (set by the Room; 0 = the exit isn't locked) and keys found.
var keys_needed: int = 0
var keys_found: int = 0

# Run statistics, shown on the game over screen.
var stats_npcs_scared: int = 0
var stats_props_spawned: int = 0
var stats_times_peed: int = 0
var stats_kids_peed: int = 0

var _time_since_glitch_gain: float = 999.0

var _low_sanity_warned: bool = false

# ---------------------------------------------------------------- candy economy & shop
signal candy_changed(amount: int)
signal inventory_changed

## Candy = global currency for the run (kept between floors, spent at the Merchant / vending machines).
var candy: int = 0
## Upgrade levels bought at the Living Room Merchant.
var sanity_resist_level: int = 0   ## each level: monsters scare 10% less
var search_speed_level: int = 0    ## each level: searching is faster
var candy_sanity_level: int = 0    ## sanity gained per candy = 1 + level (max +10)
## Consumables / timed items.
var mask_owned: bool = false          ## one spare mask at a time; lost when entering the next Living Room
var glitch_charges: int = 0           ## Q: crash the house on demand
var flashlight_floors: int = 0        ## floors the flashlight still works for
var glitch_buys: int = 0
var glitch_power_active: bool = false
## Set by the Room: the exit door needs a crash (OVERLOAD floor).
var exit_needs_crash: bool = false
## World rectangle of this floor's vending-machine room (monsters stay out). Rect2() if none.
var shop_zone: Rect2 = Rect2()
## Ticks (ms) before which a shop can't be re-opened (stops E re-opening the shop that E just closed).
var shop_block_until: int = 0

const MAX_SANITY_RESIST: int = 5
const MAX_SEARCH_SPEED: int = 5
const MAX_CANDY_SANITY: int = 9
const SANITY_RESIST_PRICES: Array[int] = [6, 12, 20, 30, 42]
const SEARCH_SPEED_PRICES: Array[int] = [4, 8, 14, 22, 32]
const MASK_PRICE: int = 5
const FLASHLIGHT_PRICE: int = 8
const FLASHLIGHT_FLOORS: int = 2
const GLITCH_BASE_PRICE: int = 14
const GLITCH_PRICE_STEP: int = 4
const MASK_DURATION: float = 10.0
## Vending machines sell a few items at a higher price.
const VENDING_MARKUP: float = 1.35


func _ready() -> void:
	is_game_active = false
	_ensure_action("use_mask", KEY_F)
	_ensure_action("glitch_power", KEY_Q)
	reset_level_state()


func _ensure_action(action: StringName, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


func add_candy(amount: int = 1) -> void:
	candy = maxi(0, candy + amount)
	candy_changed.emit(candy)


## Sanity restored by every candy picked up: +1 at the start, up to +10 with upgrades.
func candy_sanity_amount() -> float:
	return 1.0 + float(candy_sanity_level)


func sanity_resist_multiplier() -> float:
	return 1.0 - 0.1 * float(sanity_resist_level)


## Searching speed: slow at first, much faster fully upgraded (multiplies Searchable.search_time).
func search_time_scale() -> float:
	return 1.7 - 0.22 * float(search_speed_level)


## Candy drops grow with difficulty: floors in the first Living Room cycle give the least.
func candy_drop_count(base: int) -> int:
	return base + difficulty_tier() / 2


func has_flashlight() -> bool:
	return flashlight_floors > 0


func reset_economy() -> void:
	candy = 0
	sanity_resist_level = 0
	search_speed_level = 0
	candy_sanity_level = 0
	mask_owned = false
	glitch_charges = 0
	glitch_buys = 0
	flashlight_floors = 0
	glitch_power_active = false
	candy_changed.emit(candy)
	inventory_changed.emit()


## The previous mask doesn't survive into the next Living Room - buy a fresh one.
func on_enter_living_room() -> void:
	if mask_owned:
		mask_owned = false
		inventory_changed.emit()


## Called when the player leaves a haunted floor through the exit: the flashlight wears out.
func on_floor_completed() -> void:
	if is_safe_room or flashlight_floors <= 0:
		return
	flashlight_floors -= 1
	inventory_changed.emit()
	if flashlight_floors <= 0:
		Narrator.say("The flashlight battery is dead. You're on your own in the dark.")


## Items for the Merchant ("main") or a floor vending machine ("vending").
## Each entry: {id, name, desc, price, available, reason}
func shop_items(mode: String) -> Array:
	var items: Array = []
	var markup: float = VENDING_MARKUP if mode == "vending" else 1.0
	items.append(_item("flashlight", "Flashlight", "Works for %d floors. Shows what lurks in the dark." % FLASHLIGHT_FLOORS,
			FLASHLIGHT_PRICE, markup, flashlight_floors <= 0, "Already have one (%d floors left)" % flashlight_floors))
	items.append(_item("mask", "Mask [F]", "Wear it to be ignored. One at a time; it expires in the next Living Room.",
			MASK_PRICE, markup, not mask_owned, "You already carry a mask"))
	var glitch_price: int = GLITCH_BASE_PRICE + GLITCH_PRICE_STEP * glitch_buys
	items.append(_item("glitch", "Glitch Mode [Q]", "Crash the house on demand (brief). You still need all keys.",
			glitch_price, markup, glitch_charges <= 0, "You already hold a charge"))
	if mode == "main":
		items.append(_leveled("sanity_resist", "Thick Skin", "Monsters scare you 10%% less (now -%d%%)." % (sanity_resist_level * 10),
				SANITY_RESIST_PRICES, sanity_resist_level, MAX_SANITY_RESIST))
		items.append(_leveled("search", "Quick Fingers", "Search drawers faster (level %d/%d)." % [search_speed_level, MAX_SEARCH_SPEED],
				SEARCH_SPEED_PRICES, search_speed_level, MAX_SEARCH_SPEED))
		var candy_price: int = candy_sanity_level * (candy_sanity_level + 1) + 1
		var maxed: bool = candy_sanity_level >= MAX_CANDY_SANITY
		items.append({"id": "candy_sanity", "name": "Sugar Rush", "desc": "Each candy restores +%d sanity (max +10)." % int(candy_sanity_amount()),
				"price": candy_price, "available": not maxed, "reason": "Maxed out"})
	return items


func _item(id: String, item_name: String, desc: String, base_price: int, markup: float, available: bool, reason: String) -> Dictionary:
	return {"id": id, "name": item_name, "desc": desc, "price": ceili(base_price * markup), "available": available, "reason": reason}


func _leveled(id: String, item_name: String, desc: String, prices: Array[int], level: int, max_level: int) -> Dictionary:
	var maxed: bool = level >= max_level
	return {"id": id, "name": item_name, "desc": desc, "price": prices[mini(level, max_level - 1)], "available": not maxed, "reason": "Maxed out"}


## Tries to buy an item. Returns an error text, or "" on success.
func buy(id: String, mode: String) -> String:
	for entry in shop_items(mode):
		if entry["id"] != id:
			continue
		if not entry["available"]:
			return String(entry["reason"])
		var price: int = entry["price"]
		if candy < price:
			return "Not enough candy (%d needed)" % price
		add_candy(-price)
		match id:
			"flashlight":
				flashlight_floors = FLASHLIGHT_FLOORS
				get_tree().call_group("player", "set_flashlight_available", true)
			"mask":
				mask_owned = true
			"glitch":
				glitch_charges = 1
				glitch_buys += 1
			"sanity_resist":
				sanity_resist_level += 1
			"search":
				search_speed_level += 1
			"candy_sanity":
				candy_sanity_level += 1
		inventory_changed.emit()
		return ""
	return "Unknown item"


## Q: spend the glitch charge to crash the house right now (opens an OVERLOAD exit if all keys are found).
func use_glitch_power() -> void:
	if glitch_charges <= 0 or is_game_over or is_safe_room:
		return
	if not exit_needs_crash:
		Narrator.say("Nothing to crash here. Save the charge.")
		return
	if not has_all_keys():
		Narrator.say_now("The exit is still locked. Find every key first.")
		return
	glitch_charges -= 1
	glitch_power_active = true
	inventory_changed.emit()
	AudioManager.play("glitch")
	_time_since_glitch_gain = 0.0
	_set_cpu_load(max_cpu_overload)


func _process(delta: float) -> void:
	if is_game_over or not is_game_active:
		return
	_time_since_glitch_gain += delta
	if current_cpu_overload > 0.0 and _time_since_glitch_gain >= glitch_hold_time:
		_set_cpu_load(current_cpu_overload - cpu_decay_rate * delta)


## Adds glitch (a prop was spawned, something got scared). The room multiplier is applied here.
func add_cpu_load(amount: float) -> void:
	if is_game_over:
		return
	_time_since_glitch_gain = 0.0
	_set_cpu_load(current_cpu_overload + amount * cpu_load_multiplier)


func _set_cpu_load(value: float) -> void:
	current_cpu_overload = clampf(value, 0.0, max_cpu_overload)
	EventBus.cpu_overload_changed.emit(current_cpu_overload, max_cpu_overload)
	var glitch_now: bool = current_cpu_overload >= max_cpu_overload
	if glitch_now != is_glitch_mode:
		is_glitch_mode = glitch_now
		if not glitch_now:
			glitch_power_active = false
		EventBus.glitch_mode_toggled.emit(is_glitch_mode)
		if is_glitch_mode:
			Narrator.say_event("glitch_crash")


## Removes sanity. Call this whenever something scares the player.
func scare_player(amount: float, source_name: String = "") -> void:
	if is_game_over or is_safe_room or amount <= 0.0:
		return
	amount *= sanity_resist_multiplier()
	current_sanity = clampf(current_sanity - amount, 0.0, max_sanity)
	EventBus.sanity_changed.emit(current_sanity, max_sanity)
	EventBus.player_scared.emit(amount, source_name)

	if current_sanity <= max_sanity * 0.25 and not _low_sanity_warned:
		_low_sanity_warned = true
		Narrator.say_event("low_sanity")
	if current_sanity <= 0.0:
		trigger_game_over()


func restore_sanity(amount: float) -> void:
	if is_game_over:
		return
	current_sanity = clampf(current_sanity + amount, 0.0, max_sanity)
	if current_sanity > max_sanity * 0.4:
		_low_sanity_warned = false
	EventBus.sanity_changed.emit(current_sanity, max_sanity)


func refill_sanity() -> void:
	restore_sanity(max_sanity)


func set_keys_needed(count: int) -> void:
	keys_needed = count
	keys_found = 0
	EventBus.keys_changed.emit(keys_found, keys_needed)


## A key was found. The last one wakes the house up.
func add_key() -> void:
	if keys_found >= keys_needed:
		return
	keys_found += 1
	EventBus.keys_changed.emit(keys_found, keys_needed)
	if keys_found == keys_needed:
		EventBus.house_awakened.emit()


func has_all_keys() -> bool:
	return keys_found >= keys_needed


func trigger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	stats_times_peed += 1
	EventBus.game_over_triggered.emit()


## Called on game start, retry, and when a new room is entered.
func reset_level_state() -> void:
	current_sanity = max_sanity
	current_cpu_overload = 0.0
	is_glitch_mode = false
	is_game_over = false
	is_game_active = true
	_low_sanity_warned = false
	EventBus.sanity_changed.emit(current_sanity, max_sanity)
	EventBus.cpu_overload_changed.emit(current_cpu_overload, max_cpu_overload)
	EventBus.glitch_mode_toggled.emit(false)


func is_safe_level(level: int) -> bool:
	return level % LIVING_ROOM_EVERY == 0


func scene_for_level(level: int) -> String:
	if is_safe_level(level):
		return LIVING_ROOM_SCENE
	return HANDMADE_LEVELS.get(level, GENERATED_SCENE)


## 0 for the first loop, then 1, 2, 3... Generated rooms get bigger and meaner with it.
func difficulty_tier(level: int = current_level) -> int:
	return level / LIVING_ROOM_EVERY


## Floors are numbered without counting Living Rooms: LR, Floor 1, Floor 2, LR, Floor 3, ...
func floor_number(level: int = current_level) -> int:
	return level - level / LIVING_ROOM_EVERY


func floor_title(room_title: String, level: int = current_level) -> String:
	if is_safe_level(level):
		return room_title
	return "Floor %d: %s" % [floor_number(level), room_title]


## New Game: start the endless run from floor 1.
func start_new_run() -> void:
	start_from_checkpoint(0)
	reset_economy()
	stats_npcs_scared = 0
	stats_props_spawned = 0
	stats_times_peed = 0
	stats_kids_peed = 0


## Continue: resume at a saved Living Room (any level is rounded down to the last Living Room).
func start_from_checkpoint(level: int) -> void:
	checkpoint_level = maxi(level - level % LIVING_ROOM_EVERY, 0)
	current_level = checkpoint_level
	best_level = maxi(best_level, checkpoint_level)
	reset_level_state()


## Called when the player walks out of a room's exit door.
func advance_level() -> void:
	current_level += 1
	best_level = maxi(best_level, current_level)
	if is_safe_level(current_level):
		checkpoint_level = current_level


## Only clears the CPU meter (used when walking into a new room; sanity carries over).
func reset_cpu_load() -> void:
	_set_cpu_load(0.0)


## The GLITCH bar value, and the screen glitch strength, are driven by this.
## The real meter is rounded up in steps (so the bar never sits on 0), but it only
## reaches 100% when the house actually crashes.
func glitch_level() -> float:
	var pct: float = current_cpu_overload / maxf(max_cpu_overload, 1.0) * 100.0
	var step: float = maxf(glitch_display_step, 0.1)
	var stepped: float = ceilf(pct / step) * step
	if pct < 100.0:
		stepped = minf(stepped, 100.0 - step)
	return clampf(maxf(stepped, min_glitch_display), min_glitch_display, 100.0)

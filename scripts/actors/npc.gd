class_name Npc
extends CharacterBody2D

## A haunted-house resident that tries to scare the player - and can be scared first.
## Attached to: CharacterBody2D root of scenes/actors/npc.tscn. Configure via `data` (NpcData).
##
## Stealth scare duel:
##   IDLE          wanders and looks around. It SEES the player (or a kid) only inside its view cone
##                 (yellow), with no walls/furniture in between, and never while they hide or wear a mask.
##                 Spotting the player or a trick-or-treating kid -> WINDUP
##   CORNER_LURK   stands completely still in a dark corner/spot waiting for the player to approach.
##   WINDUP        visible tell (grows, glows red, "BOO" bubble) while CHASING the target. If it
##                 completes in range (and the player isn't hidden/masked), the target gets scared -> COOLDOWN
##   HIDING        (hides_in_furniture) sits in a cupboard, head peeking out now and then.
##                 Player gets close -> jumps out with a short wind-up. BOO the cupboard first
##                 and the surprise is on it.
##   PANIC         the player surprised it (BOO from behind / jumped out of hiding / masked)! Drops loot,
##                 screams (nearby NPCs panic too) and runs around bumping into others
##   DONE          DISABLED: greyed out and glitching with a countdown. Recovers after a while -> IDLE
## A BOO it can see coming does nothing (unless masked). Wind-ups pause while LagController.is_frozen.

enum State { IDLE, WINDUP, COOLDOWN, PANIC, DONE, HIDING, CORNER_LURK }

const MISSING_TEXTURE: Texture2D = preload("res://assets/sprites/environment/missing_texture.png")
## Panicking NPCs scare other NPCs within this distance.
const BUMP_RADIUS: float = 34.0
## The NPC notices a player bumping right into it, even from behind.
const TOUCH_SENSE: float = 20.0
const CONE_COLOR: Color = Color(1.0, 0.9, 0.5, 0.07)
const CONE_ALERT_COLOR: Color = Color(1.0, 0.25, 0.2, 0.16)
const CONE_RAYS: int = 12

@export var data: NpcData
## Darkness rooms: > 0 means the NPC is "not loaded" (invisible, then a missing-texture
## placeholder) until the player comes within this many pixels. Set by the Room.
@export var load_in_radius: float = 0.0
## Multiplies data.wander_radius. 0 = stays in its spot (seated dinner guests). Set by the Room.
@export var wander_scale: float = 1.0
## Set by the Room: false keeps would-be hiders out of the furniture (seated dinner guests).
@export var can_hide: bool = true
## Set by the Room: false = it winds up where it stands instead of chasing (seated dinner guests).
@export var can_chase: bool = true
## Difficulty, set by the Room: < 1 = faster wind-ups, > 1 = scarier scares.
@export var windup_scale: float = 1.0
@export var damage_scale: float = 1.0
## Difficulty, set by the Room: deeper floors = faster monsters that see further.
@export var speed_scale: float = 1.0
@export var sight_scale: float = 1.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var bubble: Label = $Bubble
@onready var status_bar: ProgressBar = get_node_or_null("StatusProgress")
@onready var windup_light: PointLight2D = $WindupLight
@onready var stumble: StumbleAnimator = $StumbleAnimator
@onready var body_shape: CollisionShape2D = $CollisionShape2D

var state: State = State.IDLE

var _player: Node2D = null
var _home: Vector2
var _state_time: float = 0.0
var _wander_target: Vector2
var _wander_time: float = 0.0
## Heading to a noise it heard (walks there faster than a wander).
var _investigating: bool = false
var _panic_dir: Vector2 = Vector2.RIGHT
var _panic_turn_time: float = 0.0
var _anim_time: float = 0.0
var _frame: int = 0
## Which way it looks: 1 = right, -1 = left.
var _facing: float = 1.0
var _look_timer: float = 0.0
var _view_cone: Polygon2D = null
## Hiding: the spot it walks to / sits in, and time since it last hid.
var _hide_spot: HideSpot = null
var _hide_walk_time: float = 0.0
var _time_since_hide: float = 0.0
## Duration of current COOLDOWN state (longer after scaring the player so packs don't spam).
var _cooldown_duration: float = 5.0
## Shorter wind-up used right after jumping out of a hiding spot or corner ambush.
var _ambush_windup: bool = false
## Who the current wind-up is aimed at: the player or a Kid.
var _target: Node2D = null
## Ghost phasing mechanics:
var _ghost_phase_timer: float = 0.0
var _is_phased: bool = false
var _unshaded_mat: CanvasItemMaterial = null
var _disappearing: bool = false


func _ready() -> void:
	add_to_group("npcs")
	_home = global_position
	_wander_target = _home
	_unshaded_mat = CanvasItemMaterial.new()
	_unshaded_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	if bubble:
		bubble.visible = false
		bubble.material = _unshaded_mat
		bubble.add_theme_font_size_override("font_size", 13)
	windup_light.enabled = false
	if data == null:
		push_error("Npc %s has no NpcData." % name)
		set_physics_process(false)
		return
	if data.is_ghost or data.can_pass_walls:
		collision_mask = 0
		add_to_group("ghosts")
	_reset_visuals()
	_facing = 1.0 if randf() > 0.5 else -1.0
	_look_timer = randf_range(data.look_around_min, data.look_around_max)
	_build_view_cone()
	EventBus.player_booed.connect(_on_player_booed)
	EventBus.noise_made.connect(_on_noise_made)


func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if GameManager.is_game_over:
		velocity = Vector2.ZERO
		return

	_animate(delta)
	_update_loaded_look()
	_update_view_cone()
	_update_ghost_phase(delta)
	_state_time += delta
	_time_since_hide += delta
	match state:
		State.IDLE:
			_process_idle(delta)
		State.WINDUP:
			_process_windup(delta)
		State.COOLDOWN:
			# Cooldown pauses/holds while the player stands right next to the entity
			if _player != null and not _player.get("is_hidden") and global_position.distance_to(_player.global_position) < 95.0:
				_state_time = minf(_state_time, _cooldown_duration - 1.2)
				if data.can_move:
					velocity = (_player.global_position.direction_to(global_position)) * data.move_speed * 0.65
				else:
					velocity = Vector2.ZERO
			else:
				velocity = Vector2.ZERO
			if status_bar:
				status_bar.visible = true
				status_bar.max_value = _cooldown_duration
				status_bar.value = maxf(0.0, _cooldown_duration - _state_time)
				status_bar.modulate = Color(0.4, 0.8, 1.0)
			if _state_time >= _cooldown_duration:
				_relocate_and_reset()
		State.PANIC:
			_process_panic(delta)
		State.DONE:
			velocity = Vector2.ZERO
			if status_bar:
				status_bar.visible = true
				status_bar.max_value = data.recover_time
				status_bar.value = maxf(0.0, data.recover_time - _state_time)
				status_bar.modulate = Color(0.8, 0.4, 1.0)
			sprite.visible = true
			if _state_time >= data.recover_time:
				_recover()
		State.HIDING:
			_process_hiding()
			return  # sitting still inside the furniture: no physics movement
		State.CORNER_LURK:
			_process_corner_lurk()
	move_and_slide()


func _update_ghost_phase(delta: float) -> void:
	if not (data.is_ghost or data.can_pass_walls) or state == State.DONE or state == State.HIDING:
		return
	_ghost_phase_timer += delta
	if _ghost_phase_timer >= 4.0:
		_ghost_phase_timer = 0.0
		_is_phased = not _is_phased
		var target_alpha: float = 0.25 if _is_phased else 0.92
		create_tween().tween_property(sprite, "modulate:a", target_alpha, 0.7)


# ---------------------------------------------------------------- states

func _process_idle(delta: float) -> void:
	var target: Node2D = _find_visible_target()
	var sees_player: bool = target != null and target == _player

	if data.afraid_of_player and sees_player:
		var away: Vector2 = (global_position - _player.global_position).normalized()
		velocity = away * data.move_speed * speed_scale * 1.4
	elif _hide_spot != null:
		_walk_to_hiding_spot(delta)
	elif data.can_move:
		_wander_time -= delta
		if global_position.distance_to(_wander_target) < 6.0 or _wander_time <= 0.0:
			_pick_wander_target()
		velocity = global_position.direction_to(_wander_target) * data.move_speed * speed_scale * (1.1 if _investigating else 0.45)
	else:
		velocity = Vector2.ZERO

	# Face where it walks; when standing still, glance the other way now and then.
	if absf(velocity.x) > 5.0:
		_facing = signf(velocity.x)
	else:
		_look_timer -= delta
		if _look_timer <= 0.0:
			_facing = -_facing
			_look_timer = randf_range(data.look_around_min, data.look_around_max)

	if target != null and _can_start_windup():
		_give_up_hiding_spot()
		_target = target
		_enter(State.WINDUP)
	elif data.hides_in_corners and can_hide and not _investigating and randf() < 0.012 and target == null and _time_since_hide >= data.hide_cooldown:
		_enter(State.CORNER_LURK)
	elif _wants_to_hide() and target == null:
		_hide_spot = _find_hiding_spot()
		if _hide_spot:
			_hide_spot.reserved_by = self
			_hide_walk_time = 0.0
		else:
			_time_since_hide = 0.0  # nothing free nearby: look again after the cooldown


func _process_corner_lurk() -> void:
	velocity = Vector2.ZERO
	if _player == null:
		return
	var player_masked_or_hidden: bool = _player.get("is_masked") or _player.get("is_hidden")
	if not player_masked_or_hidden and can_see_player():
		_ambush_windup = true
		_target = _player
		_enter(State.WINDUP)
		face_towards(_player.global_position)
	elif _state_time >= data.hide_time:
		_time_since_hide = 0.0
		_enter(State.IDLE)


func _process_windup(delta: float) -> void:
	velocity = Vector2.ZERO
	if not is_instance_valid(_target) or (_target is Kid and not (_target as Kid).is_scareable()) or (_target == _player and _player.get("is_masked")):
		_enter(State.COOLDOWN)
		return
	face_towards(_target.global_position)
	var to_target: Vector2 = _target.global_position - global_position
	var chase_speed: float = (data.rush_speed if data.rush_speed > 0.0 and _ambush_windup else data.move_speed * 1.15) * speed_scale
	if data.can_move and can_chase and to_target.length() > 28.0 and not LagController.is_frozen:
		velocity = to_target.normalized() * chase_speed
	# Lag freeze = wind-up pauses. That's the dodge window.
	if LagController.is_frozen:
		_state_time -= delta
	var progress: float = clampf(_state_time / _windup_time(), 0.0, 1.0)

	# Alert tell: puffs up slightly, glows red, and shows only a clean "!" alert indicator.
	sprite.scale = Vector2.ONE * data.sprite_scale * (1.0 + 0.30 * progress)
	sprite.modulate = data.tint.lerp(Color(1.0, 0.42, 0.42), progress)
	windup_light.energy = 0.5 + 1.4 * progress
	bubble.text = "!"
	bubble.scale = Vector2.ONE

	if to_target.length() > _sight() * 1.65:
		_enter(State.COOLDOWN)
		return
	if progress >= 1.0 or (to_target.length() <= 38.0 and _state_time >= 0.15):
		_release_scare()


func _release_scare() -> void:
	bubble.scale = Vector2.ONE
	_cooldown_duration = 5.0
	if _target == _player and (_player.get("is_hidden") or _player.get("is_masked")):
		bubble.text = "?"  # the player ducked into a hiding spot or put on a mask - miss!
		_enter(State.COOLDOWN)
		return
	var in_range: bool = is_instance_valid(_target) and global_position.distance_to(_target.global_position) <= data.scare_range * 1.15
	if in_range and _target == _player:
		_cooldown_duration = 5.0
		var is_ambush: bool = _ambush_windup
		if _player and _player.has_method("is_facing_target") and _player.is_facing_target(global_position):
			is_ambush = false
		var scare_sfx: String = "jumpscare_hit" if randf() < 0.45 else "scream"
		AudioManager.play_scare(scare_sfx, -2.5, randf_range(0.95, 1.05))
		var dmg: float = (data.ambush_damage if is_ambush else data.scare_damage) * damage_scale
		GameManager.scare_player(dmg, data.display_name)
		# Wardrobe/hiding ambushers play jump-scare animation, vanish into walls and relocate into another wardrobe!
		if is_ambush and data.hides_in_furniture:
			_vanish_and_respawn_cupboard()
			return
	elif in_range and _target is Kid:
		(_target as Kid).get_scared(global_position, "a " + data.display_name)
	_enter(State.COOLDOWN)


## When jumping out of a wardrobe, scare the player, vanish into the wall, and respawn in another wardrobe!
func _vanish_and_respawn_cupboard() -> void:
	if _disappearing:
		return
	_disappearing = true
	velocity = Vector2.ZERO
	bubble.visible = false
	if status_bar:
		status_bar.visible = false
	var tween: Tween = create_tween()
	var wall_dir: Vector2 = Vector2.UP.rotated(randf_range(-0.5, 0.5))
	tween.parallel().tween_property(self, "global_position", global_position + wall_dir * 36.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.45)
	tween.parallel().tween_property(sprite, "scale", Vector2.ZERO, 0.45)
	tween.tween_callback(func() -> void:
		_disappearing = false
		_ambush_windup = false
		_reset_visuals()
		# Find a free wardrobe / hiding spot in this room
		var free_spots: Array[HideSpot] = []
		for node in get_tree().get_nodes_in_group("hide_spots"):
			var spot: HideSpot = node as HideSpot
			if is_instance_valid(spot) and spot.is_free_for(self):
				free_spots.append(spot)
		if not free_spots.is_empty():
			var new_spot: HideSpot = free_spots[randi() % free_spots.size()]
			_hide_spot = new_spot
			_enter_hiding_spot()
		else:
			_relocate_and_reset()
	)


func _process_panic(delta: float) -> void:
	_panic_turn_time -= delta
	if _panic_turn_time <= 0.0 or is_on_wall():
		_panic_dir = Vector2.RIGHT.rotated(randf() * TAU)
		_panic_turn_time = randf_range(0.25, 0.5)
	velocity = _panic_dir * data.panic_speed
	_facing = signf(velocity.x) if velocity.x != 0.0 else _facing

	# Chain reaction: bump into other NPCs and scare them too.
	for other in get_tree().get_nodes_in_group("npcs"):
		if other != self and global_position.distance_to(other.global_position) < BUMP_RADIUS:
			(other as Npc).get_scared("a panicking " + data.display_name)
	for kid in get_tree().get_nodes_in_group("kids"):
		if global_position.distance_to((kid as Node2D).global_position) < BUMP_RADIUS:
			(kid as Kid).get_scared(global_position, "a panicking " + data.display_name)

	if _state_time >= data.panic_time:
		_enter(State.DONE)
		_apply_after_scare()


# ---------------------------------------------------------------- scare duel API

## Scare this NPC (player's BOO, flying prop, panicking friend). Returns true if it worked.
func get_scared(_by: String = "") -> bool:
	if state == State.PANIC or state == State.DONE:
		return false
	if state == State.HIDING:
		_leave_hiding_spot(Vector2.RIGHT.rotated(randf() * TAU))
	_give_up_hiding_spot()
	_enter(State.PANIC)
	_reset_visuals()
	bubble.visible = true
	bubble.text = "!!"
	AudioManager.play("npc_yelp", -2.0, randf_range(0.85, 1.25))
	_drop_loot()
	var glitch: float = 0.0
	for prop in data.loot:
		glitch += prop.load_weight
	FloatingText.spawn(self, global_position, "+%d GLITCH" % roundi(glitch * GameManager.cpu_load_multiplier), Color(1.0, 0.35, 0.9))
	if data.scream_radius > 0.0:
		# Who hears the scream is decided NOW (where it happened); they react a moment later.
		get_tree().create_timer(data.scream_delay).timeout.connect(_scream.bind(_npcs_within(data.scream_radius)))
	GameManager.stats_npcs_scared += 1
	EventBus.npc_scared.emit(data.display_name)
	Narrator.say_event("npc_scared")
	return true


## Chain reaction: everyone who heard the scream panics too.
func _scream(listeners: Array[Npc]) -> void:
	for other in listeners:
		if is_instance_valid(other):
			other.get_scared("a screaming " + data.display_name)


func _npcs_within(radius: float) -> Array[Npc]:
	var found: Array[Npc] = []
	for other in get_tree().get_nodes_in_group("npcs"):
		if other != self and global_position.distance_to(other.global_position) <= radius:
			found.append(other as Npc)
	return found


func _drop_loot() -> void:
	for prop_data in data.loot:
		var dir: Vector2 = Vector2.RIGHT.rotated(randf() * TAU)
		Prop.spawn(prop_data, global_position + dir * 10.0, dir * randf_range(120.0, 260.0), get_tree())


func _on_player_booed(origin: Vector2, boo_range: float, from_hiding: bool) -> void:
	if state == State.PANIC or state == State.DONE:
		return
	# You spotted the peeking head and BOO'd the cupboard: the ambusher gets ambushed.
	if state == State.HIDING:
		if global_position.distance_to(origin) <= boo_range + 20.0:
			_leave_hiding_spot(origin.direction_to(global_position))
			get_scared("someone who saw its head peeking out")
		return
	if global_position.distance_to(origin) > boo_range or not _has_line_of_sight(origin, global_position):
		return
	var player_masked: bool = _player != null and _player.get("is_masked")
	# The whole trick: a scare only works as a SURPRISE. Jumping out of hiding, wearing a mask, or BOOing before it alerts on you works!
	var facing_player: bool = signf(origin.x - global_position.x) == _facing
	if not from_hiding and not player_masked and (state == State.WINDUP or (facing_player and can_see_player())):
		bubble.visible = true
		bubble.text = "nice try"
		get_tree().create_timer(0.9).timeout.connect(_hide_bubble_if_calm)
		Narrator.say_event("boo_seen")
		return
	get_scared("a masked stranger")


## True if the player is within this NPC's alert range, in line of sight, not hidden, and not masked.
func can_see_player() -> bool:
	if _player == null or _player.get("is_hidden") or _player.get("is_masked"):
		return false
	return can_see(_player)


## True if `node` is within the entity's FOV cone, in range and not blocked by walls/furniture.
## - Ambushers waiting in corners or passive wanderers: smaller FOV cone (55 deg half-angle, reach ~95px).
## - Active wandering monsters: wider FOV cone (65 deg half-angle, reach ~130px).
## - FOV increases slightly with higher game level (floor).
func can_see(node: Node2D) -> bool:
	var to_node: Vector2 = node.global_position - global_position
	var dist: float = to_node.length()
	var max_range: float = _sight()
	if dist > max_range:
		return false
	if not _has_line_of_sight(global_position, node.global_position):
		return false

	# Stationary corner/ambush lurkers only trigger if player walks directly into their vision cone
	var half_angle_deg: float = _view_half_angle()
	var angle_to_target: float = absf(rad_to_deg(Vector2(_facing, 0.0).angle_to(to_node)))
	if angle_to_target <= half_angle_deg:
		return true

	# Bumping directly into monster body
	return dist <= TOUCH_SENSE


## FOV half-angle scaled dynamically with level
func _view_half_angle() -> float:
	var base_angle: float = 52.0 if (state == State.CORNER_LURK or data.hides_in_corners) else 65.0
	var level_bonus: float = minf(float(GameManager.current_level) * 2.5, 20.0)
	return clampf(base_angle + level_bonus, 45.0, 85.0)


## FOV cone reach: compact and not overly long
func _fov_reach() -> float:
	return _sight()


## Dynamic windup time from alert to jumpscare:
## - Corner lurkers / ambush: 0.50s (getting faster on higher levels down to 0.28s)
## - Other passive/wandering entities: 0.75s (getting faster on higher levels down to 0.40s)
func _windup_time() -> float:
	var level_scale: float = clampf(1.0 - float(GameManager.current_level) * 0.08, 0.55, 1.0)
	var base_time: float = 0.50 if (_ambush_windup or state == State.CORNER_LURK or data.hides_in_corners) else 0.75
	return base_time * level_scale * windup_scale * GameManager.monster_windup_scale


## The player if it can see them, otherwise the nearest kid it can see (or null).
func _find_visible_target() -> Node2D:
	if can_see_player():
		return _player
	var best: Node2D = null
	for kid in get_tree().get_nodes_in_group("kids"):
		var k: Kid = kid as Kid
		if k.is_scareable() and can_see(k) and (best == null or global_position.distance_to(k.global_position) < global_position.distance_to(best.global_position)):
			best = k
	return best


## Compact FOV reach that scales moderately with higher levels:
func _sight() -> float:
	var level_bonus: float = minf(float(GameManager.current_level) * 8.0, 48.0)
	var base_reach: float = 85.0 if (state == State.CORNER_LURK or data.hides_in_corners) else 110.0
	return (base_reach + level_bonus) * sight_scale * GameManager.monster_sight_scale


## Turn to look at a point (used by tests and scripted moments).
func face_towards(point: Vector2) -> void:
	_facing = -1.0 if point.x < global_position.x else 1.0
	_look_timer = randf_range(data.look_around_min, data.look_around_max)


## Walls, furniture and doors (collision layer 1) block sight. Fake walls don't. ;)
func _has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _can_start_windup() -> bool:
	return not data.is_harmless and not data.afraid_of_player and not GameManager.is_safe_room


func _enter(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	match new_state:
		State.IDLE:
			bubble.visible = false
			if status_bar:
				status_bar.visible = false
			_ambush_windup = false
			_reset_visuals()
		State.CORNER_LURK:
			bubble.visible = false
			if status_bar:
				status_bar.visible = false
			windup_light.enabled = false
			sprite.material = null
			z_index = 0
			sprite.modulate = data.tint.darkened(0.45)
		State.WINDUP:
			bubble.visible = true
			bubble.text = "!"
			bubble.scale = Vector2.ONE
			if status_bar:
				status_bar.visible = false
			sprite.material = null
			z_index = 0
			windup_light.enabled = true
			windup_light.color = Color(1.0, 0.3, 0.25, 1.0)
		State.COOLDOWN:
			_ambush_windup = false
			bubble.visible = false
			if status_bar:
				status_bar.visible = true
				status_bar.max_value = _cooldown_duration
				status_bar.value = _cooldown_duration
				status_bar.modulate = Color(0.4, 0.8, 1.0)
			sprite.scale = Vector2.ONE * data.sprite_scale
			sprite.material = _unshaded_mat
			z_index = 25
			sprite.modulate = Color(0.55, 0.80, 1.0, 0.85)
			windup_light.enabled = true
			windup_light.color = Color(0.45, 0.75, 1.0, 1.0)
			windup_light.energy = 0.75
		State.DONE:
			bubble.visible = false
			if status_bar:
				status_bar.visible = true
				status_bar.max_value = data.recover_time
				status_bar.value = data.recover_time
				status_bar.modulate = Color(0.8, 0.4, 1.0)
			sprite.material = _unshaded_mat
			z_index = 25
			windup_light.enabled = true
			windup_light.color = Color(0.65, 0.55, 1.0, 1.0)
			windup_light.energy = 0.65


func _hide_bubble_if_calm() -> void:
	if state == State.IDLE:
		bubble.visible = false


func _apply_after_scare() -> void:
	match data.after_scare:
		NpcData.AfterScare.FLEE:
			sprite.modulate.a = 0.75
		NpcData.AfterScare.FAINT:
			stumble.enabled = false  # lie down instead of stumbling
			sprite.rotation = PI / 2.0
		NpcData.AfterScare.FALL_APART:
			stumble.enabled = false
			sprite.scale = Vector2.ONE * data.sprite_scale * 0.7
	# Disabled = ghostly glowing silhouette visible even in dark rooms / through walls
	sprite.visible = true
	sprite.modulate = Color(0.62, 0.65, 0.90, 0.82)


func _recover() -> void:
	_relocate_and_reset()


## When COOLDOWN or DISABLED (DONE) reaches 0, the entity resets and relocates to a corner/spot
## elsewhere in the room (or returns to its post if stationary) so it can lurk or hide again.
func _relocate_and_reset() -> void:
	_reset_visuals()
	if data.can_move and wander_scale > 0.05 and not GameManager.is_safe_room:
		var room_node: Node = get_parent().get_parent() if get_parent() else null
		if room_node != null and room_node.has_method("get_random_relocate_point"):
			var avoid: Vector2 = _player.global_position if _player != null else global_position
			var new_pos: Vector2 = room_node.call("get_random_relocate_point", avoid, 165.0)
			global_position = new_pos
			_home = new_pos
		if data.hides_in_furniture and can_hide:
			var spot: HideSpot = _find_hiding_spot()
			if spot != null:
				_hide_spot = spot
				_enter_hiding_spot()
				return
		if data.hides_in_corners and can_hide:
			_enter(State.CORNER_LURK)
			return
	_enter(State.IDLE)
	_pick_wander_target()


func _reset_visuals() -> void:
	stumble.enabled = true
	sprite.visible = true
	if status_bar:
		status_bar.visible = false
	sprite.material = null
	z_index = 0
	sprite.region_enabled = false
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE * data.sprite_scale
	sprite.modulate = data.tint
	windup_light.enabled = false
	if not data.frames.is_empty():
		sprite.texture = data.frames[0]


## Heard a creaky board / a trap snap: walk over to look. Monsters that stay put (seated
## guests, hiders) and ones busy scaring or switched off ignore it.
func _on_noise_made(at: Vector2, radius: float) -> void:
	if (state != State.IDLE and state != State.CORNER_LURK) or not data.can_move or not can_chase or _hide_spot != null:
		return
	if global_position.distance_to(at) > radius:
		return
	if state == State.CORNER_LURK:
		_enter(State.IDLE)
	_wander_target = at
	_wander_time = 8.0
	_investigating = true
	face_towards(at)
	FloatingText.spawn(self, global_position + Vector2(0, -34), "?", Color(1.0, 0.9, 0.3), 20)


func _pick_wander_target() -> void:
	_investigating = false
	_wander_target = _home + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.0, data.wander_radius * wander_scale)
	_wander_time = randf_range(1.5, 3.5)


func _animate(delta: float) -> void:
	if state == State.DONE:
		return
	sprite.flip_h = _facing < 0.0
	# Frame animation is optional: single-sprite NPCs are animated by StumbleAnimator alone.
	if data.frames.size() < 2 or data.anim_fps <= 0.0:
		return
	# Choppy animation under load: frame rate drops as the CPU meter rises.
	var fps: float = data.anim_fps * (1.0 - 0.7 * LagController.lag_amount())
	if state == State.PANIC:
		fps *= 2.0
	_anim_time += delta
	if _anim_time >= 1.0 / maxf(fps, 0.5):
		_anim_time = 0.0
		_frame = (_frame + 1) % data.frames.size()
		sprite.texture = data.frames[_frame]


## Visibility & darkness:
##   - In safe rooms or when winding up / panicking: visible if within line-of-sight or close.
##   - When lurking in corners (CORNER_LURK) or in dark rooms: hidden in the shadows unless
##     the player illuminates them with the flashlight (or comes right up to them) with line of sight!
##   - Never shows magenta missing-texture placeholders on entities.
func _update_loaded_look() -> void:
	if state == State.DONE or state == State.COOLDOWN:
		sprite.visible = true
		return
	if state == State.HIDING:
		return
	if GameManager.is_safe_room:
		sprite.visible = true
		return

	var dist: float = _distance_to_player()
	var has_los: bool = _player != null and _has_line_of_sight(_player.global_position, global_position)
	var lit_by_player: bool = false
	if _player != null and _player.has_method("is_illuminating"):
		lit_by_player = _player.call("is_illuminating", global_position) and has_los

	if state == State.CORNER_LURK:
		# Corner lurkers stay completely invisible in the shadows unless the flashlight beam hits them directly
		sprite.visible = lit_by_player
		return

	if load_in_radius > 0.0:
		sprite.visible = (dist <= load_in_radius and has_los) or dist <= 40.0 or state == State.WINDUP or state == State.PANIC or lit_by_player
		return

	# Standard dark atmosphere: monsters behind walls or outside your light stay hidden in darkness
	# When flashlight beam encompasses the entity, it becomes visible!
	sprite.visible = lit_by_player or state == State.WINDUP or state == State.PANIC or (has_los and dist <= 50.0)


func _distance_to_player() -> float:
	if _player == null:
		return INF
	return global_position.distance_to(_player.global_position)


# ---------------------------------------------------------------- hiding & ambush

func _wants_to_hide() -> bool:
	return (data.hides_in_furniture and can_hide and _hide_spot == null and _time_since_hide >= data.hide_cooldown
		and not GameManager.is_safe_room)


func _find_hiding_spot() -> HideSpot:
	var best: HideSpot = null
	var best_dist: float = data.hide_search_radius
	for node in get_tree().get_nodes_in_group("hide_spots"):
		var spot: HideSpot = node as HideSpot
		var dist: float = global_position.distance_to(spot.global_position)
		# Don't climb into a cupboard right in front of the player.
		var too_close_to_player: bool = _player != null and spot.global_position.distance_to(_player.global_position) < 140.0
		if dist < best_dist and spot.is_free_for(self) and not too_close_to_player:
			best = spot
			best_dist = dist
	return best


func _walk_to_hiding_spot(delta: float) -> void:
	_hide_walk_time += delta
	if not is_instance_valid(_hide_spot) or not _hide_spot.is_free_for(self) or _hide_walk_time > 6.0:
		_give_up_hiding_spot()  # taken, or stuck behind furniture: try again later
		return
	velocity = global_position.direction_to(_hide_spot.global_position) * data.move_speed * speed_scale
	if global_position.distance_to(_hide_spot.global_position) < _hide_spot.reach * 0.75:
		_enter_hiding_spot()


func _enter_hiding_spot() -> void:
	_enter(State.HIDING)
	_hide_spot.set_occupied(true, self)
	velocity = Vector2.ZERO
	sprite.visible = false
	bubble.visible = false
	# Off right now (not deferred): it's about to sit inside the furniture's collision box,
	# and physics would push it straight back out this very frame.
	body_shape.disabled = true
	global_position = _hide_spot.global_position


func _process_hiding() -> void:
	velocity = Vector2.ZERO
	var player_hidden: bool = _player != null and (_player.get("is_hidden") or _player.get("is_masked"))
	if not player_hidden and _distance_to_player() <= data.ambush_range:
		ambush()
	elif _state_time >= data.hide_time:
		_leave_hiding_spot(Vector2.RIGHT.rotated(randf() * TAU))
		_enter(State.IDLE)


## Jump out at the player with a short wind-up. Also called when the player tries to
## climb into this monster's cupboard.
func ambush() -> void:
	if state != State.HIDING:
		return
	_leave_hiding_spot(global_position.direction_to(_player.global_position) if _player else Vector2.DOWN)
	_ambush_windup = true
	_target = _player
	_enter(State.WINDUP)
	if _player:
		face_towards(_player.global_position)


func _leave_hiding_spot(direction: Vector2) -> void:
	if is_instance_valid(_hide_spot):
		_hide_spot.set_occupied(false)
		global_position = _hide_spot.global_position + direction.normalized() * (_hide_spot.reach * 0.7)
	_hide_spot = null
	_time_since_hide = 0.0
	sprite.visible = true
	body_shape.set_deferred("disabled", false)


## Drop a reservation for a spot it was walking to (not used while actually hiding).
func _give_up_hiding_spot() -> void:
	if state == State.HIDING:
		return
	if is_instance_valid(_hide_spot) and _hide_spot.reserved_by == self:
		_hide_spot.reserved_by = null
	_hide_spot = null
	_time_since_hide = 0.0


# ---------------------------------------------------------------- view cone

func _build_view_cone() -> void:
	_view_cone = Polygon2D.new()
	_view_cone.color = CONE_COLOR
	_view_cone.z_index = -1
	add_child(_view_cone)


## The FOV cone shows where the entity looks:
## - Visible whenever the player can see the entity (not when hiding in cupboards or off-screen in darkness).
## - Shorter, compact reach.
## - Alerts red during windup.
func _update_view_cone() -> void:
	if _view_cone == null:
		return
	var cone_should_show: bool = sprite.visible and state != State.HIDING and state != State.DONE and state != State.COOLDOWN
	_view_cone.visible = cone_should_show
	if not _view_cone.visible:
		return
	_view_cone.color = CONE_ALERT_COLOR if state == State.WINDUP else CONE_COLOR
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var points: PackedVector2Array = [Vector2.ZERO]
	var half_deg: float = _view_half_angle()
	var reach: float = _fov_reach()
	for i in CONE_RAYS + 1:
		var angle: float = deg_to_rad(lerpf(-half_deg, half_deg, float(i) / CONE_RAYS))
		var tip: Vector2 = global_position + Vector2(_facing, 0.0).rotated(angle * _facing) * reach
		var query := PhysicsRayQueryParameters2D.create(global_position, tip, 1)
		query.exclude = [get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		points.append(to_local(hit.position if not hit.is_empty() else tip))
	_view_cone.polygon = points

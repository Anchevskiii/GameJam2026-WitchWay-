class_name Npc
extends CharacterBody2D

## A haunted-house resident that tries to scare the player - and can be scared first.
## Attached to: CharacterBody2D root of scenes/actors/npc.tscn. Configure via `data` (NpcData).
##
## The scare duel:
##   IDLE     wanders around. When the player comes close -> WINDUP
##   WINDUP   visible tell (grows, glows red, "BOOOO" bubble). If it completes while the
##            player is in range, the player loses sanity -> COOLDOWN
##   PANIC    the player honked first! Drops loot, screams (nearby NPCs panic too) and
##            runs around scaring other NPCs it bumps into
##   DONE     fled / fainted / fell apart. Recovers after a while -> IDLE
## Wind-ups pause while LagController.is_frozen (lag is a feature: dodge window).

enum State { IDLE, WINDUP, COOLDOWN, PANIC, DONE }

const MISSING_TEXTURE: Texture2D = preload("res://assets/sprites/environment/missing_texture.png")
## Panicking NPCs scare other NPCs within this distance.
const BUMP_RADIUS: float = 34.0
## A honk always hits NPCs this close, even outside the cone.
const POINT_BLANK: float = 40.0

@export var data: NpcData
## Darkness rooms: > 0 means the NPC is "not loaded" (invisible, then a missing-texture
## placeholder) until the player comes within this many pixels. Set by the Room.
@export var load_in_radius: float = 0.0
## Multiplies data.wander_radius. 0 = stays in its spot (seated dinner guests). Set by the Room.
@export var wander_scale: float = 1.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var bubble: Label = $Bubble
@onready var windup_light: PointLight2D = $WindupLight

var state: State = State.IDLE

var _player: Node2D = null
var _home: Vector2
var _state_time: float = 0.0
var _wander_target: Vector2
var _wander_time: float = 0.0
var _panic_dir: Vector2 = Vector2.RIGHT
var _panic_turn_time: float = 0.0
var _anim_time: float = 0.0
var _frame: int = 0


func _ready() -> void:
	add_to_group("npcs")
	_home = global_position
	_wander_target = _home
	bubble.visible = false
	windup_light.enabled = false
	if data == null:
		push_error("Npc %s has no NpcData." % name)
		set_physics_process(false)
		return
	_reset_visuals()
	EventBus.player_honked.connect(_on_player_honked)


func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if GameManager.is_game_over:
		velocity = Vector2.ZERO
		return

	_animate(delta)
	_update_loaded_look()
	_state_time += delta
	match state:
		State.IDLE:
			_process_idle(delta)
		State.WINDUP:
			_process_windup(delta)
		State.COOLDOWN:
			velocity = Vector2.ZERO
			if _state_time >= data.scare_cooldown:
				_enter(State.IDLE)
		State.PANIC:
			_process_panic(delta)
		State.DONE:
			velocity = Vector2.ZERO
			if _state_time >= data.recover_time:
				_recover()
	move_and_slide()


# ---------------------------------------------------------------- states

func _process_idle(delta: float) -> void:
	var dist: float = _distance_to_player()

	if data.afraid_of_player and dist < data.notice_range:
		var away: Vector2 = (global_position - _player.global_position).normalized()
		velocity = away * data.move_speed * 1.4
	elif data.can_move:
		_wander_time -= delta
		if global_position.distance_to(_wander_target) < 6.0 or _wander_time <= 0.0:
			_pick_wander_target()
		velocity = global_position.direction_to(_wander_target) * data.move_speed * 0.6
	else:
		velocity = Vector2.ZERO

	if _can_start_windup(dist):
		_enter(State.WINDUP)


func _process_windup(delta: float) -> void:
	velocity = Vector2.ZERO
	# Lag freeze = wind-up pauses. That's the dodge window.
	if LagController.is_frozen:
		_state_time -= delta
	var progress: float = clampf(_state_time / data.windup_time, 0.0, 1.0)

	# The tell: puff up, glow red, and a growing "BOOOO" bubble.
	sprite.scale = Vector2.ONE * data.sprite_scale * (1.0 + 0.35 * progress)
	sprite.modulate = data.tint.lerp(Color(1.0, 0.45, 0.45), progress)
	windup_light.energy = 0.4 + 1.6 * progress
	# "B" -> "BO" -> "BOO" -> "BOO!" -> "BOO!!!" as the scare charges up.
	var letters: int = maxi(1, ceili(minf(progress / 0.7, 1.0) * data.windup_text.length()))
	bubble.text = data.windup_text.left(letters) + "!".repeat(int(maxf(progress - 0.7, 0.0) / 0.1))
	bubble.scale = Vector2.ONE * (0.8 + 0.6 * progress)

	if _distance_to_player() > data.notice_range * 1.5:
		bubble.text = "aww"
		_enter(State.COOLDOWN)
		return
	if progress >= 1.0:
		_release_scare()


func _release_scare() -> void:
	bubble.text = data.windup_text + "!"
	bubble.scale = Vector2.ONE * 1.6
	AudioManager.play(data.scare_sound)
	if _distance_to_player() <= data.scare_range:
		GameManager.scare_player(data.scare_damage, data.display_name)
	_enter(State.COOLDOWN)


func _process_panic(delta: float) -> void:
	_panic_turn_time -= delta
	if _panic_turn_time <= 0.0 or is_on_wall():
		_panic_dir = Vector2.RIGHT.rotated(randf() * TAU)
		_panic_turn_time = randf_range(0.25, 0.5)
	velocity = _panic_dir * data.panic_speed
	sprite.flip_h = velocity.x < 0.0

	# Chain reaction: bump into other NPCs and scare them too.
	for other in get_tree().get_nodes_in_group("npcs"):
		if other != self and global_position.distance_to(other.global_position) < BUMP_RADIUS:
			(other as Npc).get_scared("a panicking " + data.display_name)

	if _state_time >= data.panic_time:
		_enter(State.DONE)
		_apply_after_scare()


# ---------------------------------------------------------------- scare duel API

## Scare this NPC (player honk, flying prop, panicking friend). Returns true if it worked.
func get_scared(_by: String = "") -> bool:
	if state == State.PANIC or state == State.DONE:
		return false
	_enter(State.PANIC)
	_reset_visuals()
	bubble.visible = true
	bubble.text = "!!"
	AudioManager.play("npc_yelp", -2.0, randf_range(0.85, 1.25))
	_drop_loot()
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


func _on_player_honked(origin: Vector2, direction: Vector2, honk_range: float, half_angle_deg: float) -> void:
	var to_me: Vector2 = global_position - origin
	var dist: float = to_me.length()
	if dist > honk_range:
		return
	if dist > POINT_BLANK and absf(rad_to_deg(direction.angle_to(to_me))) > half_angle_deg:
		return
	get_scared("a rubber chicken")


# ---------------------------------------------------------------- helpers

func _can_start_windup(dist: float) -> bool:
	return (not data.is_harmless and not data.afraid_of_player and not GameManager.is_safe_room
		and dist <= data.notice_range)


func _enter(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	match new_state:
		State.IDLE:
			bubble.visible = false
			_reset_visuals()
		State.WINDUP:
			bubble.visible = true
			windup_light.enabled = true
		State.COOLDOWN:
			windup_light.enabled = false
			sprite.scale = Vector2.ONE * data.sprite_scale
			sprite.modulate = data.tint
			get_tree().create_timer(0.8).timeout.connect(_hide_bubble_if_calm)


func _hide_bubble_if_calm() -> void:
	if state == State.COOLDOWN or state == State.IDLE:
		bubble.visible = false


func _apply_after_scare() -> void:
	match data.after_scare:
		NpcData.AfterScare.FLEE:
			bubble.text = "nope"
			create_tween().tween_property(sprite, "modulate:a", 0.0, 0.6)
		NpcData.AfterScare.FAINT:
			bubble.text = "zzz"
			sprite.rotation = PI / 2.0
			sprite.modulate = data.tint.darkened(0.35)
		NpcData.AfterScare.FALL_APART:
			bubble.text = "*crumble*"
			sprite.visible = false


func _recover() -> void:
	_reset_visuals()
	_enter(State.IDLE)
	_pick_wander_target()


func _reset_visuals() -> void:
	sprite.visible = true
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE * data.sprite_scale
	sprite.modulate = data.tint
	windup_light.enabled = false
	if not data.frames.is_empty():
		sprite.texture = data.frames[0]


func _pick_wander_target() -> void:
	_wander_target = _home + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.0, data.wander_radius * wander_scale)
	_wander_time = randf_range(1.5, 3.5)


func _animate(delta: float) -> void:
	if data.frames.size() < 2 or data.anim_fps <= 0.0 or state == State.DONE:
		return
	# Choppy animation under load: frame rate drops as the CPU meter rises.
	var fps: float = data.anim_fps * (1.0 - 0.7 * LagController.lag_amount())
	if state == State.PANIC:
		fps *= 2.0
	_anim_time += delta
	if _anim_time >= 1.0 / maxf(fps, 0.5):
		_anim_time = 0.0
		_frame = (_frame + 1) % data.frames.size()
		if sprite.texture != MISSING_TEXTURE:
			sprite.texture = data.frames[_frame]
	if velocity.x != 0.0 and state != State.PANIC:
		sprite.flip_h = velocity.x < 0.0


## Darkness rooms: far = invisible, closer = magenta placeholder, close = real sprite.
func _update_loaded_look() -> void:
	if load_in_radius <= 0.0 or state == State.DONE:
		return
	var dist: float = _distance_to_player()
	if dist <= load_in_radius or state == State.WINDUP:
		sprite.visible = true
		if sprite.texture == MISSING_TEXTURE and not data.frames.is_empty():
			sprite.texture = data.frames[_frame]
			sprite.region_enabled = false
	elif dist <= load_in_radius * 2.0:
		sprite.visible = randf() > 0.15  # flickers while "streaming in"
		sprite.texture = MISSING_TEXTURE
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, 0, 16, 28)
	else:
		sprite.visible = false


func _distance_to_player() -> float:
	if _player == null:
		return INF
	return global_position.distance_to(_player.global_position)

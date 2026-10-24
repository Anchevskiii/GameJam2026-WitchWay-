class_name Kid
extends CharacterBody2D

## A trick-or-treating kid in a costume, exploring the haunted house with friends.
## Attached to: CharacterBody2D root of scenes/actors/kid.tscn (spawned by Room for "&").
##
## Behaviour:
##   WANDER     the group leader wanders; the others tag along behind. Everyone keeps away
##              from monsters they get close to.
##   STARTLED   got scared (your BOO, a monster's scare, a panicking monster): screams,
##              drops candy and runs away. Running into a monster scares IT (chain reaction!)
##   PEED       the 3rd scare is one too many: puddle, crying, goes home.
## Candy restores the player's sanity, so scaring kids is how you heal.

enum State { WANDER, STARTLED, PEED }

const PUDDLE_TEXTURE: Texture2D = preload("res://assets/sprites/objects/puddle.png")
const CANDY: PropData = preload("res://data/props/candy.tres")
## A startled kid running into a monster closer than this scares it.
const BUMP_RADIUS: float = 30.0

## Scares a kid can take before peeing their pants.
@export var max_scares: int = 3
@export var walk_speed: float = 70.0
@export var run_speed: float = 175.0
@export var startle_time: float = 1.6
## Seconds after a scare during which the kid can't be scared again.
@export var scare_immunity: float = 0.8
## Keeps this far from monsters it notices.
@export var monster_avoid_range: float = 90.0
@export var costumes: Array[Texture2D] = []

@onready var sprite: Sprite2D = $Sprite2D
@onready var bubble: Label = $Bubble
@onready var pips: HBoxContainer = $Pips
@onready var body_shape: CollisionShape2D = $CollisionShape2D

var state: State = State.WANDER
## Followers stay near their leader. A leader (or a kid whose leader went home) wanders.
var leader: Kid = null
var scares: int = 0

var _state_time: float = 0.0
var _immune_left: float = 0.0
var _run_dir: Vector2 = Vector2.RIGHT
var _wander_target: Vector2
var _wander_time: float = 0.0
var _follow_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("kids")
	if not costumes.is_empty():
		sprite.texture = costumes.pick_random()
	bubble.visible = false
	_wander_target = global_position
	_follow_offset = Vector2(randf_range(-28.0, 28.0), randf_range(18.0, 34.0))
	EventBus.player_booed.connect(_on_player_booed)
	_update_pips()


func _physics_process(delta: float) -> void:
	_state_time += delta
	_immune_left -= delta
	match state:
		State.WANDER:
			_process_wander(delta)
		State.STARTLED:
			_process_startled()
		State.PEED:
			velocity = Vector2.ZERO
	if absf(velocity.x) > 2.0:
		sprite.flip_h = velocity.x < 0.0
	move_and_slide()


## True while the kid can still be scared (not peed, not just scared).
func is_scareable() -> bool:
	return state != State.PEED


## Scare this kid. `from` is where the scare came from (it runs the other way).
func get_scared(from: Vector2, _by: String = "") -> bool:
	if state == State.PEED or _immune_left > 0.0:
		return false
	scares += 1
	_immune_left = scare_immunity
	_update_pips()
	GameManager.stats_npcs_scared += 1
	EventBus.kid_scared.emit(scares, max_scares)
	if scares >= max_scares:
		_pee()
		return true
	state = State.STARTLED
	_state_time = 0.0
	_run_dir = from.direction_to(global_position).rotated(randf_range(-0.4, 0.4))
	if _run_dir == Vector2.ZERO:
		_run_dir = Vector2.RIGHT.rotated(randf() * TAU)
	_say("AAAH!", 0.9)
	AudioManager.play("npc_yelp", -6.0, randf_range(1.3, 1.6))
	_drop_candy(1)
	return true


# ---------------------------------------------------------------- states

func _process_wander(delta: float) -> void:
	var monster: Node2D = _nearest_active_monster()
	if monster and global_position.distance_to(monster.global_position) < monster_avoid_range:
		velocity = monster.global_position.direction_to(global_position) * walk_speed * 1.3
		return
	if is_instance_valid(leader) and leader != self and leader.is_scareable():
		var spot: Vector2 = leader.global_position + _follow_offset
		velocity = global_position.direction_to(spot) * walk_speed * 1.2 if global_position.distance_to(spot) > 14.0 else Vector2.ZERO
		return
	_wander_time -= delta
	if global_position.distance_to(_wander_target) < 8.0 or _wander_time <= 0.0 or is_on_wall():
		_wander_target = global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40.0, 160.0)
		_wander_time = randf_range(1.5, 3.5)
	velocity = global_position.direction_to(_wander_target) * walk_speed


func _process_startled() -> void:
	if is_on_wall():
		_run_dir = _run_dir.bounce(get_wall_normal()).rotated(randf_range(-0.5, 0.5))
	velocity = _run_dir * run_speed
	# Running away screaming into a monster's arms scares the monster. Chain reaction!
	for npc in get_tree().get_nodes_in_group("npcs"):
		if global_position.distance_to((npc as Node2D).global_position) < BUMP_RADIUS:
			(npc as Npc).get_scared("a screaming kid")
	if _state_time >= startle_time:
		state = State.WANDER
		bubble.visible = false


func _pee() -> void:
	state = State.PEED
	_state_time = 0.0
	velocity = Vector2.ZERO
	body_shape.set_deferred("disabled", true)
	GameManager.stats_kids_peed += 1
	_say("WAAAH!", 2.5)
	Narrator.say_event("kid_peed")
	FloatingText.spawn(self, global_position, "PEED!", Color(1.0, 0.9, 0.3))
	_drop_candy(3)  # drops the whole candy bag
	var puddle := Sprite2D.new()
	puddle.texture = PUDDLE_TEXTURE
	puddle.global_position = global_position + Vector2(0, 8)
	puddle.z_index = -2
	puddle.scale = Vector2.ZERO
	get_parent().add_child(puddle)
	puddle.create_tween().tween_property(puddle, "scale", Vector2.ONE * 1.4, 1.0)
	# Cry for a bit, then go home (fade out).
	var tween: Tween = create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(self, "modulate:a", 0.0, 1.2)
	tween.tween_callback(queue_free)


# ---------------------------------------------------------------- helpers

func _on_player_booed(origin: Vector2, boo_range: float, _from_hiding: bool) -> void:
	# Kids are easy: any BOO in range works, no sneaking needed.
	if global_position.distance_to(origin) > boo_range:
		return
	var query := PhysicsRayQueryParameters2D.create(origin, global_position, 1)
	if get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		get_scared(origin)


func _drop_candy(count: int) -> void:
	for i in count:
		var dir: Vector2 = Vector2.RIGHT.rotated(randf() * TAU)
		Prop.spawn(CANDY, global_position + dir * 8.0, dir * randf_range(80.0, 170.0), get_tree())


func _nearest_active_monster() -> Node2D:
	var best: Node2D = null
	for npc in get_tree().get_nodes_in_group("npcs"):
		var n: Npc = npc as Npc
		if n.state == Npc.State.DONE or n.state == Npc.State.HIDING or not n.sprite.visible:
			continue
		if best == null or global_position.distance_to(n.global_position) < global_position.distance_to(best.global_position):
			best = n
	return best


func _update_pips() -> void:
	for i in pips.get_child_count():
		var pip: ColorRect = pips.get_child(i) as ColorRect
		pip.color = Color(1.0, 0.85, 0.2) if i >= scares else Color(0.25, 0.22, 0.3)


func _say(text_value: String, seconds: float) -> void:
	bubble.text = text_value
	bubble.visible = true
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(bubble) and state != State.PEED:
			bubble.visible = false)

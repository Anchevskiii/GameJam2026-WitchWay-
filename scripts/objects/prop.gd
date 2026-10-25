class_name Prop
extends RigidBody2D

## A dropped prop (sock, cauldron, candy...). Adds glitch when it spawns, rolls around,
## and knocks over NPCs it hits while moving fast (chain reactions!).
## Props with sanity_restore (candy) are picked up by walking over them.
## Attached to: RigidBody2D root of scenes/objects/prop.tscn
## Spawn with: Prop.spawn(prop_data, world_position, impulse)
##
## Collision layers used by the project:
##   1 = walls/furniture, 2 = player, 3 (value 4) = NPCs & triggers, 4 (value 8) = props

const SCENE_PATH: String = "res://scenes/objects/prop.tscn"
## Oldest props get deleted above this count (their CPU load still decays normally).
const MAX_PROPS: int = 60
## Candy is picked up when the player gets this close.
const PICKUP_RADIUS: float = 36.0

static var _live_props: Array[Prop] = []

@export var data: PropData
## A prop moving faster than this scares any NPC it bumps into.
@export var knock_speed: float = 90.0

var _spawn_impulse: Vector2 = Vector2.ZERO
var _reachability_checked: bool = false
var _rest_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


## Creates a prop in the current room's "Props" layer.
static func spawn(prop_data: PropData, at: Vector2, impulse: Vector2, tree: SceneTree) -> Prop:
	var parent: Node = tree.get_first_node_in_group("prop_layer")
	if parent == null:
		push_warning("Prop.spawn: no node in group 'prop_layer' (is a Room loaded?)")
		return null
	var prop: Prop = (load(SCENE_PATH) as PackedScene).instantiate()
	prop.data = prop_data
	prop.position = (parent as Node2D).to_local(at)
	prop._spawn_impulse = impulse
	# Deferred: spawns often happen inside a physics callback (a prop hits an NPC, the NPC
	# drops more props), and Godot forbids adding physics bodies mid-physics-step.
	parent.add_child.call_deferred(prop)
	return prop


func _ready() -> void:
	if data == null:
		queue_free()
		return
	sprite.texture = data.texture
	sprite.scale = Vector2.ONE * data.sprite_scale
	mass = data.mass
	var shape := CircleShape2D.new()
	shape.radius = maxf(4.0, data.texture.get_width() * data.sprite_scale * 0.35) if data.texture else 6.0
	collision_shape.shape = shape
	body_entered.connect(_on_body_entered)
	apply_central_impulse(_spawn_impulse * mass)
	angular_velocity = randf_range(-8.0, 8.0)

	_register()
	GameManager.add_cpu_load(data.load_weight)
	GameManager.stats_props_spawned += 1
	EventBus.prop_spawned.emit(data.prop_name, data.load_weight)
	if data.is_heavy():
		AudioManager.play("thud")
		Narrator.say_event("heavy_prop", {"prop": data.prop_name, "weight": int(data.load_weight * GameManager.cpu_load_multiplier)})
	else:
		AudioManager.play("pop", -6.0, randf_range(0.9, 1.3))


func _exit_tree() -> void:
	_live_props.erase(self)


func _register() -> void:
	_live_props.append(self)
	while _live_props.size() > MAX_PROPS:
		var oldest: Prop = _live_props.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()


## Candy: picked up by walking over it. A distance check (not a collision) so it also
## works for candy that has come to rest and gone to sleep in the physics engine.
func _physics_process(delta: float) -> void:
	if data == null or data.sanity_restore <= 0.0:
		return

	# Ensure dropped candy is never trapped inside or on top of solid furniture/walls
	if not _reachability_checked:
		if linear_velocity.length() < 15.0:
			_rest_timer += delta
			if _rest_timer >= 0.25:
				_reachability_checked = true
				_ensure_candy_reachable()
		else:
			_rest_timer = 0.0

	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player and not player.get("is_hidden") and global_position.distance_to(player.global_position) < PICKUP_RADIUS:
		GameManager.restore_sanity(data.sanity_restore)
		FloatingText.spawn(self, global_position, "+%d SANITY" % roundi(data.sanity_restore), Color(0.5, 1.0, 0.55), 18)
		AudioManager.play("pop", -4.0, 1.5)
		queue_free()


func _ensure_candy_reachable() -> void:
	var space := get_world_2d().direct_space_state
	var point_query := PhysicsPointQueryParameters2D.new()
	point_query.position = global_position
	point_query.collision_mask = 1  # walls & solid furniture
	var hits := space.intersect_point(point_query, 1)
	if not hits.is_empty():
		for dist in [24.0, 36.0, 48.0, 64.0]:
			for step in 8:
				var test_pos: Vector2 = global_position + Vector2.RIGHT.rotated(step * PI / 4.0) * dist
				point_query.position = test_pos
				if space.intersect_point(point_query, 1).is_empty():
					global_position = test_pos
					linear_velocity = Vector2.ZERO
					sleeping = true
					return


func _on_body_entered(body: Node) -> void:
	if body is Npc and linear_velocity.length() >= knock_speed:
		(body as Npc).get_scared("a flying " + data.prop_name)

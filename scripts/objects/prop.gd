class_name Prop
extends RigidBody2D

## A dropped prop (sock, cauldron, ...). Adds CPU load when it spawns, rolls around,
## and knocks over NPCs it hits while moving fast (chain reactions!).
## Attached to: RigidBody2D root of scenes/objects/prop.tscn
## Spawn with: Prop.spawn(prop_data, world_position, impulse)
##
## Collision layers used by the project:
##   1 = walls/furniture, 2 = player, 3 (value 4) = NPCs & triggers, 4 (value 8) = props

const SCENE_PATH: String = "res://scenes/objects/prop.tscn"
## Oldest props get deleted above this count (their CPU load still decays normally).
const MAX_PROPS: int = 60

static var _live_props: Array[Prop] = []

@export var data: PropData
## A prop moving faster than this scares any NPC it bumps into.
@export var knock_speed: float = 90.0

var _spawn_impulse: Vector2 = Vector2.ZERO

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


func _on_body_entered(body: Node) -> void:
	if body is Npc and linear_velocity.length() >= knock_speed:
		(body as Npc).get_scared("a flying " + data.prop_name)

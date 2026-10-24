class_name JumpscareTrigger
extends FloorTrap

## An invisible spot (usually a doorway). The first time you cross it a face fills the
## screen with a scream, and a monster is suddenly standing right behind you.
## One-shot: it's gone afterwards.

const NPC_SCENE: PackedScene = preload("res://scenes/actors/npc.tscn")
const FACES: Array[String] = ["ghoul", "stalker"]
## Monsters that can appear behind you.
const SPAWNS: Array[String] = ["res://data/npcs/ghost.tres", "res://data/npcs/werewolf.tres", "res://data/npcs/jack_o_lantern.tres"]

@export var damage: float = 15.0
## How far behind the player the monster appears.
@export var spawn_distance: float = 70.0

## Difficulty from the Room, passed on to the monster that appears.
var npc_windup_scale: float = 1.0
var npc_damage_scale: float = 1.0
var npc_speed_scale: float = 1.0


func _on_stepped() -> void:
	set_deferred("monitoring", false)
	EventBus.jumpscare_requested.emit(FACES.pick_random(), damage)
	# ...and when the face is gone, something is right behind you.
	var back: Vector2 = -_player.velocity.normalized() if _player.velocity.length() > 5.0 else Vector2.DOWN
	var spot: Vector2 = _free_spot_near(_player.global_position, [back, back.orthogonal(), -back.orthogonal(), -back])
	if spot == Vector2.INF:
		queue_free()
		return
	var npc: Npc = NPC_SCENE.instantiate()
	npc.data = load(SPAWNS.pick_random())
	npc.windup_scale = npc_windup_scale
	npc.damage_scale = npc_damage_scale
	npc.speed_scale = npc_speed_scale
	npc.position = spot
	var actors: Node = get_tree().get_first_node_in_group("actors_root")
	if actors:
		actors.add_child.call_deferred(npc)
	queue_free()


## The first of `directions` (from `origin`, spawn_distance away) that isn't inside a wall.
func _free_spot_near(origin: Vector2, directions: Array) -> Vector2:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for dir in directions:
		var point := PhysicsPointQueryParameters2D.new()
		point.position = origin + (dir as Vector2) * spawn_distance
		point.collision_mask = 1  # walls and furniture
		var ray := PhysicsRayQueryParameters2D.create(origin, point.position, 1)
		if space.intersect_point(point).is_empty() and space.intersect_ray(ray).is_empty():
			return point.position
	return Vector2.INF

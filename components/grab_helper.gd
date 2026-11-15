class_name GrabHelper
extends RefCounted
## Stateless Cargo Push/Pull Attachment Helpers for Tarek.

static func find_pushable(ray: RayCast2D) -> Node2D:
	if not ray:
		return null
	ray.force_raycast_update()
	if not ray.is_colliding():
		return null
	var col: Object = ray.get_collider()
	if not (col is Node):
		return null
	var node := col as Node
	if node.is_in_group("pushable"):
		return node as Node2D
	var p: Node = node.get_parent()
	return (p as Node2D) if p and p.is_in_group("pushable") else null

static func detach(body: PhysicsBody2D, target: Node2D) -> void:
	if is_instance_valid(target) and target is PhysicsBody2D and body:
		body.remove_collision_exception_with(target)

static func attach(body: PhysicsBody2D, target: Node2D) -> Vector2:
	if target and target is PhysicsBody2D and body:
		body.add_collision_exception_with(target)
	return (target.global_position - body.global_position) if (target and body) else Vector2.ZERO

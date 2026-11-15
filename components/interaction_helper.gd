class_name InteractionHelper
extends RefCounted
## Stateless Proximity & Raycast Interaction Helpers for Tarek.

static func set_prompt(a: Area2D, vis: bool) -> void:
	if is_instance_valid(a) and a.get_parent() and a.get_parent().has_method("set_prompt_visible"):
		a.get_parent().set_prompt_visible(vis)

static func interact_nearest(user: Node2D, nearby: Array[Area2D], ray: RayCast2D) -> void:
	for a in nearby:
		if not is_instance_valid(a):
			continue
		var target = a.get_parent() if a.get_parent().has_method("interact") else a
		if target.has_method("interact"):
			target.interact(user)
			return
	if ray and ray.is_colliding():
		var col: Object = ray.get_collider()
		if col is Node:
			var node := col as Node
			var p: Node = node.get_parent()
			var target: Node = p if (node is Area2D and p and p.has_method("interact")) else node
			if target and target.has_method("interact"):
				target.interact(user)

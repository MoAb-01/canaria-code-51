class_name Interactor
extends Node2D
## Handles interaction queries, Area2D overlaps, and RayCast checks for an entity.

@export var ray_cast: RayCast2D
@export var detection_area: Area2D
@export var ray_length: float = 54.0

var nearby_interactables: Array[Area2D] = []

func _ready() -> void:
	if detection_area:
		detection_area.area_entered.connect(_on_area_entered)
		detection_area.area_exited.connect(_on_area_exited)
	
	var dl = get_node_or_null("/root/DialogueLayer")
	if dl:
		dl.dialogue_finished.connect(refresh_prompts)

func update_facing(facing_dir: Vector2) -> void:
	if ray_cast:
		ray_cast.target_position = facing_dir * ray_length

func _on_area_entered(area: Area2D) -> void:
	if area not in nearby_interactables:
		nearby_interactables.append(area)
		_notify_focus(area, true)

func _on_area_exited(area: Area2D) -> void:
	if area in nearby_interactables:
		nearby_interactables.erase(area)
		_notify_focus(area, false)

func refresh_prompts() -> void:
	for area in nearby_interactables:
		if is_instance_valid(area):
			_notify_focus(area, true)

func _notify_focus(area: Area2D, focused: bool) -> void:
	if area.has_method("set_focused"):
		area.set_focused(focused)
	else:
		var parent := area.get_parent()
		if parent and parent.has_method("set_prompt_visible"):
			parent.set_prompt_visible(focused)

func try_interact(user: Node2D) -> bool:
	nearby_interactables = nearby_interactables.filter(func(a): return is_instance_valid(a))
	if not nearby_interactables.is_empty():
		var best_area: Area2D = null
		var best_dist: float = INF
		for area in nearby_interactables:
			var d := global_position.distance_squared_to(area.global_position)
			if d < best_dist:
				best_dist = d
				best_area = area
		if best_area:
			if best_area.has_method("interact"):
				best_area.interact(user)
				return true
			var parent := best_area.get_parent()
			if parent and parent.has_method("interact"):
				parent.interact(user)
				return true

	if ray_cast:
		ray_cast.force_raycast_update()
		if ray_cast.is_colliding():
			var collider := ray_cast.get_collider()
			if collider:
				var target := collider.get_parent() if collider is Area2D else collider
				if target and target.has_method("interact"):
					target.interact(user)
					return true
				elif collider.has_method("interact"):
					collider.interact(user)
					return true
	return false

func get_pushable_collider() -> Node2D:
	if ray_cast:
		ray_cast.force_raycast_update()
		if ray_cast.is_colliding():
			var col := ray_cast.get_collider()
			if col and col.is_in_group("pushable"):
				return col as Node2D
			if col and col.get_parent() and col.get_parent().is_in_group("pushable"):
				return col.get_parent() as Node2D
	return null

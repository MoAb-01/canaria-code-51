class_name Bullet
extends Area2D
## Universal 16-Bit Projectile & Ballistics.
## Supports low-cover pass-over during peek-shooting and HealthComponent damage dispatch.

@export var speed: float = 950.0
@export var damage: float = 25.0
@export var max_lifetime: float = 1.6
var direction: Vector2 = Vector2.RIGHT
var shooter: Node = null
var ignore_low_cover: bool = false
var _lifetime_timer: float = 0.0
var _has_hit: bool = false

func _ready() -> void:
	rotation = direction.angle()
	body_entered.connect(_on_hit)
	area_entered.connect(_on_hit)

func _physics_process(delta: float) -> void:
	if _has_hit:
		return
	var next_pos := global_position + direction * speed * delta
	var hit := _sweep_ray(global_position, next_pos)
	global_position = hit.position if not hit.is_empty() else next_pos
	if not hit.is_empty():
		_on_hit(hit.collider)
	elif _lifetime_timer + delta >= max_lifetime:
		queue_free()
	_lifetime_timer += delta

func setup(p_origin: Vector2, p_dir: Vector2, p_speed: float, p_damage: float, p_shooter: Node, p_ignore_cover: bool) -> void:
	global_position = p_origin
	direction = p_dir.normalized() if p_dir != Vector2.ZERO else Vector2.RIGHT
	speed = p_speed
	damage = p_damage
	shooter = p_shooter
	ignore_low_cover = p_ignore_cover
	rotation = direction.angle()

func _sweep_ray(from_pos: Vector2, to_pos: Vector2) -> Dictionary:
	var space := get_world_2d().direct_space_state
	if not space or from_pos.is_equal_approx(to_pos):
		return {}
	var query := PhysicsRayQueryParameters2D.create(from_pos, to_pos, collision_mask | 3)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.hit_from_inside = true
	var excluded: Array[RID] = [get_rid()]
	for _i in 6:
		query.exclude = excluded
		var res := space.intersect_ray(query)
		if res.is_empty() or (res.collider is Node and not _should_ignore(res.collider as Node)):
			return res
		excluded.append(res.rid)
	return {}

func _should_ignore(target: Node) -> bool:
	if target == shooter or (shooter and shooter.is_ancestor_of(target)) or (ignore_low_cover and target.is_in_group("low_cover")):
		return true
	var rx := _find_damage_receiver(target)
	return (target is Area2D and rx == null) or (rx != null and (rx.get("is_dead") == true or rx.get("_active") == false))

func _on_hit(target: Node) -> void:
	if _has_hit or not target or _should_ignore(target):
		return
	var rx := _find_damage_receiver(target)
	if rx and rx.has_method("receive_hit"):
		rx.receive_hit(damage, direction, shooter)
	elif rx:
		rx.take_damage(damage, direction, shooter)
	_has_hit = true
	_spawn_impact_spark()
	queue_free()

func _find_damage_receiver(node: Node) -> Node:
	if node.has_method("receive_hit") or node.has_method("take_damage"):
		return node
	for child in node.get_children():
		if child.has_method("receive_hit") or child.has_method("take_damage"):
			return child
	return null

func _spawn_impact_spark() -> void:
	if not get_parent():
		return
	var spark := CPUParticles2D.new()
	var props := {"emitting": true, "one_shot": true, "explosiveness": 1.0, "amount": 6, "lifetime": 0.14, "direction": -direction, "spread": 65.0, "initial_velocity_min": 60.0, "initial_velocity_max": 130.0, "scale_amount_min": 2.0, "scale_amount_max": 3.5, "color": Color(1.0, 0.88, 0.45, 1.0)}
	for k in props:
		spark.set(k, props[k])
	get_parent().add_child(spark)
	spark.global_position = global_position
	spark.finished.connect(spark.queue_free)

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
	position += direction * speed * delta
	_lifetime_timer += delta
	if _lifetime_timer >= max_lifetime:
		queue_free()

func setup(p_origin: Vector2, p_dir: Vector2, p_speed: float, p_damage: float, p_shooter: Node, p_ignore_cover: bool) -> void:
	global_position = p_origin
	direction = p_dir.normalized() if p_dir != Vector2.ZERO else Vector2.RIGHT
	speed = p_speed
	damage = p_damage
	shooter = p_shooter
	ignore_low_cover = p_ignore_cover
	rotation = direction.angle()

func _on_hit(target: Node) -> void:
	if _has_hit or not target:
		return
	if target == shooter or (shooter and shooter.is_ancestor_of(target)):
		return
	if ignore_low_cover and target.is_in_group("low_cover"):
		return

	var dmg_target := _resolve_damage_target(target)
	if dmg_target:
		dmg_target.take_damage(damage, direction, shooter)
	elif target is Area2D:
		# Ignore non-damage Area2Ds such as InteractionDetector or CoverArea
		return

	_has_hit = true
	_spawn_impact_spark()
	queue_free()

func _resolve_damage_target(node: Node) -> Node:
	if node.has_method("take_damage"):
		return node
	var hc := node.get_node_or_null("HealthComponent")
	if hc and hc.has_method("take_damage"):
		return hc
	for child in node.get_children():
		if child.has_method("take_damage"):
			return child
	return null

func _spawn_impact_spark() -> void:
	if not get_parent():
		return
	var spark := CPUParticles2D.new()
	spark.global_position = global_position
	spark.emitting = true
	spark.one_shot = true
	spark.explosiveness = 1.0
	spark.amount = 6
	spark.lifetime = 0.14
	spark.direction = -direction
	spark.spread = 65.0
	spark.initial_velocity_min = 60.0
	spark.initial_velocity_max = 130.0
	spark.scale_amount_min = 2.0
	spark.scale_amount_max = 3.5
	spark.color = Color(1.0, 0.88, 0.45, 1.0)
	get_parent().add_child(spark)
	spark.finished.connect(spark.queue_free)

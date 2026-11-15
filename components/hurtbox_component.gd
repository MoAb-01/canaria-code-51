class_name HurtboxComponent
extends Area2D
## Universal 360-degree Hitbox / Hurtbox receiver for any damageable entity.
## Attach as a child with a CollisionShape2D centered on the entity's visual body.

@export var health_component: HealthComponent

var _active: bool = true


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	monitoring = true
	monitorable = true

	if not health_component and get_parent():
		health_component = get_parent().get_node_or_null("HealthComponent") as HealthComponent

	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("entity_died"):
		eb.entity_died.connect(_on_entity_died)


## Forwards a confirmed hit directly to the linked HealthComponent.
## Returns false if inactive or missing a valid alive HealthComponent so dead bodies do not absorb hits.
func receive_hit(damage: float, hit_dir: Vector2 = Vector2.ZERO, source: Node = null) -> bool:
	if not _active or not health_component or health_component.is_dead:
		return false
	return health_component.take_damage(damage, hit_dir, source)


## Enables or disables hurtbox detection and all child collision shapes safely.
func set_active(active: bool) -> void:
	_active = active
	set_deferred("monitoring", active)
	set_deferred("monitorable", active)
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", not active)


func _on_entity_died(entity: Node) -> void:
	if entity == get_parent():
		set_active(false)

class_name TestGuard
extends CharacterBody2D
## Test Crew Guard / Practice Dummy.
## Demonstrates modular HealthComponent (with damaged sprite swap) and WeaponComponent.

@export var return_fire_enabled: bool = true
@export var fire_interval: float = 1.8

var last_facing_dir: Vector2 = Vector2.DOWN
var _target: Node2D = null
var _fire_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var health: Node = $HealthComponent
@onready var weapon: Node2D = $WeaponComponent
@onready var hp_fill: ColorRect = $HPBar/Fill

func _ready() -> void:
	y_sort_enabled = true
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("entity_damaged"):
		eb.entity_damaged.connect(_on_entity_damaged)

func _physics_process(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()
	global_position = global_position.round()

	if health and health.is_dead:
		return

	if return_fire_enabled and is_instance_valid(_target) and weapon:
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			weapon.set_aim_target(_target.global_position + Vector2(0, -14))
			weapon.try_fire()
			_fire_timer = fire_interval

func _on_entity_damaged(entity: Node, _amount: float, current_hp: float, max_hp: float, hit_dir: Vector2) -> void:
	if entity != self:
		return
	if hp_fill and max_hp > 0.0:
		hp_fill.size.x = 36.0 * clampf(current_hp / max_hp, 0.0, 1.0)
	if not _target:
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			_target = players[0] as Node2D
			_fire_timer = 0.9
	if hit_dir != Vector2.ZERO and sprite:
		sprite.flip_h = hit_dir.x > 0.0

func on_entity_died() -> void:
	_target = null
	if sprite:
		sprite.rotation_degrees = 90.0
		sprite.modulate = Color(0.55, 0.45, 0.45, 0.85)
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col:
		col.set_deferred("disabled", true)

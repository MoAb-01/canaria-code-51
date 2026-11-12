class_name HealthComponent
extends Node
## Universal Health, Hit-Flash & Damaged Sprite Component.
## Attachable to any character, guard, or destructible prop.

@export var max_health: float = 100.0
@export var damaged_texture: Texture2D
@export var target_sprite_path: NodePath
@export var knockback_strength: float = 110.0

var current_health: float = 100.0
var is_dead: bool = false
var is_damaged_state: bool = false

var _target_sprite: CanvasItem = null
var _flash_tween: Tween = null

func _ready() -> void:
	current_health = max_health
	if not target_sprite_path.is_empty():
		_target_sprite = get_node_or_null(target_sprite_path) as CanvasItem
	if not _target_sprite and get_parent():
		_target_sprite = get_parent().get_node_or_null("AnimatedSprite2D") as CanvasItem
		if not _target_sprite:
			_target_sprite = get_parent().get_node_or_null("Sprite2D") as CanvasItem

func take_damage(amount: float, hit_dir: Vector2 = Vector2.ZERO, _source: Node = null) -> bool:
	if is_dead or amount <= 0.0:
		return false

	var parent := get_parent()
	if _is_protected(parent, hit_dir):
		_spawn_deflect_spark(parent)
		return false

	current_health = maxf(0.0, current_health - amount)
	_apply_knockback(parent, hit_dir)
	_play_hit_flash()

	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("entity_damaged"):
		eb.entity_damaged.emit(parent, amount, current_health, max_health, hit_dir)

	if not is_damaged_state and current_health > 0.0 and current_health <= max_health * 0.5:
		_enter_damaged_state(parent)

	if current_health <= 0.0:
		_die(parent, eb)
	return true

func _is_protected(parent: Node, hit_dir: Vector2) -> bool:
	if not parent:
		return false
	for child in parent.get_children():
		if child.has_method("is_invulnerable") and child.is_invulnerable():
			return true
		if child.has_method("is_protected_from") and child.is_protected_from(hit_dir):
			return true
	return false

func _apply_knockback(parent: Node, hit_dir: Vector2) -> void:
	if parent is CharacterBody2D and hit_dir != Vector2.ZERO:
		parent.velocity += hit_dir.normalized() * knockback_strength

func _play_hit_flash() -> void:
	if not _target_sprite:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_target_sprite.modulate = Color(2.4, 0.35, 0.35, 1.0)
	var base_color := Color(0.95, 0.78, 0.78, 1.0) if (is_damaged_state and not damaged_texture) else Color.WHITE
	_flash_tween = create_tween()
	_flash_tween.tween_property(_target_sprite, "modulate", base_color, 0.12)

func _enter_damaged_state(parent: Node) -> void:
	is_damaged_state = true
	if _target_sprite is Sprite2D and damaged_texture:
		(_target_sprite as Sprite2D).texture = damaged_texture
	if parent and parent.has_method("on_damaged_state_entered"):
		parent.on_damaged_state_entered()

func _die(parent: Node, eb: Node) -> void:
	is_dead = true
	if eb and eb.has_signal("entity_died"):
		eb.entity_died.emit(parent)
	if parent and parent.has_method("on_entity_died"):
		parent.on_entity_died()
	elif _target_sprite:
		_target_sprite.modulate = Color(0.45, 0.35, 0.35, 0.75)
		_target_sprite.rotation_degrees = 90.0

func _spawn_deflect_spark(parent: Node) -> void:
	if not (parent is Node2D) or not parent.get_parent():
		return
	var spark := CPUParticles2D.new()
	spark.global_position = (parent as Node2D).global_position + Vector2(0, -14)
	spark.emitting = true
	spark.one_shot = true
	spark.explosiveness = 1.0
	spark.amount = 6
	spark.lifetime = 0.18
	spark.spread = 180.0
	spark.initial_velocity_min = 60.0
	spark.initial_velocity_max = 120.0
	spark.scale_amount_min = 2.0
	spark.scale_amount_max = 3.0
	spark.color = Color(0.85, 0.95, 1.0, 1.0)
	parent.get_parent().add_child(spark)
	spark.finished.connect(spark.queue_free)

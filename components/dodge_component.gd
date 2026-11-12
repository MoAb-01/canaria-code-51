class_name DodgeComponent
extends Node
## Reusable Tactical Dodge Roll Component.
## Grants i-frames, applies burst velocity, spawns pixel dust, and plays roll animation.

signal dodge_started(direction: Vector2)
signal dodge_finished()

@export var dodge_speed: float = 350.0
@export var dodge_duration: float = 0.22
@export var dodge_cooldown: float = 0.55
@export var invuln_duration: float = 0.24

var is_dodging: bool = false
var _dodge_dir: Vector2 = Vector2.RIGHT
var _dodge_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _invuln_timer: float = 0.0

func _physics_process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
	if _invuln_timer > 0.0:
		_invuln_timer = maxf(0.0, _invuln_timer - delta)

	if not is_dodging:
		return

	_dodge_timer -= delta
	var body := get_parent() as CharacterBody2D
	if body:
		body.velocity = _dodge_dir * dodge_speed

	if _dodge_timer <= 0.0:
		is_dodging = false
		if body:
			body.velocity = _dodge_dir * (dodge_speed * 0.35)
		dodge_finished.emit()

func is_invulnerable() -> bool:
	return is_dodging or _invuln_timer > 0.0

func try_dodge(move_dir: Vector2) -> bool:
	if is_dodging or _cooldown_timer > 0.0:
		return false

	var body := get_parent() as CharacterBody2D
	if not body:
		return false

	var dir := move_dir.normalized()
	if dir == Vector2.ZERO:
		dir = body.last_facing_dir if "last_facing_dir" in body else Vector2.DOWN

	_dodge_dir = dir
	is_dodging = true
	_dodge_timer = dodge_duration
	_cooldown_timer = dodge_cooldown
	_invuln_timer = invuln_duration
	body.velocity = _dodge_dir * dodge_speed

	_play_dodge_anim(body)
	_spawn_dust_puff(body)
	dodge_started.emit(_dodge_dir)
	return true

func _play_dodge_anim(body: Node) -> void:
	var sprite := body.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if not sprite or not sprite.sprite_frames:
		return
	if absf(_dodge_dir.x) > 0.1:
		sprite.flip_h = _dodge_dir.x < 0.0
	if sprite.sprite_frames.has_animation("dodge_roll"):
		sprite.play("dodge_roll")

func _spawn_dust_puff(body: Node2D) -> void:
	if not body.get_parent():
		return
	var dust := CPUParticles2D.new()
	dust.global_position = body.global_position + Vector2(0, -4)
	dust.emitting = true
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.amount = 7
	dust.lifetime = 0.28
	dust.direction = -_dodge_dir
	dust.spread = 45.0
	dust.initial_velocity_min = 35.0
	dust.initial_velocity_max = 75.0
	dust.scale_amount_min = 3.0
	dust.scale_amount_max = 5.0
	dust.color = Color(0.76, 0.78, 0.82, 0.75)
	body.get_parent().add_child(dust)
	dust.finished.connect(dust.queue_free)

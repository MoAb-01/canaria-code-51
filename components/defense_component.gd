class_name DefenseComponent
extends Node
## Modular Standing Defense Component.
## Manages block raise transition (Frame 0), sustained guard hold (Frame 1),
## directional deflect arc validation, and 0.12s impact brace override + knockback (Frame 2).

const RAISE_DURATION: float = 0.08
const LOWER_DURATION: float = 0.08
const IMPACT_BRACE_DURATION: float = 0.12
const DEFLECT_KNOCKBACK: float = 95.0
const FRONT_SIDE_DOT_MAX: float = 0.15

var is_blocking: bool = false
var _is_lowering: bool = false
var _raise_timer: float = 0.0
var _lower_timer: float = 0.0
var _impact_timer: float = 0.0

func start_block(dir_suffix: String, sprite: AnimatedSprite2D) -> void:
	is_blocking = true
	_is_lowering = false
	_raise_timer = RAISE_DURATION
	_lower_timer = 0.0
	_impact_timer = 0.0
	sync_sprite(dir_suffix, sprite)

func stop_block() -> void:
	is_blocking = false
	_is_lowering = false
	_raise_timer = 0.0
	_lower_timer = 0.0
	_impact_timer = 0.0

func begin_lower(dir_suffix: String, sprite: AnimatedSprite2D) -> void:
	if not is_blocking or _is_lowering:
		return
	_is_lowering = true
	_lower_timer = LOWER_DURATION
	_raise_timer = 0.0
	_impact_timer = 0.0
	sync_sprite(dir_suffix, sprite)

func resume_guard(dir_suffix: String, sprite: AnimatedSprite2D) -> void:
	if not is_blocking:
		return
	_is_lowering = false
	_lower_timer = 0.0
	sync_sprite(dir_suffix, sprite)

func handle_hold_input(held: bool, dir_suffix: String, sprite: AnimatedSprite2D) -> void:
	if not is_blocking:
		return
	if not held:
		begin_lower(dir_suffix, sprite)
	elif _is_lowering:
		resume_guard(dir_suffix, sprite)

func is_lowering() -> bool:
	return is_blocking and _is_lowering

func is_in_impact() -> bool:
	return is_blocking and _impact_timer > 0.0

## Returns true when blocking and incoming hit_dir lies within Tarek's front/side 180-degree arc.
func can_deflect(hit_dir: Vector2, facing_dir: Vector2) -> bool:
	if not is_blocking:
		return false
	if hit_dir == Vector2.ZERO or facing_dir == Vector2.ZERO:
		return true
	return hit_dir.normalized().dot(facing_dir.normalized()) <= FRONT_SIDE_DOT_MAX

## Triggers the 0.12s Impact Brace frame override (Frame 2) and applies light knockback.
func trigger_deflect_impact(hit_dir: Vector2, body: CharacterBody2D, facing_dir: Vector2, dir_suffix: String, sprite: AnimatedSprite2D) -> void:
	if not is_blocking:
		return
	_is_lowering = false
	_lower_timer = 0.0
	_impact_timer = IMPACT_BRACE_DURATION
	_raise_timer = 0.0
	if body:
		var push_dir := hit_dir.normalized() if hit_dir != Vector2.ZERO else -facing_dir.normalized()
		body.velocity += push_dir * DEFLECT_KNOCKBACK
	sync_sprite(dir_suffix, sprite)

func process_block(delta: float, dir_suffix: String, sprite: AnimatedSprite2D) -> void:
	if not is_blocking:
		return
	if _impact_timer > 0.0:
		_impact_timer = maxf(0.0, _impact_timer - delta)
	elif _is_lowering:
		_lower_timer -= delta
		if _lower_timer <= 0.0:
			stop_block()
			return
	elif _raise_timer > 0.0:
		_raise_timer = maxf(0.0, _raise_timer - delta)
	sync_sprite(dir_suffix, sprite)

func sync_sprite(dir_suffix: String, sprite: AnimatedSprite2D) -> void:
	if not is_blocking or not sprite or not sprite.sprite_frames:
		return
	var anim_name := "defend_" + dir_suffix
	var played := anim_name if sprite.sprite_frames.has_animation(anim_name) else ("defend" if sprite.sprite_frames.has_animation("defend") else "")
	if played.is_empty():
		return
	if sprite.animation != played:
		sprite.animation = played
	sprite.pause()
	var max_frame := maxi(0, sprite.sprite_frames.get_frame_count(played) - 1)
	if _impact_timer > 0.0:
		sprite.frame = mini(2, max_frame)
	elif _raise_timer > 0.0 or _is_lowering:
		sprite.frame = 0
	else:
		sprite.frame = mini(1, max_frame)

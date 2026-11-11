class_name Player
extends "res://entities/base_character.gd"
## Unified Player Controller (Tariq).
## Handles Locomotion, Stealth Crouch, Pseudo-Z Jump, Combat, Cargo Push/Pull, and Flashlight.

# Motion Tuning
@export var walk_speed: float = 180.0
@export var sneak_speed: float = 80.0
@export var sprint_speed: float = 270.0
@export var accel_rate: float = 1400.0
@export var friction_rate: float = 1800.0

# Vertical Height Physics
@export var jump_impulse: float = 285.0
@export var pseudo_gravity: float = 900.0

var z_pos: float = 0.0
var z_velocity: float = 0.0

enum State { NORMAL, CROUCH, JUMP, COMBAT, GRAB }
var current_state: State = State.NORMAL

# Light & Cargo State
@export var has_flashlight: bool = true
var grabbed_object: Node2D = null
var _grab_offset: Vector2 = Vector2.ZERO
var interaction_cooldown: float = 0.0
var flashlight_on: bool = false
var _nearby_interactables: Array[Area2D] = []

# Sub-Node References
@onready var interaction_ray: RayCast2D = $InteractionRay if has_node("InteractionRay") else null
@onready var interaction_detector: Area2D = $InteractionDetector if has_node("InteractionDetector") else null
@onready var flashlight_pivot: Node2D = $FlashlightPivot if has_node("FlashlightPivot") else null
@onready var flashlight_cone: PointLight2D = $FlashlightPivot/FlashlightCone if has_node("FlashlightPivot/FlashlightCone") else null
@onready var flashlight_spill: PointLight2D = $FlashlightPivot/FlashlightSpill if has_node("FlashlightPivot/FlashlightSpill") else null
@onready var flashlight_audio: AudioStreamPlayer2D = $FlashlightAudio if has_node("FlashlightAudio") else null

const BASE_VISUAL_Y: float = -14.0
const RAY_LENGTH: float = 54.0

func _ready() -> void:
	super._ready()
	if interaction_ray:
		interaction_ray.target_position = last_facing_dir * RAY_LENGTH
		direction_changed.connect(func(dir): interaction_ray.target_position = dir * RAY_LENGTH)
	_update_light_visibility()
	_update_visuals()

	if interaction_detector:
		interaction_detector.area_entered.connect(func(a):
			if a not in _nearby_interactables:
				_nearby_interactables.append(a)
				var p = a.get_parent()
				if p and p.has_method("set_prompt_visible"): p.set_prompt_visible(true)
		)
		interaction_detector.area_exited.connect(func(a):
			_nearby_interactables.erase(a)
			var p = a.get_parent()
			if p and p.has_method("set_prompt_visible"): p.set_prompt_visible(false)
		)

	var dl = get_node_or_null("/root/DialogueLayer")
	if dl:
		dl.dialogue_finished.connect(func():
			for a in _nearby_interactables:
				if is_instance_valid(a) and a.get_parent() and a.get_parent().has_method("set_prompt_visible"):
					a.get_parent().set_prompt_visible(true)
		)

func _character_process(delta: float) -> void:
	if interaction_cooldown > 0.0:
		interaction_cooldown -= delta

	var dl = get_node_or_null("/root/DialogueLayer")
	if dl and dl.is_dialogue_open:
		interaction_cooldown = 0.35
		velocity = velocity.move_toward(Vector2.ZERO, friction_rate * delta)
		move_and_slide()
		sprite.play(("flashlight_idle_" if flashlight_on else "idle_") + _get_dir_suffix())
		return

	_handle_actions()
	_update_z_physics(delta)
	_apply_movement(delta)
	_update_visuals()
	move_and_slide()

	if current_state == State.GRAB and is_instance_valid(grabbed_object):
		grabbed_object.global_position = (global_position + _grab_offset).round()

func _handle_actions() -> void:
	if current_state == State.JUMP:
		return

	if has_flashlight and Input.is_action_just_pressed("toggle_flashlight"):
		if current_state in [State.COMBAT, State.GRAB]:
			_release_grab()
			current_state = State.NORMAL
		_toggle_flashlight()

	if interaction_cooldown <= 0.0 and Input.is_action_just_pressed("interact"):
		if current_state == State.GRAB:
			_release_grab()
			interaction_cooldown = 0.2
			return
		var pushable = _get_pushable_target()
		if pushable:
			_start_grab(pushable)
			interaction_cooldown = 0.2
			if flashlight_on: _toggle_flashlight()
			return
		else:
			interaction_cooldown = 0.35
			_interact_with_target()
			return

	if current_state == State.GRAB:
		if not is_instance_valid(grabbed_object): _release_grab()
		return

	if Input.is_action_just_pressed("attack") and current_state != State.COMBAT:
		current_state = State.COMBAT
		if flashlight_on: _toggle_flashlight()
		_play_combat_anim("punch")
		return
	elif Input.is_action_just_pressed("defend") and current_state != State.COMBAT:
		current_state = State.COMBAT
		if flashlight_on: _toggle_flashlight()
		_play_combat_anim("defend")
		return

	if current_state == State.COMBAT:
		return

	if Input.is_action_just_pressed("jump") and current_state != State.CROUCH:
		current_state = State.JUMP
		z_velocity = jump_impulse
		if sprite: sprite.frame = 0
		set_collision_mask_value(3, false)
		_update_light_visibility()
		return

	var crouching := Input.is_action_pressed("stealth_crouch") or Input.is_action_pressed("crouch")
	current_state = State.CROUCH if crouching else State.NORMAL

func _apply_movement(delta: float) -> void:
	var input_vec := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target_speed := walk_speed

	match current_state:
		State.CROUCH: target_speed = sneak_speed
		State.GRAB: target_speed = walk_speed * 0.45
		State.COMBAT: target_speed = 0.0
		State.NORMAL:
			if Input.is_action_pressed("speed_sprint") or Input.is_action_pressed("sprint"):
				target_speed = sprint_speed
		State.JUMP: target_speed = walk_speed * 1.05

	if input_vec != Vector2.ZERO and current_state != State.COMBAT:
		if current_state != State.GRAB:
			if absf(input_vec.x) > absf(input_vec.y):
				last_facing_dir = Vector2.RIGHT if input_vec.x > 0.0 else Vector2.LEFT
			else:
				last_facing_dir = Vector2.DOWN if input_vec.y > 0.0 else Vector2.UP
		else:
			input_vec = Vector2(signf(input_vec.x), 0.0) if last_facing_dir.x != 0.0 else Vector2(0.0, signf(input_vec.y))
		velocity = velocity.move_toward(input_vec * target_speed, accel_rate * delta)
	else:
		var friction := friction_rate * (0.35 if current_state == State.JUMP else 1.0)
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

func _update_z_physics(delta: float) -> void:
	if current_state == State.JUMP:
		z_velocity -= pseudo_gravity * delta
		z_pos += z_velocity * delta
		if z_velocity <= 0.0 and z_pos <= 0.0:
			z_pos = 0.0
			z_velocity = 0.0
			var crouching := Input.is_action_pressed("stealth_crouch") or Input.is_action_pressed("crouch")
			current_state = State.CROUCH if crouching else State.NORMAL
			set_collision_mask_value(3, true)
			_update_light_visibility()

func _get_dir_suffix() -> String:
	if last_facing_dir == Vector2.UP:
		if sprite: sprite.flip_h = false
		return "up"
	elif last_facing_dir == Vector2.DOWN:
		if sprite: sprite.flip_h = false
		return "down"
	if sprite:
		sprite.flip_h = (last_facing_dir == Vector2.LEFT)
	return "side"

func _update_visuals() -> void:
	_update_light_orientation()
	_update_light_visibility()
	if not sprite: return

	sprite.position.y = BASE_VISUAL_Y - z_pos
	if shadow:
		var size := clampf(1.0 - (z_pos / 45.0) * 0.4, 0.6, 1.0)
		shadow.scale = Vector2(size, size)

	if current_state == State.COMBAT: return

	var dir := _get_dir_suffix()
	var moving := velocity.length() > 2.0

	if current_state == State.GRAB:
		sprite.play(("push_" if velocity.dot(last_facing_dir) > 0.0 else "pull_") + dir if moving else "grab_still_" + dir)
		return

	if flashlight_on:
		if current_state == State.CROUCH:
			sprite.play("flashlight_crouch_" + dir)
			if not moving: sprite.pause(); sprite.frame = 0
		elif current_state == State.JUMP:
			sprite.play("jump_" + dir)
		else:
			sprite.play(("flashlight_walk_" if moving else "flashlight_idle_") + dir)
		return

	match current_state:
		State.CROUCH: sprite.play(("crouch_walk_" if moving else "crouch_idle_") + dir)
		State.JUMP: sprite.play("jump_" + dir)
		State.NORMAL: sprite.play(("walk_" if moving else "idle_") + dir)

func _play_combat_anim(anim_prefix: String) -> void:
	velocity = Vector2.ZERO
	var anim_name := anim_prefix + "_" + _get_dir_suffix()
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
		await sprite.animation_finished
	elif sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_prefix):
		sprite.play(anim_prefix)
		await sprite.animation_finished
	if current_state == State.COMBAT:
		current_state = State.NORMAL

func _start_grab(target: Node2D) -> void:
	_release_grab()
	grabbed_object = target
	if grabbed_object:
		_grab_offset = grabbed_object.global_position - global_position
		if grabbed_object is PhysicsBody2D: add_collision_exception_with(grabbed_object)
	current_state = State.GRAB

func _release_grab() -> void:
	if is_instance_valid(grabbed_object) and grabbed_object is PhysicsBody2D:
		remove_collision_exception_with(grabbed_object)
	grabbed_object = null
	if current_state == State.GRAB: current_state = State.NORMAL

func _get_pushable_target() -> Node2D:
	if interaction_ray:
		interaction_ray.force_raycast_update()
		if interaction_ray.is_colliding():
			var col = interaction_ray.get_collider()
			if col and col.is_in_group("pushable"): return col as Node2D
			if col and col.get_parent() and col.get_parent().is_in_group("pushable"): return col.get_parent() as Node2D
	return null

func _toggle_flashlight() -> void:
	flashlight_on = !flashlight_on
	if flashlight_audio:
		flashlight_audio.pitch_scale = randf_range(1.04, 1.08) if flashlight_on else randf_range(0.94, 0.98)
		flashlight_audio.play()
	_update_light_visibility()

func _update_light_visibility() -> void:
	var active: bool = flashlight_on and (current_state != State.JUMP)
	if flashlight_cone: flashlight_cone.enabled = active
	if flashlight_spill: flashlight_spill.enabled = active

func _update_light_orientation() -> void:
	if not flashlight_pivot: return
	var rot := 0.0
	if last_facing_dir == Vector2.DOWN: rot = 90.0
	elif last_facing_dir == Vector2.LEFT: rot = 180.0
	elif last_facing_dir == Vector2.UP: rot = 270.0
	flashlight_pivot.rotation_degrees = rot

func _interact_with_target() -> void:
	_nearby_interactables = _nearby_interactables.filter(func(a): return is_instance_valid(a))
	for a in _nearby_interactables:
		var target = a.get_parent() if a.get_parent().has_method("interact") else a
		if target.has_method("interact"): target.interact(self); return

	if interaction_ray and interaction_ray.is_colliding():
		var col = interaction_ray.get_collider()
		if col:
			var target = col.get_parent() if (col is Area2D and col.get_parent().has_method("interact")) else col
			if target.has_method("interact"): target.interact(self)

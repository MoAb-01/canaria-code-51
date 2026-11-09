extends CharacterBody2D
## Tariq — top-down (Stardew-style) deck controller with a pseudo-Z jump.
## The body's origin sits at Tariq's boots so a Y-sorted parent layers him
## correctly against deck props. Only the AnimatedSprite2D is lifted on jump.

enum State { IDLE, WALK, CROUCH, JUMP }

const WALK_SPEED: float = 180.0
const CROUCH_SPEED: float = 80.0
const ACCEL: float = 1400.0
const FRICTION: float = 1800.0

const JUMP_VELOCITY: float = 285.0  # initial upward pseudo-Z speed (px/s) -> ~45 px apex
const Z_GRAVITY: float = 900.0
const BASE_VISUAL_Y: float = 0.0

var current_state: State = State.IDLE
var last_facing_dir: Vector2 = Vector2.DOWN
var z_pos: float = 0.0
var z_velocity: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shadow: Node2D = $Shadow

func _ready() -> void:
	_ensure_input_actions()
	_update_visuals()

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var wants_crouch := Input.is_action_pressed("crouch")

	# --- State transitions ---
	if current_state == State.JUMP:
		z_velocity -= Z_GRAVITY * delta
		z_pos += z_velocity * delta
		if z_pos <= 0.0:
			z_pos = 0.0
			z_velocity = 0.0
			current_state = State.IDLE
	elif Input.is_action_just_pressed("jump"):
		current_state = State.JUMP
		z_velocity = JUMP_VELOCITY
		sprite.frame = 0
	elif wants_crouch:
		current_state = State.CROUCH
	else:
		current_state = State.WALK if input_dir != Vector2.ZERO else State.IDLE

	# --- Horizontal (deck-plane) movement ---
	var max_speed := CROUCH_SPEED if current_state == State.CROUCH else WALK_SPEED
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * max_speed, ACCEL * delta)
		last_facing_dir = _to_cardinal(input_dir)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

	move_and_slide()
	_update_visuals()

# Inside _update_visuals() on your script, map back to standard Stardew direction cycles
func _update_visuals() -> void:
	# Keep pseudo-Z visual jump lifting
	$AnimatedSprite2D.position.y = BASE_VISUAL_Y - z_pos

	# Drop/grow shadows
	if shadow:
		var s = clamp(1.0 - (z_pos / 45.0) * 0.4, 0.6, 1.0)
		shadow.scale = Vector2(s, s)

	# Calculate animation direction
	var dir_suffix := "down"
	if last_facing_dir == Vector2.UP:
		$AnimatedSprite2D.flip_h = false
		dir_suffix = "up"
	elif last_facing_dir == Vector2.DOWN:
		$AnimatedSprite2D.flip_h = false
		dir_suffix = "down"
	else:
		$AnimatedSprite2D.flip_h = (last_facing_dir == Vector2.LEFT)
		dir_suffix = "side"

	# Play states
	if current_state == State.JUMP:
		$AnimatedSprite2D.play("jump_" + dir_suffix)
	elif current_state == State.CROUCH:
		var moving = velocity.length() > 2.0
		$AnimatedSprite2D.play("crouch_walk_" + dir_suffix if moving else "crouch_idle_" + dir_suffix)
	else:
		var moving = velocity.length() > 2.0
		$AnimatedSprite2D.play("walk_" + dir_suffix if moving else "idle_" + dir_suffix)

## Snap an analog/diagonal vector to the dominant cardinal direction.
func _to_cardinal(v: Vector2) -> Vector2:
	if absf(v.x) > absf(v.y):
		return Vector2.RIGHT if v.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if v.y > 0.0 else Vector2.UP

## Registers WASD/arrows, Space (jump) and Ctrl/C (crouch) if the project
## doesn't define these actions yet, keeping the scene drop-in ready.
func _ensure_input_actions() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE],
		"crouch": [KEY_CTRL, KEY_C],
	}
	for action in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in bindings[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


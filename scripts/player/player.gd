extends CharacterBody2D

const SPEED: float = 340.0
const JUMP_VELOCITY: float = -540.0
const SWIM_JUMP_VELOCITY: float = -280.0
const CLIMB_SPEED: float = 220.0
const GRAVITY: float = 1200.0
const WATER_GRAVITY: float = 280.0
const WATER_DAMPING: float = 0.85

var is_on_ladder: bool = false
var is_in_water: bool = false
var coyote_timer: float = 0.0
const COYOTE_TIME: float = 0.12

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _physics_process(delta: float) -> void:
	var input_x: float = Input.get_axis("ui_left", "ui_right")
	var input_y: float = Input.get_axis("ui_up", "ui_down")
	
	# Horizontal sprite facing
	if input_x > 0:
		sprite.flip_h = false
	elif input_x < 0:
		sprite.flip_h = true

	# 1. Ladder Climbing Mechanics
	if is_on_ladder:
		velocity.y = input_y * CLIMB_SPEED
		velocity.x = input_x * (SPEED * 0.6)
		move_and_slide()
		return

	# 2. Water Physics (Buoyancy & Swimming)
	if is_in_water:
		velocity.y += WATER_GRAVITY * delta
		velocity.x = lerp(velocity.x, input_x * (SPEED * 0.7), 0.15)
		
		# Swim stroke with Jump or Up
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up"):
			velocity.y = SWIM_JUMP_VELOCITY
			
		velocity.y = clampf(velocity.y, -400.0, 220.0) # gentle terminal sink rate
		move_and_slide()
		return

	# 3. Standard Platformer Mechanics (Deck & Tower)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
		coyote_timer -= delta
	else:
		coyote_timer = COYOTE_TIME

	# Jump handling
	if (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")) and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0.0

	# Variable jump height (releasing jump button cuts upward boost)
	if (Input.is_action_just_released("ui_accept") or Input.is_action_just_released("ui_up")) and velocity.y < -150.0:
		velocity.y = -150.0

	# Ground movement
	if input_x != 0.0:
		velocity.x = move_toward(velocity.x, input_x * SPEED, 1800.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)

	move_and_slide()


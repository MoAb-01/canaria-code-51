class_name CoverDetectorComponent
extends Node2D
## Tactical Low-Cover Detection & Peek-Shoot Stance Component.
## Detects nearby "low_cover" objects, shields against frontal shots while crouched,
## and handles automatic pop-up peeking when firing.

signal cover_state_changed(is_crouching: bool, is_peeking: bool, near_cover: bool)

const PEEK_HOLD_DURATION: float = 0.25

@export var detect_radius: float = 56.0

var is_crouching: bool = false
var is_peeking: bool = false

var _nearby_cover: Array[Node2D] = []
var _peek_timer: float = 0.0
var _detect_area: Area2D = null

func _ready() -> void:
	_setup_detector_area()

func _process(delta: float) -> void:
	if is_peeking:
		_peek_timer -= delta
		if _peek_timer <= 0.0:
			end_peek()

func _setup_detector_area() -> void:
	_detect_area = get_node_or_null("CoverArea") as Area2D
	if not _detect_area:
		_detect_area = Area2D.new()
		_detect_area.name = "CoverArea"
		_detect_area.collision_layer = 0
		_detect_area.collision_mask = 6
		_detect_area.monitorable = false
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = detect_radius
		col.shape = shape
		_detect_area.add_child(col)
		add_child(_detect_area)

	_detect_area.body_entered.connect(_on_cover_entered)
	_detect_area.body_exited.connect(_on_cover_exited)
	_detect_area.area_entered.connect(_on_cover_entered)
	_detect_area.area_exited.connect(_on_cover_exited)

func _on_cover_entered(node: Node) -> void:
	if node is Node2D and node.is_in_group("low_cover") and node not in _nearby_cover:
		_nearby_cover.append(node)
		cover_state_changed.emit(is_crouching, is_peeking, is_near_cover())

func _on_cover_exited(node: Node) -> void:
	if node in _nearby_cover:
		_nearby_cover.erase(node)
		cover_state_changed.emit(is_crouching, is_peeking, is_near_cover())

func is_near_cover() -> bool:
	_nearby_cover = _nearby_cover.filter(func(n): return is_instance_valid(n))
	return not _nearby_cover.is_empty()

func get_nearest_cover() -> Node2D:
	_nearby_cover = _nearby_cover.filter(func(n): return is_instance_valid(n))
	if _nearby_cover.is_empty():
		return null
	var nearest: Node2D = _nearby_cover[0]
	var min_dist := global_position.distance_squared_to(nearest.global_position)
	for c in _nearby_cover:
		var d := global_position.distance_squared_to(c.global_position)
		if d < min_dist:
			min_dist = d
			nearest = c
	return nearest

func get_cover_direction() -> Vector2:
	var cover := get_nearest_cover()
	if not cover:
		return Vector2.ZERO
	return (cover.global_position - global_position).normalized()

func toggle_crouch() -> void:
	set_crouching(not is_crouching)

func set_crouching(active: bool) -> void:
	if is_crouching == active:
		return
	is_crouching = active
	if not is_crouching:
		is_peeking = false
		_peek_timer = 0.0
	cover_state_changed.emit(is_crouching, is_peeking, is_near_cover())

func start_peek() -> void:
	if not is_crouching:
		return
	is_peeking = true
	_peek_timer = PEEK_HOLD_DURATION
	cover_state_changed.emit(is_crouching, is_peeking, is_near_cover())

func end_peek() -> void:
	if not is_peeking:
		return
	is_peeking = false
	_peek_timer = 0.0
	cover_state_changed.emit(is_crouching, is_peeking, is_near_cover())

func is_protected_from(hit_dir: Vector2) -> bool:
	if not is_crouching or is_peeking or not is_near_cover():
		return false
	if hit_dir == Vector2.ZERO:
		return true
	var cover_dir := get_cover_direction()
	if cover_dir == Vector2.ZERO:
		return false
	# Bullet travels toward character; if opposite to cover_dir, cover is between shooter and character
	return hit_dir.normalized().dot(cover_dir) < 0.35

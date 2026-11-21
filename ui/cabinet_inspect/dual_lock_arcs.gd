class_name DualLockArcs
extends Control
## Procedural narrow dual semi-circular progress arcs with smooth tap-to-fill (K -> J)
## mechanics, gentle spring-back decay, and label scale punch feedback.

signal right_arc_completed
signal left_arc_completed
signal progress_changed(side: String, progress: float)

const TRACK_COLOR := Color(0.10, 0.09, 0.09, 0.82)
const FILL_COLOR := Color(0.902, 0.722, 0.416, 1.0)
const ACTIVE_TEXT_COLOR := Color(0.902, 0.722, 0.416, 1.0)
const IDLE_TEXT_COLOR := Color(0.968627, 0.945098, 0.901961, 0.85)
const ARC_WIDTH := 8.0
const ARC_RADIUS := 54.0
const ARC_POINTS := 48

@export var tap_increment: float = 0.22
@export var decay_rate: float = 0.10
@export var smooth_speed: float = 14.0

var right_target: float = 0.0
var right_progress: float = 0.0
var left_target: float = 0.0
var left_progress: float = 0.0

var _active_side: String = ""
var _right_done: bool = false
var _left_done: bool = false
var _label_j: Label = null
var _label_k: Label = null
var _punch_tween: Tween = null

func _ready() -> void:
	custom_minimum_size = Vector2(220, 140)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_j = _make_key_label("LabelJ", "J", Vector2(10, 50))
	_label_k = _make_key_label("LabelK", "K", Vector2(178, 50))
	_update_label_colors()

func _make_key_label(node_name: String, key_text: String, pos: Vector2) -> Label:
	var lbl := Label.new()
	lbl.name = node_name; lbl.text = key_text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.position = pos; lbl.size = Vector2(32, 40)
	lbl.pivot_offset = lbl.size * 0.5
	add_child(lbl)
	return lbl

func reset_arcs() -> void:
	right_target = 0.0; right_progress = 0.0; _right_done = false
	left_target = 0.0; left_progress = 0.0; _left_done = false
	_active_side = "right"
	if _label_j: _label_j.scale = Vector2.ONE
	if _label_k: _label_k.scale = Vector2.ONE
	_update_label_colors()
	queue_redraw()

func set_active_side(side: String) -> void:
	_active_side = side
	_update_label_colors()
	queue_redraw()

func add_right_tap() -> void:
	if _active_side != "right" or _right_done:
		return
	right_target = clampf(right_target + tap_increment, 0.0, 1.0)
	_punch_label(_label_k)

func add_left_tap() -> void:
	if _active_side != "left" or _left_done:
		return
	left_target = clampf(left_target + tap_increment, 0.0, 1.0)
	_punch_label(_label_j)

func _process(delta: float) -> void:
	if not visible:
		return
	var step := clampf(smooth_speed * delta, 0.0, 1.0)
	if _active_side == "right" and not _right_done:
		if right_target < 1.0:
			right_target = maxf(0.0, right_target - decay_rate * delta)
		right_progress = lerpf(right_progress, right_target, step)
		if right_progress >= 0.99:
			right_progress = 1.0; right_target = 1.0; _right_done = true
			_active_side = "left"; _update_label_colors()
			progress_changed.emit("right", 1.0)
			right_arc_completed.emit()
		else:
			progress_changed.emit("right", right_progress)
		queue_redraw()
	elif _active_side == "left" and not _left_done:
		if left_target < 1.0:
			left_target = maxf(0.0, left_target - decay_rate * delta)
		left_progress = lerpf(left_progress, left_target, step)
		if left_progress >= 0.99:
			left_progress = 1.0; left_target = 1.0; _left_done = true
			_active_side = ""; _update_label_colors()
			progress_changed.emit("left", 1.0)
			left_arc_completed.emit()
		else:
			progress_changed.emit("left", left_progress)
		queue_redraw()

func _punch_label(lbl: Label) -> void:
	if not lbl:
		return
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()
	lbl.scale = Vector2.ONE
	_punch_tween = create_tween()
	_punch_tween.tween_property(lbl, "scale", Vector2(1.22, 1.22), 0.045)
	_punch_tween.tween_property(lbl, "scale", Vector2.ONE, 0.045)

func _update_label_colors() -> void:
	if _label_j:
		_label_j.add_theme_color_override("font_color", ACTIVE_TEXT_COLOR if _active_side == "left" else IDLE_TEXT_COLOR)
	if _label_k:
		_label_k.add_theme_color_override("font_color", ACTIVE_TEXT_COLOR if _active_side == "right" else IDLE_TEXT_COLOR)

func _draw() -> void:
	var center := size * 0.5
	var r_start := -PI * 0.38
	var r_end := PI * 0.38
	draw_arc(center, ARC_RADIUS, r_start, r_end, ARC_POINTS, TRACK_COLOR, ARC_WIDTH, true)
	if right_progress > 0.001:
		draw_arc(center, ARC_RADIUS, r_start, lerpf(r_start, r_end, right_progress), ARC_POINTS, FILL_COLOR, ARC_WIDTH, true)

	var l_start := PI * 1.38
	var l_end := PI * 0.62
	draw_arc(center, ARC_RADIUS, l_end, l_start, ARC_POINTS, TRACK_COLOR, ARC_WIDTH, true)
	if left_progress > 0.001:
		draw_arc(center, ARC_RADIUS, lerpf(l_start, l_end, left_progress), l_start, ARC_POINTS, FILL_COLOR, ARC_WIDTH, true)

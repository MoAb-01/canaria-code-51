class_name OptionsPanel
extends Control
## Reusable Options & Settings Panel.
## Controls Master, Music, SFX volumes, UI clicks, and Fullscreen display mode.
## Reads and persists settings centrally via SaveManager and emits EventBus signals.

signal closed

const TOTAL_ROWS: int = 6

var current_row: int = 0
var is_open: bool = false

@onready var master_val: Label = $VBox/MasterRow/ValueLabel
@onready var music_val: Label = $VBox/MusicRow/ValueLabel
@onready var sfx_val: Label = $VBox/SfxRow/ValueLabel
@onready var ui_click_val: Label = $VBox/UiClickRow/ValueLabel
@onready var display_val: Label = $VBox/DisplayRow/ValueLabel
@onready var back_btn: Button = $VBox/BackBtn

@onready var hover_sound: AudioStreamPlayer = $HoverSound if has_node("HoverSound") else null
@onready var click_sound: AudioStreamPlayer = $ClickSound if has_node("ClickSound") else null

var _rows: Array[Control] = []

func _ready() -> void:
	_rows = [
		$VBox/MasterRow,
		$VBox/MusicRow,
		$VBox/SfxRow,
		$VBox/UiClickRow,
		$VBox/DisplayRow,
		back_btn
	]
	_setup_interactions()
	_update_labels()
	
	var eb = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("settings_changed"):
		eb.settings_changed.connect(func(_k = "", _v = null): _update_labels())

func _setup_interactions() -> void:
	for i in range(_rows.size()):
		var row := _rows[i]
		var idx := i
		row.mouse_entered.connect(func():
			if visible and is_open:
				current_row = idx
				play_hover()
				_update_highlight()
		)
		if row is HBoxContainer:
			row.mouse_filter = Control.MOUSE_FILTER_STOP
			row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			for child in row.get_children():
				if child is Control:
					child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.gui_input.connect(func(event: InputEvent):
				if visible and is_open and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					current_row = idx
					_update_highlight()
					var dir: int = 1 if (idx in [3, 4] or event.position.x >= row.size.x * 0.5) else -1
					_adjust_setting(dir)
			)

	if back_btn:
		back_btn.pressed.connect(close)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not is_open:
		return

	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		var delta: int = -1 if event.is_action_pressed("ui_up") else 1
		current_row = posmod(current_row + delta, TOTAL_ROWS)
		play_hover()
		_update_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		var dir: int = -1 if event.is_action_pressed("ui_left") else 1
		_adjust_setting(dir)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if current_row == 5:
			close()
		elif current_row in [3, 4]:
			_adjust_setting(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	is_open = true
	current_row = 0
	_update_labels()
	_update_highlight()
	if back_btn:
		back_btn.grab_focus()

func close() -> void:
	if not is_open:
		return
	play_click()
	is_open = false
	visible = false
	closed.emit()

func _adjust_setting(dir: int) -> void:
	play_click()
	var sm = get_node_or_null("/root/SaveManager")
	if not sm:
		return

	match current_row:
		0: sm.set_setting("master_vol", sm.master_volume + (dir * 10))
		1: sm.set_setting("music_vol", sm.music_volume + (dir * 10))
		2: sm.set_setting("sfx_vol", sm.sfx_volume + (dir * 10))
		3: sm.set_setting("ui_clicks", !sm.ui_clicks_enabled)
		4: sm.set_setting("fullscreen", !sm.is_fullscreen)
	_update_labels()

func _update_highlight() -> void:
	for i in range(_rows.size()):
		_rows[i].modulate = Color("ff9a1f") if i == current_row else Color("e5edf5")

func _update_labels() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	var m_vol: int = sm.master_volume if sm else 80
	var mu_vol: int = sm.music_volume if sm else 100
	var s_vol: int = sm.sfx_volume if sm else 80
	var clicks: bool = sm.ui_clicks_enabled if sm else true
	var fs: bool = sm.is_fullscreen if sm else false

	if master_val: master_val.text = "<  %d%%  >" % m_vol
	if music_val: music_val.text = "<  %d%%  >" % mu_vol
	if sfx_val: sfx_val.text = "<  %d%%  >" % s_vol
	if ui_click_val: ui_click_val.text = "<  ON  >" if clicks else "<  OFF  >"
	if display_val: display_val.text = "< FULLSCREEN >" if fs else "< WINDOWED >"

func play_hover() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm and not sm.ui_clicks_enabled:
		return
	if hover_sound:
		hover_sound.play()

func play_click() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm and not sm.ui_clicks_enabled:
		return
	if click_sound:
		click_sound.play()

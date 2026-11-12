class_name PauseMenu
extends CanvasLayer
## Dual-Mode Pause Menu System.
## Handles normal gameplay pause with sliding maritime drawer,
## cutscene pause with minimal overlay, and embeds the shared OptionsPanel.

@onready var dim_overlay: ColorRect = $DimOverlay
@onready var cutscene_label: Label = $CutscenePauseLabel
@onready var sliding_panel: PanelContainer = $SlidingPanel
@onready var continue_btn: Button = $SlidingPanel/Margin/VBox/MenuButtons/ContinueBtn
@onready var options_btn: Button = $SlidingPanel/Margin/VBox/MenuButtons/OptionsBtn
@onready var main_menu_btn: Button = $SlidingPanel/Margin/VBox/MenuButtons/MainMenuBtn
@onready var options_panel: Control = $OptionsPanel

@onready var hover_sound: AudioStreamPlayer = $HoverSound if has_node("HoverSound") else null
@onready var click_sound: AudioStreamPlayer = $ClickSound if has_node("ClickSound") else null

var is_paused: bool = false
var _active_tween: Tween = null

const PANEL_WIDTH: float = 380.0
const PANEL_OPEN_X: float = 48.0
const PANEL_CLOSED_X: float = -420.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	
	dim_overlay.modulate.a = 0.0
	dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	cutscene_label.visible = false
	cutscene_label.modulate.a = 0.0
	
	sliding_panel.visible = false
	sliding_panel.position.x = PANEL_CLOSED_X
	
	if options_panel:
		options_panel.visible = false
		options_panel.closed.connect(_on_options_panel_closed)
		
	_connect_buttons()

func _connect_buttons() -> void:
	var btns = [continue_btn, options_btn, main_menu_btn]
	for btn in btns:
		if btn:
			btn.mouse_entered.connect(_play_hover)
			btn.focus_entered.connect(_play_hover)
			btn.focus_mode = Control.FOCUS_ALL

	if continue_btn:
		continue_btn.pressed.connect(_on_continue_pressed)
	if options_btn:
		options_btn.pressed.connect(_on_options_pressed)
	if main_menu_btn:
		main_menu_btn.pressed.connect(_on_main_menu_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") and not event.is_action_pressed("pause"):
		return

	var cs = get_tree().current_scene
	if cs:
		var path: String = str(cs.scene_file_path).to_lower()
		if path.contains("main_menu") or path.contains("teaser"):
			return

	if options_panel and options_panel.is_open:
		options_panel.close()
		get_viewport().set_input_as_handled()
		return

	if is_paused:
		resume()
	else:
		pause()
	get_viewport().set_input_as_handled()

func pause() -> void:
	if is_paused:
		return
	is_paused = true
	get_tree().paused = true
	
	dim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_kill_active_tween()
	
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw.tween_property(dim_overlay, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween = tw
	
	var in_cutscene: bool = GameState.is_cutscene_active if has_node("/root/GameState") else false
	
	if in_cutscene:
		sliding_panel.visible = false
		cutscene_label.visible = true
		tw.tween_property(cutscene_label, "modulate:a", 1.0, 0.18)
	else:
		cutscene_label.visible = false
		sliding_panel.visible = true
		tw.tween_property(sliding_panel, "position:x", PANEL_OPEN_X, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if continue_btn:
			continue_btn.grab_focus()
			
	var eb = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("game_paused"):
		eb.game_paused.emit(true, in_cutscene)

func resume() -> void:
	if not is_paused:
		return
	is_paused = false
	
	if options_panel and options_panel.is_open:
		options_panel.close()
		
	dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kill_active_tween()
	
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw.tween_property(dim_overlay, "modulate:a", 0.0, 0.15)
	
	if cutscene_label.visible:
		tw.tween_property(cutscene_label, "modulate:a", 0.0, 0.15)
		tw.chain().tween_callback(func(): cutscene_label.visible = false)
		
	if sliding_panel.visible:
		tw.tween_property(sliding_panel, "position:x", PANEL_CLOSED_X, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(func(): sliding_panel.visible = false)
		
	_active_tween = tw
	get_tree().paused = false
	
	var in_cutscene: bool = GameState.is_cutscene_active if has_node("/root/GameState") else false
	var eb = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("game_paused"):
		eb.game_paused.emit(false, in_cutscene)

func _on_continue_pressed() -> void:
	_play_click()
	resume()

func _on_options_pressed() -> void:
	_play_click()
	sliding_panel.visible = false
	if options_panel:
		options_panel.open()

func _on_options_panel_closed() -> void:
	if is_paused and not GameState.is_cutscene_active:
		sliding_panel.visible = true
		if options_btn:
			options_btn.grab_focus()

func _on_main_menu_pressed() -> void:
	_play_click()
	get_tree().paused = false
	is_paused = false
	var eb = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("game_paused"):
		eb.game_paused.emit(false, false)
	get_tree().change_scene_to_file("res://screens/main_menu/main_menu.tscn")

func _kill_active_tween() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

func _play_hover() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm and not sm.ui_clicks_enabled:
		return
	if hover_sound:
		hover_sound.play()

func _play_click() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm and not sm.ui_clicks_enabled:
		return
	if click_sound:
		click_sound.play()

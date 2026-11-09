extends Button

var target_x: float = 0.0
@onready var origin_x: float = position.x
var base_text: String = ""

func _ready() -> void:
	base_text = text.trim_prefix("> ")
	modulate = Color("eeeeee")
	mouse_entered.connect(_on_mouse_entered)
	focus_entered.connect(_on_hover)
	mouse_exited.connect(_on_blur)
	focus_exited.connect(_on_blur)

func _on_mouse_entered() -> void:
	grab_focus()
	_on_hover()

func _on_hover() -> void:
	var tw: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Highlight orange and display retro focus arrow ">"
	modulate = Color("ff9a1f")
	text = "> " + base_text
	# Hover offset 10px to right
	tw.tween_property(self, "position:x", origin_x + 10.0, 0.15)

func _on_blur() -> void:
	if has_focus():
		return
	var tw: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Back to off-white/light gray
	modulate = Color("eeeeee")
	text = base_text
	tw.tween_property(self, "position:x", origin_x, 0.15)

extends Node2D
## Test Deck Level Controller.
## Handles HUD notifications and stage coordination.

@onready var notification_label: Label = $HUD/NotificationBanner if has_node("HUD/NotificationBanner") else null

var _notif_tween: Tween = null

func _ready() -> void:
	var eb = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("notification_displayed"):
		eb.notification_displayed.connect(_on_notification_displayed)
	if notification_label:
		notification_label.modulate.a = 0.0

func _on_notification_displayed(message: String, duration: float) -> void:
	if not notification_label:
		return
	notification_label.text = message
	if _notif_tween and _notif_tween.is_valid():
		_notif_tween.kill()
	_notif_tween = create_tween()
	_notif_tween.tween_property(notification_label, "modulate:a", 1.0, 0.2)
	_notif_tween.tween_interval(duration)
	_notif_tween.tween_property(notification_label, "modulate:a", 0.0, 0.4)

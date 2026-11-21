extends Node
## UiTextGuard — Autoload that enforces TEXTURE_FILTER_LINEAR on all UI text controls
## so global default_texture_filter = 0 (Nearest) never pixelates UI typography.

func _ready() -> void:
	var tree := get_tree()
	if not tree:
		return
	_apply_recursive(tree.root)
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	_guard_node(node)

func _apply_recursive(node: Node) -> void:
	if not node:
		return
	_guard_node(node)
	for child in node.get_children():
		_apply_recursive(child)

func _guard_node(node: Node) -> void:
	if not (node is Label or node is RichTextLabel or node is Button or node is LinkButton):
		return
	if node.has_meta("keep_pixel_filter"):
		return
	(node as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

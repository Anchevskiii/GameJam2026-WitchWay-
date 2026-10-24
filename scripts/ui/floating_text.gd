class_name FloatingText
extends Label

## Pop-up text that floats up and fades out ("+18 GLITCH", "+5 SANITY", "WAAAH").
## Usage: FloatingText.spawn(self, global_position, "+18 GLITCH", Color.MAGENTA)


static func spawn(near: Node, at: Vector2, text_value: String, color: Color = Color.WHITE, font_size: int = 20) -> void:
	if near == null or not near.is_inside_tree():
		return
	var parent: Node = near.get_tree().get_first_node_in_group("prop_layer")
	if parent == null:
		parent = near.get_parent()
	var label := FloatingText.new()
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	label.material = unshaded
	label.text = text_value
	label.z_index = 40
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(200, 30)
	parent.add_child(label)
	label.global_position = at + Vector2(-100, -70)
	var tween: Tween = label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 30.0, 0.9)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tween.tween_callback(label.queue_free)

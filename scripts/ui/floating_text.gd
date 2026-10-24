class_name FloatingText
extends Label

## Pop-up text that floats up and fades out ("+18 GLITCH", "+5 SANITY", "BOO!").
## Always rendered UNSHADED so it remains 100% bright and readable in pitch blackness.

static var _unshaded_material: CanvasItemMaterial = null


static func _get_unshaded_material() -> CanvasItemMaterial:
	if _unshaded_material == null:
		_unshaded_material = CanvasItemMaterial.new()
		_unshaded_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded_material


static func spawn(near: Node, at: Vector2, text_value: String, color: Color = Color.WHITE, font_size: int = 15) -> void:
	if near == null or not near.is_inside_tree():
		return
	var parent: Node = near.get_tree().get_first_node_in_group("prop_layer")
	if parent == null:
		parent = near.get_parent()
	var label := FloatingText.new()
	label.material = _get_unshaded_material()
	label.text = text_value
	label.z_index = 80
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(180, 24)
	parent.add_child(label)
	label.global_position = at + Vector2(-90, -45)
	
	var tween: Tween = label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 24.0, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.5)
	tween.tween_callback(label.queue_free)

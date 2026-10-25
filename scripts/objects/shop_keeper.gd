extends Node2D

## A shop you open with E: the Merchant in the Living Room ("main" - full upgrade list) or a
## vending machine in the bright, monster-free room of every haunted floor ("vending" - flashlight,
## mask and glitch mode only, at a higher price).
## Created by Room (no scene file). The player picks it as an interaction target through the
## "shops" group: is_player_in_reach(), is_active_target and open_shop().

const SHOP_UI: Script = preload("res://scripts/ui/shop_ui.gd")
const MERCHANT_TINT: Color = Color(1.0, 0.82, 0.35)

## "main" (Merchant) or "vending" (vending machine).
var mode: String = "main"
## Sprite for the Merchant. Without one, a vending machine is drawn.
var texture: Texture2D = null
var reach: float = 58.0
var is_active_target: bool = false

var _player: Node2D = null
var _prompt: Label


func _ready() -> void:
	add_to_group("shops")
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	if texture != null:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.modulate = MERCHANT_TINT
		sprite.offset = Vector2(0, -texture.get_height() * 0.5)
		add_child(sprite)
		var bob: Tween = create_tween().set_loops()
		bob.tween_property(sprite, "position:y", -3.0, 0.9).set_trans(Tween.TRANS_SINE)
		bob.tween_property(sprite, "position:y", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	else:
		material = unshaded
		var body := StaticBody2D.new()
		body.position = Vector2(0, -12)
		var shape := RectangleShape2D.new()
		shape.size = Vector2(26, 22)
		var collision := CollisionShape2D.new()
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
	var title := Label.new()
	title.text = "CASPER (TAVERN)" if mode == "main" else "CANDY DISPENSER"
	title.material = unshaded
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", MERCHANT_TINT)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(120, 16)
	title.position = Vector2(-60, -72 if texture == null else -(texture.get_height() + 22))
	title.z_index = 60
	add_child(title)
	_prompt = Label.new()
	_prompt.material = unshaded
	_prompt.text = "E: Tavern Shop" if mode == "main" else "E: Candy Dispenser"
	_prompt.add_theme_font_size_override("font_size", 17)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.98, 0.78))
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(200, 22)
	_prompt.position = Vector2(-100, 6)
	_prompt.z_index = 60
	_prompt.visible = false
	add_child(_prompt)


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	_prompt.visible = is_active_target
	if texture == null:
		queue_redraw()


func is_player_in_reach() -> bool:
	return _player != null and _player.visible and global_position.distance_to(_player.global_position) <= reach


func open_shop() -> void:
	if Time.get_ticks_msec() < GameManager.shop_block_until:
		return
	SHOP_UI.call("open", self, mode)


## Vending machine drawn from rectangles (no art asset): bright candy window, glowing slot.
func _draw() -> void:
	if texture != null:
		return
	var pulse: float = 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.006)
	draw_rect(Rect2(-15, -46, 30, 46), Color(0.55, 0.08, 0.18))
	draw_rect(Rect2(-15, -46, 30, 4), Color(0.8, 0.2, 0.3))
	draw_rect(Rect2(-11, -40, 22, 24), Color(0.12, 0.1, 0.18))
	draw_rect(Rect2(-10, -39, 20, 22), Color(0.55, 0.9, 1.0, pulse * 0.55))
	var colors: Array[Color] = [Color(1, 0.4, 0.7), Color(1, 0.85, 0.2), Color(0.5, 1, 0.5), Color(0.7, 0.5, 1)]
	for row in 3:
		for col in 4:
			draw_rect(Rect2(-9 + col * 5, -37 + row * 7, 4, 4), colors[(row + col) % colors.size()])
	draw_rect(Rect2(-9, -13, 18, 5), Color(0.05, 0.04, 0.08))
	draw_rect(Rect2(-9, -13, 18, 1), Color(1.0, 0.9, 0.4, pulse))
	draw_rect(Rect2(-12, -6, 24, 3), Color(0.25, 0.04, 0.1))

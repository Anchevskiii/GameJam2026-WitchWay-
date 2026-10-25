extends CanvasLayer

## Shop window for the Merchant and the vending machines. Pauses the game while open.
## Open with: ShopUI.open(host_node, "main" | "vending")  (see shop_keeper.gd).
## Prices and rules live in GameManager.shop_items() / GameManager.buy().

var _mode: String = "main"
var _rows: VBoxContainer
var _candy_label: Label
var _message: Label


## Opens the shop unless one is already open.
static func open(host: Node, shop_mode: String) -> void:
	var root: Node = host.get_tree().root
	if root.has_node("ShopUI"):
		return
	var ui: CanvasLayer = (load("res://scripts/ui/shop_ui.gd") as Script).new()
	ui.name = "ShopUI"
	ui.set("_mode", shop_mode)
	root.add_child(ui)


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	AudioManager.process_mode = Node.PROCESS_MODE_ALWAYS  # shop clicks must be audible while paused
	_build()
	_refresh()
	AudioManager.play("pop", -3.0, 1.2)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(620, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title := Label.new()
	title.text = "THE MERCHANT" if _mode == "main" else "CANDY MACHINE (limited stock, higher prices)"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_candy_label = Label.new()
	_candy_label.add_theme_font_size_override("font_size", 18)
	_candy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_candy_label)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	box.add_child(_rows)
	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_color_override("font_color", Color(1.0, 0.8, 0.6))
	box.add_child(_message)
	var close := Button.new()
	close.text = "Close  (E / Esc)"
	close.pressed.connect(_close)
	box.add_child(close)


func _refresh() -> void:
	for child in _rows.get_children():
		child.queue_free()
	_candy_label.text = "Your candy: %d" % GameManager.candy
	var first_button: Button = null
	for entry in GameManager.shop_items(_mode):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := Label.new()
		name_label.text = String(entry["name"])
		name_label.add_theme_font_size_override("font_size", 17)
		text.add_child(name_label)
		var desc := Label.new()
		desc.text = String(entry["desc"])
		desc.add_theme_font_size_override("font_size", 12)
		desc.modulate = Color(1, 1, 1, 0.7)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(380, 0)
		text.add_child(desc)
		row.add_child(text)
		var button := Button.new()
		button.custom_minimum_size = Vector2(130, 0)
		var available: bool = entry["available"]
		if available:
			button.text = "Buy  (%d candy)" % int(entry["price"])
			button.disabled = GameManager.candy < int(entry["price"])
		else:
			button.text = "-"
			button.disabled = true
			desc.text = String(entry["reason"])
		button.pressed.connect(_on_buy.bind(String(entry["id"])))
		row.add_child(button)
		_rows.add_child(row)
		if first_button == null and not button.disabled:
			first_button = button
	if first_button != null:
		first_button.call_deferred("grab_focus")


func _on_buy(id: String) -> void:
	var error: String = GameManager.buy(id, _mode)
	if error.is_empty():
		_message.text = "Purchased!"
		AudioManager.play("key", -2.0, 1.1)
	else:
		_message.text = error
		AudioManager.play("thud", -6.0, 1.3)
	_refresh()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	GameManager.shop_block_until = Time.get_ticks_msec() + 350
	get_tree().paused = false
	AudioManager.process_mode = Node.PROCESS_MODE_INHERIT
	queue_free()

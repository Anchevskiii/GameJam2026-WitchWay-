class_name CustomizationMenu
extends CanvasLayer

## Full-screen Customization screen: pick one of 5 character presets and type your name.
## The name + preset are saved via SaveManager and reused for every future game.
## Attached to: CanvasLayer in scenes/ui/customization_menu.tscn

signal closed()

@onready var root: Control = $Root
@onready var preview: TextureRect = %Preview
@onready var name_edit: LineEdit = %NameEdit
@onready var preset_grid: HBoxContainer = %PresetGrid
@onready var save_button: Button = %SaveButton
@onready var back_button: Button = %BackButton

var _selected_id: int = 0
var _cards: Array[PanelContainer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if root:
		root.theme = UiTheme.build()
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	_build_preset_grid()


func open() -> void:
	var profile: Dictionary = SaveManager.load_player_profile()
	_selected_id = int(profile.get("preset_id", 0))
	if not PlayerPresets.is_valid(_selected_id):
		_selected_id = PlayerPresets.DEFAULT_ID
	if name_edit:
		name_edit.text = String(profile.get("name", ""))
		_apply_character_limit()
	_refresh_preview()
	_refresh_selection()
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _build_preset_grid() -> void:
	if preset_grid == null:
		return
	for child in preset_grid.get_children():
		child.queue_free()
	_cards.clear()
	for id in PlayerPresets.count():
		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(120, 150)
		card.add_theme_stylebox_override("panel", UiTheme.card_box(false))
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 8)
		card.add_child(box)

		var sprite_button := TextureButton.new()
		sprite_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		sprite_button.ignore_texture_size = true
		sprite_button.custom_minimum_size = Vector2(72, 96)
		sprite_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		sprite_button.texture_normal = PlayerPresets.texture(id)
		sprite_button.pressed.connect(_select.bind(id))
		box.add_child(sprite_button)

		var label := Label.new()
		label.text = PlayerPresets.display_name(id).to_upper()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		box.add_child(label)

		preset_grid.add_child(card)
		_cards.append(card)


func _select(id: int) -> void:
	_selected_id = id
	AudioManager.play("pop", -8.0)
	_refresh_preview()
	_refresh_selection()


func _refresh_preview() -> void:
	if preview:
		preview.texture = PlayerPresets.texture(_selected_id)


func _refresh_selection() -> void:
	for i in _cards.size():
		_cards[i].add_theme_stylebox_override("panel", UiTheme.card_box(i == _selected_id))


func _on_save_pressed() -> void:
	var player_name: String = name_edit.text.strip_edges() if name_edit else ""
	SaveManager.save_player_profile(player_name, _selected_id)
	AudioManager.play("pop", -6.0)
	close()


func _on_back_pressed() -> void:
	AudioManager.play("pop", -8.0)
	close()


## Keep the name short enough to fit the pixel font nicely.
func _apply_character_limit() -> void:
	name_edit.max_length = 16

class_name HUD
extends CanvasLayer

## Sanity bar, GLITCH bar (scares make the house glitch), room name/objective and the Narrator text box.
## Attached to: CanvasLayer in scenes/ui/hud.tscn

const CPU_CALM: Color = Color(0.2, 0.8, 1.0)
const CPU_WARM: Color = Color(1.0, 0.65, 0.2)
const CPU_HOT: Color = Color(1.0, 0.25, 0.25)
const CPU_OVERLOAD: Color = Color(1.0, 0.0, 0.86)

@onready var sanity_bar: ProgressBar = $Control/PanelContainer/VBoxContainer/SanityBox/SanityBar
@onready var sanity_label: Label = $Control/PanelContainer/VBoxContainer/SanityBox/HeaderBox/SanityPercent
@onready var cpu_bar: ProgressBar = $Control/PanelContainer/VBoxContainer/CPUBox/CPUBar
@onready var cpu_label: Label = $Control/PanelContainer/VBoxContainer/CPUBox/HeaderBox/CPUPercent
@onready var room_label: Label = $Control/PanelContainer/VBoxContainer/RoomLabel
@onready var objective_label: Label = $Control/PanelContainer/VBoxContainer/ObjectiveLabel
@onready var narrator_box: PanelContainer = $Control/NarratorBox
@onready var narrator_text: Label = $Control/NarratorBox/VBoxContainer/NarratorText

var _cpu_fill: StyleBoxFlat
var _keys_label: Label
var _candy_box: HBoxContainer
var _candy_icon: TextureRect
var _candy_label: Label
var _items_label: Label
var _narrator_tween: Tween


func _on_candy_changed(_amount: int) -> void:
	_update_inventory()


func _update_inventory() -> void:
	if _candy_label == null:
		return
	_candy_label.text = "%d" % GameManager.candy
	var parts: Array[String] = []
	if GameManager.mask_owned:
		parts.append("Mask [R]")
	if GameManager.glitch_charges > 0:
		parts.append("Glitch [Q]")
	if GameManager.flashlight_floors > 0:
		parts.append("Flashlight (%d floor%s)" % [GameManager.flashlight_floors, "" if GameManager.flashlight_floors == 1 else "s"])
	_items_label.text = "  ".join(parts)
	_items_label.visible = not parts.is_empty()


func _ready() -> void:
	# Own copy of the fill style so changing its colour doesn't touch other bars.
	_cpu_fill = (cpu_bar.get_theme_stylebox("fill") as StyleBoxFlat).duplicate()
	cpu_bar.add_theme_stylebox_override("fill", _cpu_fill)
	narrator_box.visible = false

	EventBus.sanity_changed.connect(_on_sanity_changed)
	EventBus.cpu_overload_changed.connect(_on_cpu_overload_changed)
	EventBus.room_entered.connect(_on_room_entered)
	EventBus.narrator_line_changed.connect(_on_narrator_line_changed)
	# Keys for a locked exit: shown only on floors that have them.
	_keys_label = Label.new()
	_keys_label.add_theme_font_override("font", UiTheme.font())
	_keys_label.add_theme_font_size_override("font_size", 10)
	_keys_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_keys_label.visible = false
	room_label.get_parent().add_child(_keys_label)
	room_label.get_parent().move_child(_keys_label, room_label.get_index())
	EventBus.keys_changed.connect(_on_keys_changed)
	EventBus.house_awakened.connect(_on_house_awakened)

	# Candy currency widget with candy icon + number in pixel font:
	_candy_box = HBoxContainer.new()
	_candy_box.add_theme_constant_override("separation", 6)
	_candy_icon = TextureRect.new()
	_candy_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_candy_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_candy_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_candy_icon.custom_minimum_size = Vector2(22, 22)
	_candy_icon.texture = _load_candy_texture()
	_candy_box.add_child(_candy_icon)

	_candy_label = Label.new()
	_candy_label.add_theme_font_override("font", UiTheme.font())
	_candy_label.add_theme_font_size_override("font_size", 12)
	_candy_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.32))
	_candy_box.add_child(_candy_label)
	room_label.get_parent().add_child(_candy_box)

	_items_label = Label.new()
	_items_label.add_theme_font_override("font", UiTheme.font())
	_items_label.add_theme_font_size_override("font_size", 9)
	_items_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	room_label.get_parent().add_child(_items_label)
	GameManager.candy_changed.connect(_on_candy_changed)
	GameManager.inventory_changed.connect(_update_inventory)
	_update_inventory()
	_on_sanity_changed(GameManager.current_sanity, GameManager.max_sanity)
	_on_cpu_overload_changed(GameManager.current_cpu_overload, GameManager.max_cpu_overload)


func _on_sanity_changed(current: float, max_val: float) -> void:
	sanity_bar.max_value = max_val
	sanity_bar.value = current
	var pct: int = int((current / maxf(max_val, 1.0)) * 100.0)
	sanity_label.text = "%d%%" % pct
	sanity_bar.modulate = Color(1, 1, 1) if pct > 25 else Color(1, 0.6, 0.6)


func _on_cpu_overload_changed(_current: float, _max_val: float) -> void:
	var level: float = GameManager.glitch_level()
	cpu_bar.max_value = 100.0
	cpu_bar.value = level
	var pct: int = int(level)
	# The glitch meter in words: scaring things makes the house glitch; at 100% it crashes.
	if pct >= 100:
		cpu_label.text = "CRASHED!"
		_cpu_fill.bg_color = CPU_OVERLOAD
	elif pct >= 90:
		cpu_label.text = "%d%% CRASHING" % pct
		_cpu_fill.bg_color = CPU_HOT
	elif pct >= 80:
		cpu_label.text = "%d%% SEVERE" % pct
		_cpu_fill.bg_color = CPU_HOT
	elif pct >= 50:
		cpu_label.text = "%d%% LAGGING" % pct
		_cpu_fill.bg_color = CPU_WARM
	elif pct >= 25:
		cpu_label.text = "%d%% FLICKERING" % pct
		_cpu_fill.bg_color = CPU_CALM
	else:
		cpu_label.text = "%d%% STABLE" % pct
		_cpu_fill.bg_color = CPU_CALM


func _on_keys_changed(found: int, needed: int) -> void:
	_keys_label.visible = needed > 0
	if needed <= 0:
		return
	var has_all: bool = found >= needed
	if has_all:
		_keys_label.text = "KEYS: ALL FOUND (%d/%d)" % [found, needed]
	else:
		_keys_label.text = "KEYS: %d/%d - LOCKED" % [found, needed]
	_keys_label.add_theme_color_override("font_color",
		Color(0.4, 1.0, 0.5) if has_all else Color(1.0, 0.85, 0.3))


func _on_house_awakened() -> void:
	_keys_label.text = "KEYS: ALL FOUND (%d/%d)" % [GameManager.keys_found, GameManager.keys_needed]
	_keys_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))


func _on_room_entered(room_title: String, objective: String) -> void:
	room_label.text = room_title.to_upper()
	objective_label.text = objective
	objective_label.visible = not objective.is_empty()


## Typewriter-style narrator box. Empty text hides it.
func _on_narrator_line_changed(text: String) -> void:
	if _narrator_tween:
		_narrator_tween.kill()
	if text.is_empty():
		narrator_box.visible = false
		return
	narrator_box.visible = true
	narrator_text.text = text
	narrator_text.visible_ratio = 0.0
	_narrator_tween = create_tween()
	_narrator_tween.tween_property(narrator_text, "visible_ratio", 1.0, minf(0.02 * text.length(), 1.2))


func _load_candy_texture() -> Texture2D:
	for custom_path in [
		"res://assets/sprites/items/halloween-candy.png",
		"res://assets/sprites/items/candy.png",
		"res://inspo/candy.png",
		"res://review/candy.png",
	]:
		if ResourceLoader.exists(custom_path):
			var t: Texture2D = load(custom_path) as Texture2D
			if t:
				return t
		var custom_global: String = ProjectSettings.globalize_path(custom_path)
		if FileAccess.file_exists(custom_global):
			var img: Image = Image.load_from_file(custom_global)
			if img != null and not img.is_empty():
				return ImageTexture.create_from_image(img)
	var external_dirs := ["../GameJam2026_Previews", "../GameJam2026_Previews/inspo", "../GameJam2026_Previews/review"]
	for ed in external_dirs:
		for fn in ["halloween-candy.png", "candy.png", "candy_icon.png", "candy1.png"]:
			var ext_p := "%s/%s" % [ed, fn]
			if FileAccess.file_exists(ext_p):
				var img := Image.load_from_file(ext_p)
				if img != null and not img.is_empty():
					return ImageTexture.create_from_image(img)
	return null

class_name ShopUI
extends CanvasLayer

## Halloween Tavern Merch Shop for Casper the Ghost Merchant and Haunted Alcoves.
## Displays animated ghost shopkeeper, atmospheric tavern decor (pumpkins, candles, cobwebs),
## custom pixel art icons for all upgrades, detailed item stats, candy currency and UiTheme buttons.
## Pauses the game while open. Can be opened via ShopUI.open(host, mode).

signal closed()

const FONT_PATH: String = "res://assets/fonts/press_start_2p.ttf"

const ITEM_ICONS: Dictionary = {
	"flashlight": "res://assets/sprites/items/flashlight.png",
	"mask": "res://assets/sprites/items/ghost_sheet.png",
	"glitch": "res://assets/sprites/items/cauldron.png",
	"sanity_resist": "res://assets/sprites/items/fang.png",
	"search": "res://assets/sprites/objects/key.png",
	"candy_sanity": "res://assets/sprites/items/candy.png",
}

const ITEM_FALLBACKS: Dictionary = {
	"flashlight": "res://assets/sprites/objects/lamp.png",
	"mask": "res://assets/sprites/characters/player_guy_mask.png",
	"glitch": "res://assets/sprites/items/candelabra.png",
	"sanity_resist": "res://assets/sprites/items/bone.png",
	"search": "res://assets/sprites/items/mug.png",
	"candy_sanity": "res://assets/sprites/items/candy.png",
}

const ITEM_BADGES: Dictionary = {
	"flashlight": "TOOL",
	"mask": "DISGUISE",
	"glitch": "POWER",
	"sanity_resist": "PERK",
	"search": "PERK",
	"candy_sanity": "PASSIVE",
}

const GHOST_ITEM_DIALOGUES: Dictionary = {
	"flashlight": "Flashlight [F]! Casts a sharp beam into the dark. Monsters hate the glow, but battery floors run out!",
	"mask": "Spooky Ghost Mask [R]! Wear it and roam freely among the restless horrors - they won't even notice!",
	"glitch": "Glitch Charge [Q]! Tear a seam into reality itself to escape when you hold all the keys!",
	"sanity_resist": "Thick Skin! Monster howls won't shake your brain as hard. Essential armor for brittle sanity!",
	"search": "Quick Fingers! Loot cupboards and drawers like lightning before the stalkers sneak up!",
	"candy_sanity": "Sugar Rush! Pure sweet treats! Every candy you eat permanently restores +1 more Sanity!",
}

const GHOST_IDLE_QUOTES: Array[String] = [
	"Boo! Welcome to the Spooky Tavern, mortal! Got any candies?",
	"Candies talk, whispers walk! Best survival wares beyond the grave!",
	"Mind the creaking floorboards... HE is always wandering above.",
	"Trading sweet treats for survival tricks! Look around!",
	"Don't be shy! My goods are strictly guaranteed to keep you breathing!",
	"Stock up before you descend into the darker corridors!"
]

const GHOST_BUY_QUOTES: Array[String] = [
	"Hehehe! Delicious crunchy candies! Enjoy your upgrade!",
	"A wise trade, traveler! Treat it well in the dark!",
	"Pleasure doing business with ya! Those monsters won't know what hit 'em!",
	"Mmm, sweet treats! You're always welcome at my tavern!"
]

var _mode: String = "main"
var _ghost_frames: Array[Texture2D] = []
var _ghost_frame_idx: int = 0
var _anim_timer: float = 0.0
var _floating_time: float = 0.0
var _idle_timer: float = 0.0
var _target_dialogue: String = ""
var _displayed_dialogue: String = ""
var _typewriter_timer: float = 0.0
var _char_index: int = 0
var _casper_click_count: int = 0
var _base_ghost_pos: Vector2 = Vector2.ZERO
var _texture_cache: Dictionary = {}

# Node references
@onready var root_control: Control = %Root
@onready var shop_title: Label = %ShopTitle
@onready var shop_subtitle: Label = %ShopSubtitle
@onready var candy_count_label: Label = %CandyCountLabel
@onready var candy_icon_header: TextureRect = %CandyIconHeader
@onready var ghost_sprite: TextureRect = %GhostSprite
@onready var ghost_glow: TextureRect = %GhostGlow
@onready var pumpkin_sprite: TextureRect = %PumpkinSprite
@onready var candle_sprite: TextureRect = %CandleSprite
@onready var dialogue_label: Label = %DialogueLabel
@onready var items_container: VBoxContainer = %ItemsContainer
@onready var status_message: Label = %StatusMessage
@onready var close_button: Button = %CloseButton


## Static helper to open the shop anywhere.
static func open(host: Node, shop_mode: String = "main") -> void:
	var root: Node = host.get_tree().root
	if root.has_node("ShopUI"):
		return
	var scene: PackedScene = load("res://scenes/ui/shop_menu.tscn")
	var ui: CanvasLayer = null
	if scene != null:
		ui = scene.instantiate()
	else:
		ui = (load("res://scripts/ui/shop_ui.gd") as Script).new()
	ui.name = "ShopUI"
	ui.set("_mode", shop_mode)
	root.add_child(ui)


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	AudioManager.process_mode = Node.PROCESS_MODE_ALWAYS

	if root_control:
		root_control.theme = UiTheme.build()

	_load_ghost_frames()
	_setup_decor()
	_setup_header()

	if ghost_sprite:
		_base_ghost_pos = ghost_sprite.position

	if close_button:
		close_button.pressed.connect(_close)

	if %GhostButton:
		(%GhostButton as BaseButton).pressed.connect(_on_ghost_clicked)

	_refresh_items()
	_set_dialogue("Welcome to the Spooky Tavern, mortal! Spend your candies wisely, hehehe...")
	AudioManager.play("cackle", -8.0, 1.3)


func _load_ghost_frames() -> void:
	_ghost_frames.clear()
	for i in range(1, 5):
		var p: String = "res://assets/sprites/entities/ghost/Png_animation/Ghost%d.png" % i
		var tex: Texture2D = _get_texture_safe(p)
		if tex:
			_ghost_frames.append(tex)
	if _ghost_frames.is_empty():
		var fb: Texture2D = _get_texture_safe("res://assets/sprites/characters/ghost.png")
		if fb:
			_ghost_frames.append(fb)


func _setup_decor() -> void:
	if candy_icon_header:
		candy_icon_header.texture = _get_texture_safe("res://assets/sprites/items/candy.png")
		candy_icon_header.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		candy_icon_header.custom_minimum_size = Vector2(22, 22)
	if pumpkin_sprite:
		pumpkin_sprite.texture = _get_texture_safe("res://assets/sprites/objects/pumpkin.png")
	if candle_sprite:
		candle_sprite.texture = _get_texture_safe("res://assets/sprites/objects/candles.png")
	if %CobwebLeft:
		(%CobwebLeft as TextureRect).texture = _get_texture_safe("res://assets/sprites/objects/cobweb.png")
	if %CobwebRight:
		(%CobwebRight as TextureRect).texture = _get_texture_safe("res://assets/sprites/objects/cobweb.png")
	if %CauldronSprite:
		(%CauldronSprite as TextureRect).texture = _get_texture_safe("res://assets/sprites/items/cauldron.png")
	if %MugSprite:
		(%MugSprite as TextureRect).texture = _get_texture_safe("res://assets/sprites/items/mug.png")
	if ghost_glow:
		ghost_glow.texture = _get_texture_safe("res://assets/sprites/environment/light_radial.tres")


func _setup_header() -> void:
	if _mode == "vending":
		if shop_title:
			shop_title.text = "ALCOVE CANDY DISPENSER"
		if shop_subtitle:
			shop_subtitle.text = "Emergency haunted outpost - expedited treats for dark corners"
		if %MerchantTitle:
			(%MerchantTitle as Label).text = "DISPENSER SPIRIT"
	else:
		if shop_title:
			shop_title.text = "THE SPOOKY TAVERN & MERCH"
		if shop_subtitle:
			shop_subtitle.text = "Trade hard-earned candies for spectral survival tools & charms"
		if %MerchantTitle:
			(%MerchantTitle as Label).text = "CASPER THE TAVERN KEEPER"


func _process(delta: float) -> void:
	_floating_time += delta
	_anim_timer += delta
	_idle_timer += delta

	# Animated Ghost Floating & Frame Cycling
	if _ghost_frames.size() > 0 and _anim_timer >= 0.16:
		_anim_timer = 0.0
		_ghost_frame_idx = (_ghost_frame_idx + 1) % _ghost_frames.size()
		if ghost_sprite:
			ghost_sprite.texture = _ghost_frames[_ghost_frame_idx]

	if ghost_sprite:
		var bob: float = sin(_floating_time * 2.8) * 8.0
		var sway: float = cos(_floating_time * 1.4) * 3.0
		ghost_sprite.position = _base_ghost_pos + Vector2(sway, bob)

	if ghost_glow:
		ghost_glow.modulate.a = 0.45 + 0.18 * sin(_floating_time * 3.2)

	# Candle & Pumpkin flame flicker
	if candle_sprite:
		candle_sprite.modulate.a = 0.85 + 0.15 * sin(_floating_time * 9.0)
	if pumpkin_sprite:
		var p_pulse: float = 0.90 + 0.10 * sin(_floating_time * 7.5 + 1.0)
		pumpkin_sprite.modulate = Color(1.0, 0.95 * p_pulse, 0.85 * p_pulse)

	# Typewriter Dialogue text
	if _char_index < _target_dialogue.length():
		_typewriter_timer += delta
		if _typewriter_timer >= 0.025:
			_typewriter_timer = 0.0
			_char_index += 1
			_displayed_dialogue = _target_dialogue.substr(0, _char_index)
			if dialogue_label:
				dialogue_label.text = _displayed_dialogue

	# Periodic idle banter
	if _idle_timer >= 8.0:
		_idle_timer = 0.0
		var random_quote: String = GHOST_IDLE_QUOTES[randi() % GHOST_IDLE_QUOTES.size()]
		_set_dialogue(random_quote)


func _set_dialogue(text: String) -> void:
	_target_dialogue = text
	_displayed_dialogue = ""
	_char_index = 0
	_typewriter_timer = 0.0
	if dialogue_label:
		dialogue_label.text = ""


func _refresh_items() -> void:
	if items_container == null:
		return

	for child in items_container.get_children():
		child.queue_free()

	if candy_count_label:
		candy_count_label.text = "CANDY: %d" % GameManager.candy

	var items: Array = GameManager.shop_items(_mode)
	var first_active_button: Button = null

	for entry in items:
		var item_id: String = String(entry["id"])
		var item_name: String = String(entry["name"])
		var item_desc: String = String(entry["desc"])
		var price: int = int(entry["price"])
		var available: bool = bool(entry["available"])
		var reason: String = String(entry.get("reason", ""))

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 82)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", UiTheme.card_box(false))

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)
		hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		card.add_child(hbox)

		# Icon Frame
		var icon_panel := PanelContainer.new()
		icon_panel.custom_minimum_size = Vector2(64, 64)
		var icon_sb := StyleBoxFlat.new()
		icon_sb.bg_color = Color(0.04, 0.03, 0.08, 0.95)
		icon_sb.border_color = Color(0.45, 0.35, 0.65)
		icon_sb.set_border_width_all(2)
		icon_panel.add_theme_stylebox_override("panel", icon_sb)

		var icon_rect := TextureRect.new()
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(44, 44)
		icon_rect.texture = _get_item_icon(item_id)
		icon_panel.add_child(icon_rect)
		hbox.add_child(icon_panel)

		# Info Column
		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		info_vbox.add_theme_constant_override("separation", 4)
		hbox.add_child(info_vbox)

		# Name + Badge Row
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 8)
		info_vbox.add_child(name_row)

		var name_label := Label.new()
		name_label.text = item_name.to_upper()
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
		name_row.add_child(name_label)

		var badge_label := Label.new()
		badge_label.text = "[%s]" % ITEM_BADGES.get(item_id, "ITEM")
		badge_label.add_theme_font_size_override("font_size", 9)
		badge_label.add_theme_color_override("font_color", Color(0.96, 0.58, 0.22))
		name_row.add_child(badge_label)

		var desc_label := Label.new()
		desc_label.text = item_desc
		desc_label.add_theme_font_size_override("font_size", 9)
		desc_label.add_theme_color_override("font_color", Color(0.72, 0.70, 0.85))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_vbox.add_child(desc_label)

		# Price & Buy Column
		var buy_box := HBoxContainer.new()
		buy_box.add_theme_constant_override("separation", 10)
		buy_box.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(buy_box)

		# Candy Price widget
		var price_box := HBoxContainer.new()
		price_box.alignment = BoxContainer.ALIGNMENT_CENTER
		price_box.add_theme_constant_override("separation", 5)

		var candy_img := TextureRect.new()
		candy_img.texture = _get_texture_safe("res://assets/sprites/items/candy.png")
		candy_img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		candy_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		candy_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		candy_img.custom_minimum_size = Vector2(20, 20)
		price_box.add_child(candy_img)

		var price_lbl := Label.new()
		price_lbl.text = "%d" % price
		price_lbl.add_theme_font_size_override("font_size", 14)
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.3))
		price_box.add_child(price_lbl)
		buy_box.add_child(price_box)

		# Action Button
		var button := Button.new()
		button.custom_minimum_size = Vector2(130, 42)
		button.add_theme_font_size_override("font_size", 11)

		if available:
			if GameManager.candy >= price:
				button.text = "BUY"
				button.disabled = false
			else:
				button.text = "NEED %d" % (price - GameManager.candy)
				button.disabled = true
		else:
			button.text = "OWNED" if item_id in ["flashlight", "mask", "glitch"] else "MAXED"
			button.disabled = true

		button.pressed.connect(_on_buy.bind(item_id, item_name))

		# Hover events for dialogue reaction and audio
		button.mouse_entered.connect(_on_item_hovered.bind(item_id, card, true))
		button.mouse_exited.connect(_on_item_hovered.bind(item_id, card, false))
		card.mouse_entered.connect(_on_item_hovered.bind(item_id, card, true))
		card.mouse_exited.connect(_on_item_hovered.bind(item_id, card, false))

		buy_box.add_child(button)
		items_container.add_child(card)

		if first_active_button == null and not button.disabled:
			first_active_button = button

	if first_active_button != null:
		first_active_button.call_deferred("grab_focus")


func _on_item_hovered(id: String, card: PanelContainer, is_hover: bool) -> void:
	if card:
		card.add_theme_stylebox_override("panel", UiTheme.card_box(is_hover))
	if is_hover:
		AudioManager.play("pop", -14.0, 1.6)
		_idle_timer = 0.0
		if GHOST_ITEM_DIALOGUES.has(id):
			_set_dialogue(GHOST_ITEM_DIALOGUES[id])


func _on_buy(id: String, item_name: String) -> void:
	var error: String = GameManager.buy(id, _mode)
	if error.is_empty():
		AudioManager.play("key", -2.0, 1.1)
		AudioManager.play("pop", -4.0, 1.8)
		if status_message:
			status_message.text = "Purchased %s successfully!" % item_name
			status_message.modulate = Color(0.4, 1.0, 0.4)
		_trigger_ghost_celebration()
		var buy_quote: String = GHOST_BUY_QUOTES[randi() % GHOST_BUY_QUOTES.size()]
		_set_dialogue(buy_quote)
	else:
		AudioManager.play("thud", -6.0, 1.3)
		if status_message:
			status_message.text = error
			status_message.modulate = Color(1.0, 0.4, 0.4)
		_set_dialogue("Bah! %s" % error)
	_refresh_items()


func _trigger_ghost_celebration() -> void:
	if ghost_sprite == null:
		return
	var tw: Tween = create_tween()
	tw.tween_property(ghost_sprite, "scale", Vector2(1.22, 1.22), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost_sprite, "scale", Vector2(1.0, 1.0), 0.18)


func _on_ghost_clicked() -> void:
	_casper_click_count += 1
	AudioManager.play("player_boo", -6.0, 1.2 + randf() * 0.3)
	_trigger_ghost_celebration()
	if _casper_click_count == 1:
		_set_dialogue("Hey! Ticklish! Keep your mortal paws to the merchandise!")
	elif _casper_click_count == 2:
		_set_dialogue("Quit poking the merchant! Ghost etiquette, please!")
	elif _casper_click_count >= 3:
		# Fun Easter egg: Casper gifts 15 trick-or-treat candies!
		GameManager.add_candy(15)
		_set_dialogue("Alright, alright! Have 15 candies from the secret stash, just don't poke me again!")
		AudioManager.play("key", -1.0, 1.3)
		_refresh_items()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	AudioManager.play("pop", -6.0, 0.9)
	GameManager.shop_block_until = Time.get_ticks_msec() + 350
	get_tree().paused = false
	AudioManager.process_mode = Node.PROCESS_MODE_INHERIT
	closed.emit()
	queue_free()


func _get_item_icon(id: String) -> Texture2D:
	var path: String = ITEM_ICONS.get(id, "")
	var fb_path: String = ITEM_FALLBACKS.get(id, "")
	var tex: Texture2D = _get_texture_safe(path, fb_path)
	if tex == null:
		tex = _get_texture_safe("res://assets/sprites/items/candy.png")
	return tex


func _get_texture_safe(path: String, fallback_path: String = "") -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var res: Texture2D = null

	# If checking for candy, first check if user uploaded a custom candy icon in inspo/review/previews
	if path.ends_with("candy.png"):
		for custom_path in [
			"res://assets/sprites/items/halloween-candy.png",
			"res://assets/sprites/items/candy.png",
			"res://inspo/candy.png",
			"res://review/candy.png",
		]:
			if ResourceLoader.exists(custom_path):
				res = load(custom_path) as Texture2D
				if res != null:
					break
			var custom_global: String = ProjectSettings.globalize_path(custom_path)
			if FileAccess.file_exists(custom_global):
				var img: Image = Image.load_from_file(custom_global)
				if img != null and not img.is_empty():
					res = ImageTexture.create_from_image(img)
					break
		if res == null:
			var external_dirs := ["../GameJam2026_Previews", "../GameJam2026_Previews/inspo", "../GameJam2026_Previews/review"]
			for ed in external_dirs:
				for fn in ["halloween-candy.png", "candy.png", "candy_icon.png", "candy1.png"]:
					var ext_p := "%s/%s" % [ed, fn]
					if FileAccess.file_exists(ext_p):
						var img := Image.load_from_file(ext_p)
						if img != null and not img.is_empty():
							res = ImageTexture.create_from_image(img)
							break
				if res != null:
					break

	if res == null and ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			res = loaded
	if res == null:
		var global_p: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(global_p):
			var img: Image = Image.load_from_file(global_p)
			if img != null and not img.is_empty():
				res = ImageTexture.create_from_image(img)
	if res == null and not fallback_path.is_empty():
		if ResourceLoader.exists(fallback_path):
			var fb_loaded: Resource = load(fallback_path)
			if fb_loaded is Texture2D:
				res = fb_loaded
		if res == null:
			var fb_global: String = ProjectSettings.globalize_path(fallback_path)
			if FileAccess.file_exists(fb_global):
				var fb_img: Image = Image.load_from_file(fb_global)
				if fb_img != null and not fb_img.is_empty():
					res = ImageTexture.create_from_image(fb_img)
	_texture_cache[path] = res
	return res

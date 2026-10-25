class_name UiTheme
extends RefCounted

## Pixel-art UI theme for the main menu, settings and customization screens.
## Built in code so the palette stays consistent everywhere: deep purple panels,
## lavender borders, sharp corners and chunky "pixel" borders, plus the Press Start 2P
## pixel font. Use `UiTheme.build()` once and assign it to a Control's `theme`.

const FONT_PATH: String = "res://assets/fonts/press_start_2p.ttf"

const PANEL_BG: Color = Color(0.06, 0.04, 0.10, 0.94)
const PANEL_BORDER: Color = Color(0.55, 0.45, 0.75)
const BUTTON_BG: Color = Color(0.09, 0.06, 0.15)
const BUTTON_BORDER: Color = Color(0.62, 0.50, 0.85)
const BUTTON_HOVER_BG: Color = Color(0.18, 0.11, 0.26)
const BUTTON_HOVER_BORDER: Color = Color(0.96, 0.58, 0.22)
const BUTTON_PRESSED_BG: Color = Color(0.03, 0.02, 0.07)
const BUTTON_PRESSED_BORDER: Color = Color(0.46, 0.36, 0.66)
const BUTTON_DISABLED_BG: Color = Color(0.08, 0.07, 0.11, 0.55)
const BUTTON_DISABLED_BORDER: Color = Color(0.30, 0.28, 0.42, 0.7)
const TEXT: Color = Color(0.94, 0.91, 0.99)
const TEXT_DIM: Color = Color(0.62, 0.60, 0.76)
const ACCENT: Color = Color(0.96, 0.58, 0.22)

enum GearTint { NORMAL, HOVER, PRESSED }

static var _font: FontFile = null
static var _theme: Theme = null
static var _gear_cache: Dictionary = {}


static func font() -> FontFile:
	if _font == null:
		if ResourceLoader.exists(FONT_PATH):
			_font = load(FONT_PATH) as FontFile
	return _font


static func build() -> Theme:
	if _theme != null:
		return _theme

	var theme := Theme.new()
	var pixel_font: FontFile = font()
	if pixel_font != null:
		theme.default_font = pixel_font
	theme.default_font_size = 16

	# Buttons: chunky sharp-cornered pixel borders with a pressed "push down" effect.
	theme.set_stylebox("normal", "Button", _box(BUTTON_BG, BUTTON_BORDER, 3, 0))
	theme.set_stylebox("hover", "Button", _box(BUTTON_HOVER_BG, BUTTON_HOVER_BORDER, 3, 0))
	theme.set_stylebox("pressed", "Button", _box(BUTTON_PRESSED_BG, BUTTON_PRESSED_BORDER, 3, 2))
	theme.set_stylebox("disabled", "Button", _box(BUTTON_DISABLED_BG, BUTTON_DISABLED_BORDER, 2, 0))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", TEXT_DIM)
	theme.set_color("font_disabled_color", "Button", Color(0.45, 0.45, 0.55, 0.7))

	# Panels.
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL_BG, PANEL_BORDER, 3, 0))

	# Labels.
	theme.set_color("font_color", "Label", TEXT)

	# Name input.
	theme.set_stylebox("normal", "LineEdit", _box(Color(0.03, 0.02, 0.07), BUTTON_BORDER, 2, 0))
	theme.set_stylebox("focus", "LineEdit", _box(Color(0.03, 0.02, 0.07), BUTTON_HOVER_BORDER, 2, 0))
	theme.set_stylebox("read_only", "LineEdit", _box(Color(0.03, 0.02, 0.07), PANEL_BORDER, 2, 0))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", TEXT_DIM)
	theme.set_color("caret_color", "LineEdit", BUTTON_HOVER_BORDER)

	# Checkboxes (fullscreen / vsync): orange hover in both states, but enabled (checked) fills
	# the box while disabled (unchecked) just outlines it.
	theme.set_stylebox("normal", "CheckBox", _toggle_style(false, false))
	theme.set_stylebox("hover", "CheckBox", _toggle_style(false, true))
	theme.set_stylebox("pressed", "CheckBox", _toggle_style(true, false))
	theme.set_stylebox("hover_pressed", "CheckBox", _toggle_style(true, true))
	theme.set_color("font_color", "CheckBox", TEXT)
	theme.set_color("font_hover_color", "CheckBox", BUTTON_HOVER_BORDER)
	theme.set_color("font_pressed_color", "CheckBox", Color(1.0, 0.72, 0.4))
	theme.set_color("font_hover_pressed_color", "CheckBox", Color(1.0, 0.78, 0.45))
	theme.set_color("font_color", "HSlider", TEXT)
	theme.set_color("font_color", "HSeparator", PANEL_BORDER)

	_theme = theme
	return theme


## A small card panel used for the customization preset picker. Highlighted border when selected.
static func card_box(selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BUTTON_HOVER_BG if selected else BUTTON_BG
	sb.border_color = BUTTON_HOVER_BORDER if selected else PANEL_BORDER
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb


## Checkbox toggle style: `filled` = checked/enabled, `hot` = hovered.
## Disabled hover = orange outline; enabled hover = filled orange - both orange, but distinct.
static func _toggle_style(filled: bool, hot: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(0)
	sb.bg_color = Color(0.96, 0.58, 0.22, 0.32) if (filled and hot) else Color(0.0, 0.0, 0.0, 0.0)
	sb.border_color = (BUTTON_HOVER_BORDER if hot else PANEL_BORDER)
	sb.set_border_width_all(2 if (hot or filled) else 0)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	return sb


## A flat, sharp-cornered stylebox. `press` shifts the content down a couple of pixels
## so buttons visibly "click".
static func _box(bg: Color, border: Color, border_width: int, press: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 10.0 + press
	sb.content_margin_bottom = 10.0 - press
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 3 - press)
	return sb


## A pixel-art gear/cog icon drawn at runtime (no external asset needed).
static func gear_texture(tint: int) -> ImageTexture:
	if not _gear_cache.has(tint):
		var body: Color
		var hub: Color
		match tint:
			GearTint.HOVER:
				body = Color(0.96, 0.58, 0.22)
				hub = Color(1.0, 0.78, 0.42)
			GearTint.PRESSED:
				body = Color(0.46, 0.36, 0.66)
				hub = Color(0.56, 0.46, 0.76)
			_:
				body = Color(0.62, 0.50, 0.85)
				hub = Color(0.80, 0.70, 0.96)
		_gear_cache[tint] = ImageTexture.create_from_image(_gear_image(body, hub))
	return _gear_cache[tint]


static func _gear_image(body: Color, hub_color: Color) -> Image:
	var s: int = 24
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c: float = (s - 1) / 2.0
	var teeth: int = 8
	var sector_deg: float = 360.0 / teeth
	var tooth_deg: float = sector_deg * 0.5
	var outer: float = s * 0.46
	var inner: float = s * 0.33
	var hub_r: float = s * 0.17
	var hole_r: float = s * 0.075

	for y in s:
		for x in s:
			var dx: float = x - c
			var dy: float = y - c
			var d: float = sqrt(dx * dx + dy * dy)
			if d <= hole_r:
				continue
			var col: Color = body
			if d <= hub_r:
				col = hub_color
			else:
				var ang: float = rad_to_deg(atan2(dy, dx))
				var in_sector: float = fposmod(ang, sector_deg)
				var limit: float = outer if in_sector < tooth_deg else inner
				if d > limit:
					continue
			img.set_pixel(x, y, col)
	return img

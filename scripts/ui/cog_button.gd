class_name CogButton
extends TextureButton

## Pixel-art cog wheel (settings shortcut) that draws its own chunky gear textures,
## spins slowly in idle (and faster on hover), and plays a click when pressed.
## Matches the rest of the pixel UI theme. Attached to: a TextureButton in scenes/ui/main_menu.tscn.

## Idle rotation speed, in radians per second.
@export var idle_spin_speed: float = 0.6
## Rotation speed while hovered, in radians per second.
@export var hover_spin_speed: float = 4.0

var _spin_speed: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	ignore_texture_size = true
	texture_normal = UiTheme.gear_texture(UiTheme.GearTint.NORMAL)
	texture_hover = UiTheme.gear_texture(UiTheme.GearTint.HOVER)
	texture_pressed = UiTheme.gear_texture(UiTheme.GearTint.PRESSED)
	pivot_offset = size * 0.5
	_spin_speed = idle_spin_speed
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _process(delta: float) -> void:
	rotation += _spin_speed * delta


func _on_pressed() -> void:
	AudioManager.play("pop", -8.0)


func _on_mouse_entered() -> void:
	_spin_speed = hover_spin_speed


func _on_mouse_exited() -> void:
	_spin_speed = idle_spin_speed

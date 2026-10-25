extends CanvasLayer

## Full-screen jumpscares: a white flash, a face slams into view with a scream, the screen
## shakes, then it fades. Listens to EventBus.jumpscare_requested(face, damage); the damage
## is applied to sanity when the face hits.
## Attached to: JumpscareLayer (CanvasLayer) in scenes/main.tscn

const FACE_PATH: String = "res://assets/sprites/ui/jumpscare_%s.png"

## Seconds the face stays fully on screen.
@export var hold_time: float = 0.45
## A new jumpscare can't start within this many seconds of the last one.
@export var min_gap: float = 1.5

var _flash: ColorRect
var _face: TextureRect
var _busy_until: float = 0.0


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)
	_face = TextureRect.new()
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	_face.visible = false
	add_child(_face)
	EventBus.jumpscare_requested.connect(_on_jumpscare_requested)


func _on_jumpscare_requested(face: String, damage: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < _busy_until or GameManager.is_game_over or GameManager.is_safe_room:
		return
	_busy_until = now + hold_time + min_gap
	var texture: Texture2D = load(FACE_PATH % face) if ResourceLoader.exists(FACE_PATH % face) else null
	if texture == null:
		return
	_face.texture = texture
	_face.visible = true
	_face.modulate = Color.WHITE
	_face.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	_face.scale = Vector2.ONE * 0.35
	_face.position = Vector2.ZERO
	_flash.color.a = 0.85
	var js_sfx: String = "squeak_scare" if (face == "stalker" or randf() < 0.6) else "poltergeist"
	AudioManager.play(js_sfx, 3.0, 1.0)
	GameManager.scare_player(damage, "Jumpscare")

	var tween: Tween = create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.25)
	tween.parallel().tween_property(_face, "scale", Vector2.ONE * 1.25, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Shake while it's on screen.
	for i in int(hold_time / 0.03):
		tween.tween_property(_face, "position", Vector2(randf_range(-18, 18), randf_range(-12, 12)), 0.03)
	tween.tween_property(_face, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void: _face.visible = false)


func is_showing() -> bool:
	return _face.visible

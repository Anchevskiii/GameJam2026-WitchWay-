class_name SettingsMenu
extends CanvasLayer

## Production-ready Settings Menu managing Audio, Display, and Controls
## Attached to: CanvasLayer in scenes/ui/settings_menu.tscn

signal closed()

@onready var master_slider: HSlider = %MasterSlider
@onready var master_val_label: Label = %MasterValueLabel
@onready var music_slider: HSlider = %MusicSlider
@onready var music_val_label: Label = %MusicValueLabel
@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_val_label: Label = %SfxValueLabel

@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var vsync_check: CheckBox = %VsyncCheck

@onready var back_button: Button = %BackButton
@onready var reset_button: Button = %ResetButton

var _settings_data: Dictionary = {}

func _ready() -> void:
	visible = false
	_connect_signals()
	load_and_apply_settings()

func _connect_signals() -> void:
	if master_slider:
		master_slider.value_changed.connect(_on_master_slider_changed)
	if music_slider:
		music_slider.value_changed.connect(_on_music_slider_changed)
	if sfx_slider:
		sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	if fullscreen_check:
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	if vsync_check:
		vsync_check.toggled.connect(_on_vsync_toggled)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)

func open() -> void:
	load_and_apply_settings()
	visible = true

func close() -> void:
	visible = false
	SaveManager.save_settings(_settings_data)
	closed.emit()

func load_and_apply_settings() -> void:
	_settings_data = SaveManager.load_settings()
	
	# Audio Sliders
	var master_vol: float = _settings_data.get("master_volume", 1.0)
	var music_vol: float = _settings_data.get("music_volume", 0.8)
	var sfx_vol: float = _settings_data.get("sfx_volume", 0.9)
	
	if master_slider:
		master_slider.value = master_vol * 100.0
		_update_bus_volume("Master", master_vol)
		_update_slider_label(master_val_label, master_vol)
		
	if music_slider:
		music_slider.value = music_vol * 100.0
		_update_bus_volume("Music", music_vol)
		_update_slider_label(music_val_label, music_vol)
		
	if sfx_slider:
		sfx_slider.value = sfx_vol * 100.0
		_update_bus_volume("SFX", sfx_vol)
		_update_slider_label(sfx_val_label, sfx_vol)
		
	# Display Toggles
	var is_fullscreen: bool = _settings_data.get("fullscreen", false)
	var is_vsync: bool = _settings_data.get("vsync", true)
	
	if fullscreen_check:
		fullscreen_check.button_pressed = is_fullscreen
		_apply_fullscreen(is_fullscreen)
		
	if vsync_check:
		vsync_check.button_pressed = is_vsync
		_apply_vsync(is_vsync)

func _update_bus_volume(bus_name: String, linear_val: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		if linear_val <= 0.001:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_val))

func _update_slider_label(label: Label, val: float) -> void:
	if label:
		label.text = "%d%%" % int(val * 100.0)

func _on_master_slider_changed(val: float) -> void:
	var linear_val: float = val / 100.0
	_settings_data["master_volume"] = linear_val
	_update_bus_volume("Master", linear_val)
	_update_slider_label(master_val_label, linear_val)

func _on_music_slider_changed(val: float) -> void:
	var linear_val: float = val / 100.0
	_settings_data["music_volume"] = linear_val
	_update_bus_volume("Music", linear_val)
	_update_slider_label(music_val_label, linear_val)

func _on_sfx_slider_changed(val: float) -> void:
	var linear_val: float = val / 100.0
	_settings_data["sfx_volume"] = linear_val
	_update_bus_volume("SFX", linear_val)
	_update_slider_label(sfx_val_label, linear_val)

func _on_fullscreen_toggled(button_pressed: bool) -> void:
	_settings_data["fullscreen"] = button_pressed
	_apply_fullscreen(button_pressed)

func _apply_fullscreen(is_fullscreen: bool) -> void:
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_vsync_toggled(button_pressed: bool) -> void:
	_settings_data["vsync"] = button_pressed
	_apply_vsync(button_pressed)

func _apply_vsync(is_vsync: bool) -> void:
	if is_vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		Engine.max_fps = 0
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		# Safeguard: cap to native monitor refresh rate to prevent 3000+ FPS coil whine
		var refresh: int = int(DisplayServer.screen_get_refresh_rate())
		Engine.max_fps = refresh if refresh > 0 else 240

func _on_back_pressed() -> void:
	close()

func _on_reset_pressed() -> void:
	_settings_data = {
		"master_volume": 1.0,
		"music_volume": 0.8,
		"sfx_volume": 0.9,
		"fullscreen": false,
		"vsync": true
	}
	SaveManager.save_settings(_settings_data)
	load_and_apply_settings()

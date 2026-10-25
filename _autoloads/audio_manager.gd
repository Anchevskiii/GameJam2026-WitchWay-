extends Node

## Manages ambient loops, muffled distant room sounds, and sound effects (jumpscares, triggers).
## Attached as Autoload singleton: AudioManager

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _muffled_player: AudioStreamPlayer
var _echo_loop_player: AudioStreamPlayer
var _whisper_loop_player: AudioStreamPlayer

const SFX_POOL_SIZE: int = 8
const MUFFLED_BUS: StringName = &"MuffledRoom"
const AMBIENT_MIN_COOLDOWN: float = 4.0

var _muffled_busy_until: float = 0.0
var _room_ambience_active: bool = false
var _ambience_fade_weight: float = 0.0
var _whisper_phase: float = 0.0
var _fade_tween: Tween = null


func _ready() -> void:
	_setup_muffled_bus()

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

	_echo_loop_player = AudioStreamPlayer.new()
	_echo_loop_player.bus = "Music"
	add_child(_echo_loop_player)

	_whisper_loop_player = AudioStreamPlayer.new()
	_whisper_loop_player.bus = "SFX"
	add_child(_whisper_loop_player)

	_muffled_player = AudioStreamPlayer.new()
	_muffled_player.bus = MUFFLED_BUS
	add_child(_muffled_player)

	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)


## Creates a dedicated audio bus with a LowPassFilter + Reverb so screams and laughs sound
## like they are coming through the walls from another room across the house!
func _setup_muffled_bus() -> void:
	if AudioServer.get_bus_index(MUFFLED_BUS) != -1:
		return
	var idx: int = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, MUFFLED_BUS)
	AudioServer.set_bus_send(idx, &"SFX")
	var lowpass := AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = 680.0
	lowpass.resonance = 0.35
	AudioServer.add_bus_effect(idx, lowpass)
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.78
	reverb.damping = 0.65
	reverb.wet = 0.42
	reverb.dry = 0.65
	AudioServer.add_bus_effect(idx, reverb)


func _process(delta: float) -> void:
	if not _room_ambience_active or _ambience_fade_weight <= 0.001:
		return
	_whisper_phase += delta
	# Continuous uncut whisper loop: slowly swells louder and quieter in eerie waves
	var wave: float = (sin(_whisper_phase * 0.42) * 0.5 + 0.5) * 0.65 + (sin(_whisper_phase * 0.17 + 1.3) * 0.5 + 0.5) * 0.35
	var target_whisper_db: float = lerpf(-22.0, -5.5, wave)
	var target_echo_db: float = -5.5
	var fade_db: float = linear_to_db(clampf(_ambience_fade_weight, 0.0001, 1.0))
	_whisper_loop_player.volume_db = target_whisper_db + fade_db
	_echo_loop_player.volume_db = target_echo_db + fade_db

	if not _echo_loop_player.playing:
		_echo_loop_player.play()
	if not _whisper_loop_player.playing:
		_whisper_loop_player.play()


## Starts (and smoothly fades in) the continuous uncut haunted house echo ambient + oscillating ghost whispers.
func start_room_ambience(fade_in_duration: float = 1.4) -> void:
	var echo_stream: AudioStream = _load_sfx("haunted_echo_ambient")
	var whisper_stream: AudioStream = _load_sfx("whisper_ghost")
	if echo_stream is AudioStreamMP3:
		(echo_stream as AudioStreamMP3).loop = true
	if whisper_stream is AudioStreamMP3:
		(whisper_stream as AudioStreamMP3).loop = true

	if _echo_loop_player.stream != echo_stream:
		_echo_loop_player.stream = echo_stream
	if _whisper_loop_player.stream != whisper_stream:
		_whisper_loop_player.stream = whisper_stream

	_room_ambience_active = true
	if not _echo_loop_player.playing and echo_stream != null:
		_echo_loop_player.volume_db = -60.0
		_echo_loop_player.play()
	if not _whisper_loop_player.playing and whisper_stream != null:
		_whisper_loop_player.volume_db = -60.0
		_whisper_loop_player.play()

	if _fade_tween:
		_fade_tween.kill()
	_ambience_fade_weight = 0.01
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "_ambience_fade_weight", 1.0, fade_in_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Smoothly fades out all room ambience and distant sounds to complete silence (used when transitioning floors).
func fade_out_room_ambience(fade_out_duration: float = 0.9) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "_ambience_fade_weight", 0.0, fade_out_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if _muffled_player.playing:
		_fade_tween.parallel().tween_property(_muffled_player, "volume_db", -50.0, fade_out_duration)
	_fade_tween.tween_callback(func() -> void:
		_room_ambience_active = false
		_echo_loop_player.stop()
		_whisper_loop_player.stop()
		_muffled_player.stop()
	)


func play_music(stream: AudioStream, volume_db: float = 0.0) -> void:
	if not stream:
		return
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.volume_db = volume_db
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not stream:
		return
	var target: AudioStreamPlayer = _sfx_players[0]  # If all players are busy, take the first one
	for player in _sfx_players:
		if not player.playing:
			target = player
			break
	target.stream = stream
	target.volume_db = volume_db
	# Lag cue: sounds get pitch-bent down as the fake CPU load climbs.
	target.pitch_scale = maxf(0.1, pitch_scale * (1.0 - 0.2 * LagController.lag_amount()))
	target.play()


const SFX_EXTENSIONS: Array[String] = ["mp3", "wav", "ogg"]
var _sfx_cache: Dictionary = {}


func _load_sfx(sfx_name: String) -> AudioStream:
	if not _sfx_cache.has(sfx_name):
		var stream: AudioStream = null
		var bytes_path_mp3: String = "res://assets/audio/sfx/%s.mp3" % sfx_name
		# Load full uncut MP3 directly from disk bytes if present so it is guaranteed uncut
		if FileAccess.file_exists(bytes_path_mp3):
			var mp3 := AudioStreamMP3.new()
			mp3.data = FileAccess.get_file_as_bytes(bytes_path_mp3)
			stream = mp3
		else:
			for ext in SFX_EXTENSIONS:
				var path: String = "res://assets/audio/sfx/%s.%s" % [sfx_name, ext]
				if ResourceLoader.exists(path):
					stream = load(path)
					break
		_sfx_cache[sfx_name] = stream
		if stream == null:
			push_warning("AudioManager: missing sound %s" % sfx_name)
	return _sfx_cache[sfx_name]


## Play a sound by file name from assets/audio/sfx/, e.g. AudioManager.play("player_boo").
func play(sfx_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	play_sfx(_load_sfx(sfx_name), volume_db, pitch_scale)


## Plays a full, uncut distant horror sound (woman screaming, evil laugh) through the MuffledRoom
## bus (low-pass filter + reverb) so it sounds like it's coming from another room across the house!
func play_muffled_distant(sfx_name: String, volume_db: float = -2.5, pitch_scale: float = 1.0) -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	if _muffled_player.playing or now < _muffled_busy_until or not _room_ambience_active:
		return false
	var stream: AudioStream = _load_sfx(sfx_name)
	if stream == null:
		return false
	_muffled_player.stream = stream
	_muffled_player.volume_db = volume_db
	_muffled_player.pitch_scale = maxf(0.5, pitch_scale)
	_muffled_player.play()
	var dur: float = stream.get_length() if stream.get_length() > 0.0 else 4.0
	_muffled_busy_until = now + dur / maxf(_muffled_player.pitch_scale, 0.5) + AMBIENT_MIN_COOLDOWN
	return true

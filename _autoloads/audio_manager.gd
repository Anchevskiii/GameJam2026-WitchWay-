extends Node

## Manages ambient music and sound effects (jumpscares, triggers, distant ambient horror)
## Attached as Autoload singleton: AudioManager

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _ambient_player: AudioStreamPlayer
const SFX_POOL_SIZE: int = 8

## Minimum gap (seconds) after an ambient horror sound finishes before another can play.
const AMBIENT_MIN_COOLDOWN: float = 3.5
var _ambient_busy_until: float = 0.0

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = "SFX"
	add_child(_ambient_player)
	
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)

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


const SFX_EXTENSIONS: Array[String] = ["wav", "mp3", "ogg"]
var _sfx_cache: Dictionary = {}

func _load_sfx(sfx_name: String) -> AudioStream:
	if not _sfx_cache.has(sfx_name):
		var stream: AudioStream = null
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


## Plays a distant / ambient horror sound on a dedicated single-voice channel so ambient
## sounds NEVER overlap each other or cut each other off.
func play_ambient(sfx_name: String, volume_db: float = -4.0, pitch_scale: float = 1.0) -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	if _ambient_player.playing or now < _ambient_busy_until:
		return false
	var stream: AudioStream = _load_sfx(sfx_name)
	if stream == null:
		return false
	_ambient_player.stream = stream
	_ambient_player.volume_db = volume_db
	_ambient_player.pitch_scale = maxf(0.2, pitch_scale * (1.0 - 0.15 * LagController.lag_amount()))
	_ambient_player.play()
	var dur: float = stream.get_length() if stream.get_length() > 0.0 else 2.5
	_ambient_busy_until = now + dur / maxf(_ambient_player.pitch_scale, 0.5) + AMBIENT_MIN_COOLDOWN
	return true

extends Node

## Manages ambient music and sound effects (jumpscares, triggers)
## Attached as Autoload singleton: AudioManager

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 8

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)
	
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
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


const SFX_DIR: String = "res://assets/audio/sfx/%s.wav"
var _sfx_cache: Dictionary = {}

## Play a sound by file name from assets/audio/sfx/, e.g. AudioManager.play("whoosh").
func play(sfx_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not _sfx_cache.has(sfx_name):
		var path: String = SFX_DIR % sfx_name
		_sfx_cache[sfx_name] = load(path) if ResourceLoader.exists(path) else null
		if _sfx_cache[sfx_name] == null:
			push_warning("AudioManager: missing sound %s" % path)
	play_sfx(_sfx_cache[sfx_name], volume_db, pitch_scale)

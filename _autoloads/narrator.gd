extends Node

## The deadpan Narrator ("Haunted House Management").
## Attached as Autoload singleton: Narrator
##
## Usage:
##   Narrator.say("Texture not found? That's called minimalism.")
##   Narrator.say_event("heavy_prop", {"prop": "Cauldron"})   # random line from data/narrator_lines.json
##
## Lines are queued and shown one after another. The HUD listens to
## EventBus.narrator_line_changed and draws the text box.

const LINES_PATH: String = "res://data/narrator_lines.json"

## Seconds a line stays on screen: base + per character.
@export var base_duration: float = 1.6
@export var seconds_per_char: float = 0.045
## Max lines waiting in the queue; older chatter is dropped so the narrator never lags behind.
@export var max_queue: int = 3
## The same event type will not be announced again within this many seconds.
@export var event_cooldown: float = 6.0

var _queue: Array[String] = []
var _timer: float = 0.0
var _showing: bool = false
var _lines: Dictionary = {}
var _last_event_time: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_lines()


func _process(delta: float) -> void:
	if _showing:
		_timer -= delta
		if _timer <= 0.0:
			_showing = false
			EventBus.narrator_line_changed.emit("")
	if not _showing and not _queue.is_empty():
		_show(_queue.pop_front())


## Queue a line of text.
func say(text: String) -> void:
	if text.is_empty():
		return
	_queue.append(text)
	while _queue.size() > max_queue:
		_queue.pop_front()


## Interrupt whatever is showing and say this right now (deaths, door opening).
func say_now(text: String) -> void:
	_queue.clear()
	_show(text)


## Say a random line for an event key from narrator_lines.json.
## `values` fills {placeholders}, e.g. {"prop": "Cauldron"}.
func say_event(event_key: String, values: Dictionary = {}, interrupt: bool = false) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if _last_event_time.has(event_key) and now - float(_last_event_time[event_key]) < event_cooldown:
		return
	var options: Array = _lines.get(event_key, [])
	if options.is_empty():
		return
	_last_event_time[event_key] = now
	var text: String = str(options.pick_random()).format(values)
	if interrupt:
		say_now(text)
	else:
		say(text)


func clear() -> void:
	_queue.clear()
	_showing = false
	EventBus.narrator_line_changed.emit("")


func _show(text: String) -> void:
	_showing = true
	_timer = base_duration + text.length() * seconds_per_char
	EventBus.narrator_line_changed.emit(text)


func _load_lines() -> void:
	var file: FileAccess = FileAccess.open(LINES_PATH, FileAccess.READ)
	if not file:
		push_warning("Narrator: could not open %s" % LINES_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_lines = parsed
	else:
		push_error("Narrator: %s is not a JSON object." % LINES_PATH)

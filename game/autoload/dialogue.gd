extends Node
## THE VEIL - dialogue / subtitles (autoload "Dialogue").
## Lines live in game/data/dialogue.json: {id: {lines: [{speaker, text, time}], choices: [{text, next}]}}.
## say(id) queues an entry; the HUD shows each line as a subtitle. Choices are carried in the data and emitted
## for a future dialogue UI (Phase 1 only uses protagonist observations).

signal line_started(speaker: String, text: String, duration: float)
signal line_finished
signal choices_offered(id: String, choices: Array)

var data := {}
var _queue: Array = []
var _timer := 0.0
var _active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var f := FileAccess.open("res://game/data/dialogue.json", FileAccess.READ)
	if f:
		data = JSON.parse_string(f.get_as_text())


## Queue an entry. once=true plays it only the first time in a playthrough (tracked as a Game flag).
func say(id: String, once := false, interrupt := false) -> void:
	if not data.has(id):
		push_warning("dialogue id missing: " + id)
		return
	if once:
		if Game.has_flag("said_" + id):
			return
		Game.flags["said_" + id] = true
	if interrupt:
		_queue.clear()
		_active = false
		_timer = 0.0
	for l in data[id].get("lines", []):
		_queue.append(l)
	if data[id].has("choices"):
		_queue.append({"choices": data[id]["choices"], "id": id})


func clear() -> void:
	_queue.clear()
	_active = false
	line_finished.emit()


func is_busy() -> bool:
	return _active or not _queue.is_empty()


func _process(delta: float) -> void:
	if _active:
		_timer -= delta
		if _timer <= 0.0:
			_active = false
			line_finished.emit()
	if not _active and not _queue.is_empty():
		var l: Dictionary = _queue.pop_front()
		if l.has("choices"):
			choices_offered.emit(l["id"], l["choices"])
			return
		_active = true
		_timer = float(l.get("time", 2.5))
		line_started.emit(l.get("speaker", ""), l.get("text", ""), _timer)

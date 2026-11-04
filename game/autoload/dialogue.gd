extends Node
## THE VEIL - dialogue / subtitles (autoload "Dialogue").
## Lines live in game/data/dialogue.json: {id: {lines: [{speaker, text, time}], choices: [{text, next}]}}.
## say(id) queues an entry; the HUD shows each line as a subtitle. Choices are emitted (choices_offered) for the
## choice panel. In confirm_mode (NPC conversations) each line waits for the player to confirm it.

signal line_started(speaker: String, text: String, duration: float)
signal line_finished
signal choices_offered(id: String, choices: Array)
## conversation mode: a line has been on screen long enough and now waits for the player (E / click / Space)
signal waiting_confirm(on: bool)

var data := {}
var _queue: Array = []
var _timer := 0.0
var _active := false
## Conversations (NPC talks) wait for the player to confirm each line instead of timing out. Set by the world's
## converse(); monologue lines and observations stay timed.
var confirm_mode := false
## tests: confirm automatically once a line's normal time is up (emulates the player pressing E)
var auto_confirm := false
const MIN_SHOW := 0.35                  ## a line can be skipped this long after it appears
var _shown := 0.0
var _waiting := false
var confirms := 0                       ## lines advanced by a confirmation (tests)


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
	_set_waiting(false)
	line_finished.emit()


func is_busy() -> bool:
	return _active or not _queue.is_empty()


## The player confirmed the current conversation line (also skips a line that has been up for MIN_SHOW s).
func advance() -> void:
	if not _active or not confirm_mode or _shown < MIN_SHOW:
		return
	confirms += 1
	_active = false
	_set_waiting(false)
	line_finished.emit()


## Any line on screen can be advanced by the player (one press = one line, never before MIN_SHOW).
func advance_any() -> void:
	if not _active or _shown < MIN_SHOW:
		return
	confirms += 1
	_active = false
	_set_waiting(false)
	line_finished.emit()


## HOLD to skip: the current line and the lines queued after it, up to (never past) a choice.
var skipped := 0


func skip() -> void:
	if not _active:
		return
	while not _queue.is_empty() and not (_queue[0] as Dictionary).has("choices"):
		_queue.pop_front()
	skipped += 1
	_active = false
	_set_waiting(false)
	line_finished.emit()


func is_active() -> bool:
	return _active


func is_waiting() -> bool:
	return _waiting


func _set_waiting(on: bool) -> void:
	if on != _waiting:
		_waiting = on
		waiting_confirm.emit(on)


func _unhandled_input(e: InputEvent) -> void:
	if not (confirm_mode and _active):
		return
	var press: bool = e.is_action_pressed("interact") or e.is_action_pressed("ui_accept") \
		or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
		or (e is InputEventScreenTouch and e.pressed)
	if press:
		advance()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _active:
		_timer -= delta
		_shown += delta
		if _timer <= 0.0:
			if confirm_mode and not auto_confirm:
				_set_waiting(true)                 # hold the line until the player confirms
			elif confirm_mode:
				advance()
			else:
				_active = false
				line_finished.emit()
	if not _active and not _queue.is_empty():
		var l: Dictionary = _queue.pop_front()
		if l.has("choices"):
			choices_offered.emit(l["id"], l["choices"])
			return
		_active = true
		_shown = 0.0
		_timer = float(l.get("time", 2.5))
		line_started.emit(l.get("speaker", ""), l.get("text", ""), _timer)

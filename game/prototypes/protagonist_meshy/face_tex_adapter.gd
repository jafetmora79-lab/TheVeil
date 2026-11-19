extends Node
class_name VeilFaceTexAdapter
## THE VEIL - lets the protagonist's face-texture expressions (VeilProtagonistFaceTex) answer the calls the world already makes on an NPC's VeilFace:
## set_expression / say / start_talking / stop_talking / blink / look / widen_eyes / narrow_eyes. Used only by the clerk test
## (the protagonist test); the game's own faces are untouched.
## Expression names the game uses: neutral, happy, scared, shocked, angry, sad ...; Sarah has neutral / scared / angry, the rest map to the nearest.

var face: VeilProtagonistFaceTex
var expression := "neutral"
var talking := false
var face_atlas: Texture2D                       ## (unused, kept so code that sets it does not break)
var _talk_left := -1.0
var _override_left := 0.0
var _override := ""


func setup(f: VeilProtagonistFaceTex) -> void:
	face = f


static func map_expression(name: String) -> String:
	match name:
		"scared", "shocked", "surprised", "afraid":
			return "scared"
		"angry", "mad", "annoyed":
			return "neutral"                      # (no angry texture yet)
	return "neutral"


func set_expression(name: String, _instant := false) -> void:
	expression = name
	if face and _override_left <= 0.0:
		face.expression = map_expression(name)


func start_talking(_style := "idle") -> void:
	talking = true
	if face:
		face.talking = true


func stop_talking() -> void:
	talking = false
	_talk_left = -1.0
	if face:
		face.talking = false


func say(seconds: float, style := "idle") -> void:
	start_talking(style)
	_talk_left = seconds


func blink() -> void:
	if face:
		face.blink()


func look(_direction: String, _seconds := 1.0) -> void:
	pass                                          # the eyes are painted: glances are done by the head (NpcAnimator)


func widen_eyes(seconds := 0.45) -> void:
	_temporary("scared", seconds)


func narrow_eyes(seconds := 0.7) -> void:
	_temporary("angry", seconds)


func current_cells() -> Dictionary:
	return {}


func _temporary(expr: String, seconds: float) -> void:
	_override = expr
	_override_left = seconds
	if face:
		face.expression = expr


func _process(delta: float) -> void:
	if _talk_left > 0.0:
		_talk_left -= delta
		if _talk_left <= 0.0:
			stop_talking()
	if _override_left > 0.0:
		_override_left -= delta
		if _override_left <= 0.0 and face:
			face.expression = map_expression(expression)

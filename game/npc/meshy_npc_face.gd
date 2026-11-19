extends Node
class_name VeilMeshyNpcFace
## THE VEIL - answers the calls the world already makes on an NPC's VeilFace (set_expression / say / start_talking / stop_talking / blink / look /
## widen_eyes / narrow_eyes) for a Meshy NPC's face-texture expressions (VeilNpcFaceTex: neutral, scared, angry, worried + talking + blinking).
## The old face system has ten expressions; they map onto the four: scared / shocked / pain -> scared; angry / determined / suspicious -> angry;
## sad / confused -> worried; everything else -> neutral.
var face: VeilNpcFaceTex
var expression := "neutral"
var talking := false
var face_atlas: Texture2D                       ## (unused: kept so code that sets it does not break)
var auto_blink := true:
	set(v):
		auto_blink = v
		if face:
			face.auto_blink = v
var _talk_left := -1.0
var _override_left := 0.0


func setup(f: VeilNpcFaceTex) -> void:
	face = f


static func map_expression(name: String) -> String:
	match name:
		"scared", "shocked", "pain", "surprised", "afraid":
			return "scared"
		"angry", "determined", "suspicious", "mad", "annoyed":
			return "angry"
		"sad", "confused", "worried", "concerned":
			return "worried"
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
	pass                                          # the eyes are painted into the face texture: glances are done by the head (NpcAnimator)


func widen_eyes(seconds := 0.45) -> void:
	_temporary("scared", seconds)


func narrow_eyes(seconds := 0.7) -> void:
	_temporary("angry", seconds)


func current_cells() -> Dictionary:
	return {}


func _temporary(expr: String, seconds: float) -> void:
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

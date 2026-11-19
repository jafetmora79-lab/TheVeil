extends Node
class_name VeilMeshyNpcFace
## THE VEIL - answers the calls the world already makes on an NPC's VeilFace (set_expression / say / start_talking / stop_talking / blink / look /
## widen_eyes / narrow_eyes) for a Meshy NPC's face-texture expressions (VeilNpcFaceTex: neutral, scared, angry, worried + talking + blinking).
## The old face system has ten expressions; they map onto the NPCs' four: scared / shocked / pain -> scared; angry / determined / suspicious -> angry;
## sad / confused -> worried; everything else -> neutral.
var face: Node                                  ## VeilNpcFaceTex (NPCs), VeilProtagonistFaceTex (protagonist) or VeilSarahFace (Sarah): all have expression / talking / blink() / auto_blink
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
var _anim: Node                                 ## the NpcAnimator next to this node: a scared body (set_mood("scared"): fleeing, hiding, hurt) shows a scared face


func setup(f: Node) -> void:
	face = f


func _ready() -> void:
	var p := get_parent()
	_anim = p.get_node_or_null("Animator") if p else null


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
		face.expression = _for_controller(map_expression(name))


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


## Sarah's decal face and the protagonist's texture face know fewer expressions than the NPCs': what they lack becomes neutral.
func _for_controller(expr: String) -> String:
	if expr == "worried" and not (face is VeilNpcFaceTex):
		return "neutral"
	if expr == "angry" and face is VeilProtagonistFaceTex:
		return "neutral"
	return expr


func _temporary(expr: String, seconds: float) -> void:
	_override_left = seconds
	if face:
		face.expression = _for_controller(expr)


## The face follows the body: while the NpcAnimator's mood is scared and the game has not set a stronger expression, the face is scared.
func _mood_face() -> void:
	if _anim == null or face == null or _override_left > 0.0:
		return
	var want := map_expression(expression)
	if want == "neutral" and String(_anim.get("mood")) == "scared":
		want = "scared"
	want = _for_controller(want)
	if String(face.expression) != want:
		face.expression = want


func _process(delta: float) -> void:
	_mood_face()
	if _talk_left > 0.0:
		_talk_left -= delta
		if _talk_left <= 0.0:
			stop_talking()
	if _override_left > 0.0:
		_override_left -= delta
		if _override_left <= 0.0 and face:
			face.expression = _for_controller(map_expression(expression))

extends Node
class_name VeilSarahFace
## THE VEIL - Sarah's facial expressions for the Meshy prototype (NOT used by any scene).
## Her face has no eyelid or mouth geometry (the features are painted into the 512 px skin texture), so expressions are small texture
## DECALS laid on the face (Face_* meshes in the GLB, skinned to the Head bone): each is a crop of her own face with one feature edited -
## eyes closed / wide / narrowed, angry brows, four mouth shapes. Showing or hiding them touches only visibility, never the skeleton, so
## they play together with any body animation without interfering.
##   expression : "neutral" | "scared" | "angry"
##   talking    : mouth cycles through small / wide / rest shapes
##   blink()    : lids closed for a moment; blinks also happen on their own every few seconds
##   Neutral is the unmodified face (all decals hidden).

const EYES_CLOSED := "Face_eyes_closed"
const EYES_WIDE := "Face_eyes_wide"
const EYES_NARROW := "Face_eyes_narrow"
const BROWS_ANGRY := "Face_brows_angry"
const BROWS_SCARED := "Face_brows_scared"                 # (only on faces that have it: the protagonist)
const MOUTH_SMALL := "Face_mouth_talk_small"
const MOUTH_WIDE := "Face_mouth_talk_wide"
const MOUTH_SCARED := "Face_mouth_scared"
const MOUTH_ANGRY := "Face_mouth_angry"
const TALK_CYCLE := [MOUTH_SMALL, MOUTH_WIDE, MOUTH_SMALL, "", MOUTH_WIDE, "", MOUTH_SMALL, MOUTH_WIDE]

var expression := "neutral":
	set(v):
		expression = v
		_apply()
var talking := false:
	set(v):
		talking = v
		_talk_i = 0
		_talk_t = 0.0
		_apply()
var auto_blink := true
var blink_time := 0.13
var _meshes := {}
var _blink_left := 0.0
var _next_blink := 2.2
var _talk_t := 0.0
var _talk_i := 0
var _rng := RandomNumberGenerator.new()
var eyes_state := "open"                  ## "open" | "closed" | "wide" | "narrow"   (read by tests and tools)
var mouth_state := "rest"                 ## "rest" | "small" | "wide" | "scared" | "angry"
var brows_state := "normal"               ## "normal" | "angry"


func setup(model_root: Node) -> void:
	_rng.randomize()
	for mi in model_root.find_children("Face_*", "MeshInstance3D", true, false):
		_meshes[String(mi.name)] = mi
		(mi as MeshInstance3D).visible = false
	_apply()


func has_decals() -> bool:
	return not _meshes.is_empty()


func blink(duration := -1.0) -> void:
	_blink_left = blink_time if duration < 0.0 else duration
	_apply()


func _process(delta: float) -> void:
	var dirty := false
	if _blink_left > 0.0:
		_blink_left -= delta
		dirty = true
	elif auto_blink:
		_next_blink -= delta
		if _next_blink <= 0.0:
			_blink_left = blink_time
			_next_blink = _rng.randf_range(2.2, 5.0) if _rng.randf() > 0.2 else 0.25     # now and then a double blink
			dirty = true
	if talking:
		_talk_t -= delta
		if _talk_t <= 0.0:
			_talk_t = _rng.randf_range(0.08, 0.15)
			_talk_i = (_talk_i + 1) % TALK_CYCLE.size()
			dirty = true
	if dirty:
		_apply()


func _show(only: Array) -> void:
	for k in _meshes:
		(_meshes[k] as MeshInstance3D).visible = only.has(k)


func _apply() -> void:
	var eyes := ""
	var brows := ""
	var mouth := ""
	match expression:
		"scared":
			eyes = EYES_WIDE
			mouth = MOUTH_SCARED
			if _meshes.has(BROWS_SCARED):
				brows = BROWS_SCARED
		"angry":
			eyes = EYES_NARROW
			brows = BROWS_ANGRY
			mouth = MOUTH_ANGRY
	if talking:
		var m: String = TALK_CYCLE[_talk_i]
		if m != "":
			mouth = m
	if _blink_left > 0.0:
		eyes = EYES_CLOSED
	eyes_state = {"": "open", EYES_CLOSED: "closed", EYES_WIDE: "wide", EYES_NARROW: "narrow"}[eyes]
	brows_state = "angry" if brows == BROWS_ANGRY else ("scared" if brows == BROWS_SCARED else "normal")
	mouth_state = {"": "rest", MOUTH_SMALL: "small", MOUTH_WIDE: "wide", MOUTH_SCARED: "scared", MOUTH_ANGRY: "angry"}[mouth]
	_show([eyes, brows, mouth])

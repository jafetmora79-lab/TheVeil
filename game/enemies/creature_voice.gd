extends Node
class_name VeilCreatureVoice
## THE VEIL - one creature's sounds, in 3D on its own body: a voice and its feet, so a growl never cuts a footstep.
## The creature's AI (game/enemies/hound_ai.gd) calls tick() each frame; state changes and short random waits pick the
## sound. The files come from Sfx.bank(). While a struggle holds the creature its own audio takes over (quiet()).

const SET := {
	"hound": {"unit": 6.0, "max": 60.0, "cut": 4000.0, "idle": ["hound_sniff", "hound_growl"], "alert": "hound_growl", "chase_in": "hound_bark",
		"chase": ["hound_bark", "hound_snarl"], "search": "hound_search", "bite": "hound_bite", "resume": "hs_resume", "pain": "hound_yelp",
		"hurt": "hound_whimper", "walk_once": "hound_steps", "run": "hound_run_loop"},
	"skitter": {"unit": 3.0, "max": 35.0, "cut": 6000.0, "idle": ["sk_chitter", "sk_stalk"], "alert": "sk_chitter", "chase_in": "sk_prepare",
		"chase": ["sk_fury", "sk_chitter"], "search": "sk_stalk", "bite": "ss_impact", "resume": "ss_retreat", "pain": "sk_injured",
		"hurt": "sk_injured", "walk": "sk_move_loop", "run": "sk_move_loop"},
	"crab": {"unit": 8.0, "max": 50.0, "cut": 3000.0, "idle": ["cr_creak"], "alert": "cr_threat", "chase_in": "cr_threat",
		"chase": ["cr_threat", "cr_creak"], "search": "cr_creak", "bite": "cr_snap", "resume": "cs_resume", "pain": "cr_injured",
		"hurt": "cr_angry", "walk": "cr_walk_loop", "run": "cr_walk_loop", "burst": "cr_burst"},
}

var ai: Node
var kit: Dictionary
var _voice: AudioStreamPlayer3D
var _feet: AudioStreamPlayer3D
var _feet_id := ""
var _state := ""
var _wait := 3.0
var _steps_wait := 2.0


func setup(p_ai: Node, kind: String) -> void:
	ai = p_ai
	kit = SET.get(kind, SET["hound"])
	_voice = _player()
	_feet = _player()
	_feet.volume_db = -6.0


func _player() -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.unit_size = float(kit["unit"])
	p.max_distance = float(kit["max"])
	p.attenuation_filter_cutoff_hz = float(kit["cut"])
	p.attenuation_filter_db = -18.0
	p.position = Vector3(0, 0.6, 0)
	ai.body.add_child(p)
	return p


func say(id: String, db := 0.0) -> void:
	var s := Sfx.bank(id)
	if s == null or not _voice.is_inside_tree():
		return
	_voice.stream = s
	_voice.volume_db = db
	_voice.play()


func _pick(key: String) -> String:
	var v = kit.get(key, "")
	return String(v[randi() % v.size()]) if v is Array else String(v)


func bite() -> void:
	say(_pick("bite"))


func pain() -> void:
	say(_pick("pain"), 2.0)


func burst() -> void:
	if kit.has("burst"):
		say(_pick("burst"), -2.0)


func resume() -> void:
	say(_pick("resume"))


func hurt() -> void:
	say(_pick("hurt"))


## Held by a struggle, or gone quiet: the feet stop, the voice is cut.
func quiet() -> void:
	_set_feet("")
	if _voice.playing:
		_voice.stop()
	_state = "HELD"


func _set_feet(id: String) -> void:
	if id == _feet_id:
		return
	_feet_id = id
	if id == "":
		_feet.stop()
		return
	var s := Sfx.bank(id)
	if s:
		_feet.stream = s
		_feet.play()


func tick(delta: float, state: String, moving: bool) -> void:
	if state != _state:
		_state = state
		match state:
			"SUSPICIOUS":
				say(_pick("alert"))
			"CHASE":
				say(_pick("chase_in"))
			"SEARCH":
				say(_pick("search"), -2.0)
		_wait = randf_range(2.0, 4.0)
	_wait -= delta
	if _wait <= 0.0 and not _voice.playing:
		match state:
			"CHASE":
				say(_pick("chase"))
				_wait = randf_range(2.2, 4.5)
			"SEARCH", "SUSPICIOUS":
				say(_pick("search"), -2.0)
				_wait = randf_range(3.5, 6.0)
			"PATROL", "RETURN":
				say(_pick("idle"), -3.0)
				_wait = randf_range(7.0, 15.0)
			_:
				_wait = 1.5
	# the feet: a run loop in a chase, a walk loop or the odd stalking steps otherwise
	if not moving or state == "RECOVER":
		_set_feet("")
	elif state == "CHASE":
		_set_feet(String(kit.get("run", "")))
	else:
		_set_feet(String(kit.get("walk", "")))
		if kit.has("walk_once"):
			_steps_wait -= delta
			if _steps_wait <= 0.0:
				_steps_wait = randf_range(3.5, 6.0)
				var s := Sfx.bank(String(kit["walk_once"]))
				if s:
					_feet.stream = s
					_feet.play()

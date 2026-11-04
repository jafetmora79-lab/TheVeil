## THE VEIL - lightweight facial animation for the approved characters (texture-swap faces).
## Add as a child of a character instance (or point `character` at one) and assign that character's face atlas
## (Facial/Faces/T_Face_<Name>.png). The approved head texture and mesh are kept; only two pixel windows change.
##
##   set_expression("scared")      # neutral, happy, angry, scared, shocked, sad, suspicious, confused, determined, pain
##   start_talking("angry")         # idle, angry, scared, happy, whisper  - mouth shapes follow the current expression
##   stop_talking()
##   say(2.5, "idle")               # talk for a while, then stop
##   blink()  look("left", 1.0)  widen_eyes()  narrow_eyes()
## Blinking runs on its own timer; expression, eyes and talking are independent layers.
class_name VeilFace
extends Node

const EXPRESSIONS := ["neutral", "happy", "angry", "scared", "shocked", "sad", "suspicious", "confused", "determined", "pain"]
const EYE_ACTIONS := ["none", "blink", "look_left", "look_right", "look_up", "look_down", "widen", "narrow"]
const VISEMES := ["rest", "slight", "wide", "round", "teeth"]
const TALK_STYLES := {
	"idle":    {"weights": {"slight": 3, "wide": 2, "round": 1, "teeth": 1, "rest": 1}, "step": Vector2(0.08, 0.14)},
	"angry":   {"weights": {"wide": 3, "teeth": 3, "slight": 1, "rest": 1}, "step": Vector2(0.06, 0.10)},
	"scared":  {"weights": {"slight": 3, "round": 2, "rest": 2}, "step": Vector2(0.05, 0.09)},
	"happy":   {"weights": {"wide": 3, "slight": 2, "round": 1, "rest": 1}, "step": Vector2(0.08, 0.13)},
	"whisper": {"weights": {"slight": 3, "rest": 3, "round": 1}, "step": Vector2(0.11, 0.17)},
}
const SHADER := preload("res://THE_VEIL_ASSETS_V2/06_Characters/Facial/veil_face.gdshader")

@export var face_atlas: Texture2D
@export var character: Node3D                       ## defaults to the parent
@export var expression := "neutral"
@export var auto_blink := true
@export var blink_interval := Vector2(2.5, 6.0)
@export var expression_transition := 0.06           ## brows/eyes change first, the mouth follows after this delay

var talking := false
var talk_style := "idle"
var _mat: ShaderMaterial
var _head: MeshInstance3D
var _rng := RandomNumberGenerator.new()
var _upper_expr := 0
var _mouth_expr := 0
var _mouth_delay := 0.0
var _eye := "none"
var _eye_timer := 0.0
var _blink_timer := 0.0
var _viseme := "rest"
var _viseme_timer := 0.0
var _talk_left := -1.0

func _ready() -> void:
	_rng.randomize()
	if character == null:
		character = get_parent() as Node3D
	_head = _find_head(character)
	if _head == null or face_atlas == null:
		push_warning("VeilFace: head mesh (*_Head) or face atlas missing on %s" % [character])
		return
	var base: Material = _head.get_active_material(0)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("base_tex", base.albedo_texture if base is BaseMaterial3D else null)
	_mat.set_shader_parameter("face_atlas", face_atlas)
	_head.set_surface_override_material(0, _mat)
	_blink_timer = _rng.randf_range(blink_interval.x, blink_interval.y)
	set_expression(expression, true)

func _find_head(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and String(n.name).ends_with("_Head"):
		return n
	for c in n.get_children():
		var r := _find_head(c)
		if r:
			return r
	return null

# ---------------------------------------------------------------- public API
func set_expression(name: String, instant := false) -> void:
	var i := EXPRESSIONS.find(name)
	if i < 0:
		push_warning("VeilFace: unknown expression '%s'" % name)
		return
	expression = name
	_upper_expr = i
	if instant or expression_transition <= 0.0:
		_mouth_expr = i
		_mouth_delay = 0.0
	else:
		_mouth_delay = expression_transition
	_apply()

func start_talking(style := "idle") -> void:
	talk_style = style if TALK_STYLES.has(style) else "idle"
	talking = true
	_talk_left = -1.0
	_viseme_timer = 0.0

func stop_talking() -> void:
	talking = false
	_talk_left = -1.0
	_viseme = "rest"
	_apply()

func say(seconds: float, style := "idle") -> void:
	start_talking(style)
	_talk_left = seconds

func blink() -> void:
	_set_eye("blink", 0.11)

func look(direction: String, seconds := 1.0) -> void:
	_set_eye("look_" + direction, seconds)

func widen_eyes(seconds := 0.45) -> void:
	_set_eye("widen", seconds)

func narrow_eyes(seconds := 0.7) -> void:
	_set_eye("narrow", seconds)

func current_cells() -> Dictionary:
	return {"upper": Vector2(_upper_expr, EYE_ACTIONS.find(_eye)), "mouth": Vector2(_mouth_expr, VISEMES.find(_viseme))}

# ---------------------------------------------------------------- internals
func _set_eye(action: String, seconds: float) -> void:
	if EYE_ACTIONS.find(action) < 0:
		return
	_eye = action
	_eye_timer = seconds
	_apply()

func _apply() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("upper_cell", Vector2(_upper_expr, EYE_ACTIONS.find(_eye)))
	_mat.set_shader_parameter("mouth_cell", Vector2(_mouth_expr, VISEMES.find(_viseme)))

func _pick_viseme() -> String:
	var w: Dictionary = TALK_STYLES[talk_style]["weights"]
	var total := 0
	for k in w:
		total += w[k]
	var r := _rng.randi_range(1, total)
	for k in w:
		r -= w[k]
		if r <= 0:
			return k if k != _viseme else ("rest" if k != "rest" else "slight")
	return "rest"

func _process(delta: float) -> void:
	if _mat == null:
		return
	var dirty := false
	if _mouth_delay > 0.0:
		_mouth_delay -= delta
		if _mouth_delay <= 0.0:
			_mouth_expr = _upper_expr
			dirty = true
	if _eye != "none":
		_eye_timer -= delta
		if _eye_timer <= 0.0:
			_eye = "none"
			dirty = true
	if auto_blink:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_blink_timer = _rng.randf_range(blink_interval.x, blink_interval.y)
			if _eye == "none":
				blink()
				if _rng.randf() < 0.15:
					_blink_timer = 0.25          # occasional double blink
	if talking:
		if _talk_left >= 0.0:
			_talk_left -= delta
			if _talk_left <= 0.0:
				stop_talking()
				return
		_viseme_timer -= delta
		if _viseme_timer <= 0.0:
			var st: Vector2 = TALK_STYLES[talk_style]["step"]
			_viseme_timer = _rng.randf_range(st.x, st.y)
			_viseme = _pick_viseme()
			dirty = true
	if dirty:
		_apply()

## Face_Demo: cycles every expression, talking style and eye action on one approved character (no gameplay logic).
extends Node3D

@export var face: VeilFace
const SCRIPT := [
	["neutral", "", ""], ["happy", "happy", ""], ["scared", "scared", "widen"], ["angry", "angry", ""], ["shocked", "", "widen"],
	["sad", "whisper", "look_down"], ["suspicious", "idle", "look_left"], ["confused", "idle", "look_right"],
	["determined", "idle", "narrow"], ["pain", "", ""], ["neutral", "whisper", "look_up"],
]
var _i := 0
var _t := 0.0

func _process(delta: float) -> void:
	if face == null:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = 2.6
	var step: Array = SCRIPT[_i % SCRIPT.size()]
	_i += 1
	face.set_expression(step[0])
	if step[1] != "":
		face.say(1.8, step[1])
	else:
		face.stop_talking()
	match step[2]:
		"widen": face.widen_eyes(0.6)
		"narrow": face.narrow_eyes(1.0)
		"": pass
		_: face.look(step[2].trim_prefix("look_"), 1.2)

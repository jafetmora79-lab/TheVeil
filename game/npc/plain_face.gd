extends Node
class_name VeilPlainFace
## THE VEIL - the stand-in "face controller" for Meshy characters that only have their painted neutral face (no expression sheet yet): it accepts the same calls
## as VeilNpcFaceTex and changes nothing on the model (their bodies still turn scared / talk through the NpcAnimator).
var expression := "neutral"
var talking := false
var auto_blink := true


func blink() -> void:
	pass

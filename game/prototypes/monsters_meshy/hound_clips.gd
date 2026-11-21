extends CharacterBody3D
## THE VEIL - the Hound's model is the Meshy dog (MON_hound_anim.glb) with the four clips that came with it:
##   dog_run (a real gallop, 0.37 s)  dog_chigouliang (head down, nosing about: 4.2 s)  wolf_walk_fight_right (a snarling stance, stationary)  wolf_run_fight_forward (the lunge)
## The game's creature code asks for Idle / Walk / Run / Alert / Sniff / Detect / Attack_Bite / Hit_React / Death: this script builds that set from the four, once per hound
## (each hound has its own AnimationLibrary: the imported one is shared by every copy of the model). There is no walking clip in the file: Walk is the gallop slowed to the
## walking pace (the feet do not slide, the stride is slow). The model stands on the ground by its lowest toe.
const SCALE := 2.1
const MAP := {
	"Run": "dog_run", "Walk": "dog_run", "Idle": "dog_chigouliang", "Sniff": "dog_chigouliang", "Alert": "wolf_walk_fight_right", "Detect": "wolf_walk_fight_right",
	"Attack_Bite": "wolf_run_fight_forward", "Hit_React": "wolf_run_fight_forward", "Death": "dog_chigouliang",
}
const LOOPED := ["Run", "Walk", "Idle", "Sniff", "Alert"]
const TOES := ["rearToe.L", "rearToe.R", "frontToe.L", "frontToe.R"]


func _ready() -> void:
	var model := get_node_or_null("Model") as Node3D
	if model == null:
		return
	var ap := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var own := AnimationLibrary.new()
	for k in MAP:
		var src := ap.get_animation(MAP[k])
		if src == null:
			continue
		var an := src.duplicate() as Animation
		an.loop_mode = Animation.LOOP_LINEAR if k in LOOPED else Animation.LOOP_NONE
		own.add_animation(k, an)
	for ln in ap.get_animation_library_list():
		ap.remove_animation_library(ln)
	ap.add_animation_library("", own)
	ap.play("Idle")
	# stand on the ground: the lowest toe of the gallop and of the idle sets the model's height
	var sk := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var low := 1e9
	for clip in ["Run", "Idle"]:
		ap.play(clip)
		var a := ap.get_animation(clip)
		for s in 8:
			ap.seek(a.length * s / 8.0, true)
			sk.force_update_all_bone_transforms()
			for tn in TOES:
				var i := sk.find_bone(tn)
				if i >= 0:
					low = minf(low, sk.get_bone_global_pose(i).origin.y)
	ap.play("Idle")
	model.position.y = -low * SCALE

class_name VeilTripodColossus
extends Node3D
## THE VEIL - the Colossus: the Meshy tripod bonecage (game/prototypes/monsters_meshy/MON_tripod.glb), standing in the mist. Three legs, a slow walk, and one
## eye that is a searchlight: it sweeps the city and can lock on. Its body sinks into the mist with height (only the legs read plainly); the eye does not.
const MODEL := preload("res://game/prototypes/monsters_meshy/MON_tripod.glb")
const VEIL_SHADER := preload("res://game/world/colossus_veil.gdshader")
const BASE_H := 12.0                   ## the GLB's own height
const BASE_SPEED := 0.45               ## its walk's ground speed (m/s) at speed_scale 1, at BASE_H
const CYCLE_S := 8.0
const LOOK := {"conceal_start": 30.0, "conceal_end": 110.0, "dissolve_start": 900.0, "dissolve_end": 1000.0, "albedo_mul": 1.5,
		"key_energy": 0.7, "ambient": 0.7, "emission_energy": 0.0, "distance_fade": 0.005, "mist_col": Color(0.2, 0.22, 0.26)}
var model: Node3D
var eye: VeilTripodEye
var ap: AnimationPlayer
var height := 40.0


func build(h: float, ground_y: float) -> void:
	height = h
	model = MODEL.instantiate() as Node3D
	add_child(model)
	model.scale = Vector3.ONE * (h / BASE_H)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		ap = players[0] as AnimationPlayer
		for nm in ["Walk_Heavy", "Idle"]:
			if ap.has_animation(nm):
				ap.get_animation(nm).loop_mode = Animation.LOOP_LINEAR
		ap.play("Walk_Heavy" if ap.has_animation("Walk_Heavy") else "Idle")
	eye = VeilTripodEye.new()
	model.add_child(eye)                                # (its _ready makes the pod's glowing surface)
	eye.ground_y = ground_y
	eye.max_angle = 1.35
	_veil(ground_y)


## the bone surfaces go through the Veil's look; surface 1 (the eye) keeps its own glowing material
func _veil(ground_y: float) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var src := m.get_active_material(0) as BaseMaterial3D
		var sm := ShaderMaterial.new()
		sm.shader = VEIL_SHADER
		if src:
			sm.set_shader_parameter("albedo_tex", src.albedo_texture)
		sm.set_shader_parameter("ground_y", ground_y)
		for k in LOOK:
			sm.set_shader_parameter(k, LOOK[k])
		m.set_surface_override_material(0, sm)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func ground_speed() -> float:
	return BASE_SPEED * (height / BASE_H) * (ap.speed_scale if ap else 1.0)


func step_interval() -> float:
	return CYCLE_S / 3.0 / maxf(ap.speed_scale if ap else 1.0, 0.05)


func set_walking(on: bool, speed_scale := 1.2) -> void:
	if ap == null:
		return
	if on:
		ap.play("Walk_Heavy")
		ap.speed_scale = speed_scale
	else:
		ap.play("Idle")
		ap.speed_scale = 1.0


## A holder that stands in for an OLD Colossus scene (the old one walks +Z and has no pivot offset): the tripod faces -Z, so it sits turned half a turn inside the holder.
## The holder carries `animation_player`-style helpers: `col` (this node), and answers the old clip names (Walk_Heavy, anything else -> Idle) through play_old().
static func make_holder(parent: Node, h: float, ground_y: float) -> Node3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	var tc := VeilTripodColossus.new()
	tc.name = "Tripod"
	holder.add_child(tc)
	tc.build(h, ground_y)
	tc.rotation.y = PI
	holder.set_meta("tripod", tc)
	tc.enable_stomps.call_deferred()
	return holder


func play_old(clip: String, speed_scale := 1.0) -> void:
	if ap == null:
		return
	if clip == "Walk_Heavy":
		set_walking(true, speed_scale)
	else:
		set_walking(false)


## The footprints, felled trees and dust it leaves where its feet come down (game/enemies/colossus_stomps.gd). `trees` is the world's VeilScatter (or null).
func enable_stomps(trees: Node = null) -> Node:
	if trees == null and is_inside_tree():
		trees = get_tree().root.find_child("Scatter", true, false)
	var st = load("res://game/enemies/colossus_stomps.gd").attach(self, trees)
	set_meta("stomps", st)
	return st

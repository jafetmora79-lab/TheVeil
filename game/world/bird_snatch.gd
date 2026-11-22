extends Node
class_name VeilBirdSnatch
## Review note #91: while scavenging, the flying monsters (Grimtalons) come down out of the mist all at once and go for the player. A fast, frightening little sequence: a screech, three
## shapes diving, CROUCH within 3 seconds (the crouch key) and they scream past overhead; too slow and they rake you (damage); a second miss, or a hit that could kill, and one takes you by the shoulders:
## from first person you are lifted off the ground and carried up into the mist, the screen fades, YOU DIED (the world's death scene, RETRY from the last checkpoint).
const WINDOW := 3.0
var world: Node
var player: CharacterBody3D
var busy := false
var misses := 0
var report := {"runs": 0, "ducked": 0, "scratched": 0, "snatched": 0}


func setup(w: Node) -> void:
	world = w
	player = w.player


func can_start() -> bool:
	return not busy and player != null and player.controls_enabled and not world.in_car and not world.conversing and not Dialogue.is_busy() \
		and player.global_position.y > -5.0 and player.health > 0.0 and world._outdoors()


func trigger() -> void:
	if busy:
		return
	busy = true
	report["runs"] += 1
	var cam: Camera3D = player.camera
	var p0: Vector3 = player.global_position
	var away := -player.global_basis.z
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	Sfx.play("colossus_call", p0 + Vector3(0, 30, 0), 2.0, 1.6)                # the screech first
	world.hud.set_hint("")
	world.hud.title_card("CROUCH!", 0.8)
	var birds: Array = []
	for i in 3:
		var side := (i - 1) * 7.0
		var start: Vector3 = p0 + away * 55.0 + away.cross(Vector3.UP) * side + Vector3(0, 30.0 + 4.0 * i, 0)
		var g := VeilGrimtalon.spawn(world, start, atan2(-away.x, -away.z))
		g.scripted()
		g.flap_rate = 3.0
		g.amp = 1.0
		birds.append(g)
	# the dive: each bird comes down the line to the player and arrives together at WINDOW seconds
	var t := 0.0
	var ducked := false
	while t < WINDOW:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		if player.crouching:
			ducked = true
		var k := clampf(t / WINDOW, 0.0, 1.0)
		var e := k * k
		for i in birds.size():
			var g: VeilGrimtalon = birds[i]
			var start2: Vector3 = p0 + away * 55.0 + away.cross(Vector3.UP) * ((i - 1) * 7.0) + Vector3(0, 30.0 + 4.0 * i, 0)
			var tgt: Vector3 = player.global_position + Vector3(0, 1.7 if not ducked else 3.2, 0) + away.cross(Vector3.UP) * ((i - 1) * 0.5)
			var prev := g.global_position
			g.global_position = start2.lerp(tgt, e)
			g._look_along(g.global_position - prev if (g.global_position - prev).length() > 0.001 else -away, 0.0)
			g.pitch_angle = -0.5
		if t > WINDOW * 0.5 and int(t * 4.0) % 2 == 0:
			world.hud.set_hint("CROUCH!")
	# the moment of contact
	var safe: bool = ducked or bool(player.crouching)
	if safe:
		report["ducked"] += 1
		Sfx.play("colossus_step", player.global_position + Vector3(0, 3, 0), 3.0, 1.8)
		world._shake(cam, 0.5, 0.05)
		world.hud.set_hint("They pass over you.")
		VeilGrimtalon.retire_all(birds, away)
		misses = 0
		await get_tree().create_timer(2.0).timeout
		world.hud.set_hint("")
		busy = false
		return
	misses += 1
	var lethal: bool = misses >= 2 or player.health <= 40.0
	if not lethal:
		report["scratched"] += 1
		player.damage(18.0, player.global_position + away * 2.0)
		Sfx.play("hurt", player.global_position, 2.0)
		world._shake(cam, 0.6, 0.07)
		world.hud.set_hint("They tear at you. Get down - NOW - the next pass will kill you.")
		VeilGrimtalon.retire_all(birds, away)
		await get_tree().create_timer(3.0).timeout
		world.hud.set_hint("")
		busy = false
		return
	# the final blow: a bird takes you by the shoulders; first person, lifted and carried away into the mist
	report["snatched"] += 1
	player.controls_enabled = false
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	var lead: VeilGrimtalon = birds[1]
	Sfx.play("hurt", player.global_position, 4.0)
	var up_to: Vector3 = player.global_position + Vector3(0, 16.0, 0) + away * 14.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(player, "global_position", up_to, 3.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_method(func(k: float): player.set_yaw_pitch(player.rotation.y, lerpf(player.head.rotation.x, 0.6, k)), 0.0, 1.0, 1.4)
	var follow := true
	var tf := create_tween()
	tf.tween_method(func(_v: float):
		if is_instance_valid(lead) and follow:
			lead.global_position = player.global_position + Vector3(0, 1.8, 0.0), 0.0, 1.0, 3.4)
	for k in 6:
		world._shake(cam, 0.4, 0.05)
		Sfx.play("colossus_call", player.global_position, 1.0, 1.9)
		await get_tree().create_timer(0.55).timeout
	await world.hud.fade_to(1.0, 0.6)
	follow = false
	for g in birds:
		if is_instance_valid(g):
			g.queue_free()
	player.set_physics_process(true)
	player.damage(9999.0, up_to)                            # the death scene: YOU DIED, RETRY
	busy = false

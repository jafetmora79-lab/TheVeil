extends Node
## THE VEIL - the score and the dread (audio overhaul, 2026-11-22). Everything here is synthesised at start-up on a background thread (no new audio files):
##  - DRONES: three perfectly looping dark beds of unrelated lengths (14 / 17 / 19 s) that never line up twice: a sub drone with a beating dissonant partial, a minor-second / diminished cluster pad, an inharmonic
##    low metal texture. Under the Veil they sit under everything and swell with the danger; before the Veil they are silent.
##  - HEARTBEAT: gets louder and faster as a hunter closes in (group "veil_hunter") and during a struggle; the world also dulls (a low-pass on the Master bus) as the danger rises.
##  - AMBIENT EVENTS: every 9 - 24 s something out in the fog or in the walls (a distant hound, the Colossus far away, a roof, metal, a window, a house creak), never during a scene.
##  - JUMPSCARES: `jumpscare(kind)`: the world is cut to a hush, a sub boom + the creature's own stinger + a harsh screech land together, the view punches in, a flash, the world is muffled and the heartbeat
##    thunders for a few seconds, then everything comes back.
## It owns the Master bus effects too: a gentle EQ that removes the shrill top end (the interaction sounds were reported as uncomfortably high), a touch of room, and a limiter.

const LAYER_RATE := 16000
const HIT_RATE := 22050

var ready_layers := false
var _drone: Array = []                  ## three AudioStreamPlayers
var _heart: AudioStreamPlayer
var _streams := {}
var _thread: Thread
var _lp: AudioEffectLowPassFilter
var _lp_idx := -1
var _event_t := 14.0
var _danger := 0.0                      ## 0..1 smoothed
var _boost := 0.0                       ## a jumpscare's thunder (seconds left)
var _flash: ColorRect
var _hush_tw: Tween
var _mute := 0.0                        ## 0..1: how much the layers are cut (the hush before / after a hit)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_master_fx()
	_thread = Thread.new()
	_thread.start(_build)


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


# ------------------------------------------------------------------ the Master bus: tame the top end, a little room, a limiter
func _master_fx() -> void:
	var bus := AudioServer.get_bus_index("Master")
	var eq := AudioEffectEQ10.new()                # bands: 31, 62, 125, 250, 500, 1k, 2k, 4k, 8k, 16k
	eq.set_band_gain_db(6, -1.5)
	eq.set_band_gain_db(7, -4.0)
	eq.set_band_gain_db(8, -9.0)
	eq.set_band_gain_db(9, -15.0)
	AudioServer.add_bus_effect(bus, eq)
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.4
	rev.damping = 0.75
	rev.wet = 0.07
	rev.dry = 1.0
	AudioServer.add_bus_effect(bus, rev)
	_lp = AudioEffectLowPassFilter.new()           # opens fully; closes briefly in a scare / when something is close
	_lp.cutoff_hz = 20500.0
	AudioServer.add_bus_effect(bus, _lp)
	_lp_idx = AudioServer.get_bus_effect_count(bus) - 1
	var lim := AudioEffectLimiter.new()
	lim.ceiling_db = -1.0
	AudioServer.add_bus_effect(bus, lim)


# ------------------------------------------------------------------ synthesis (a background thread)
static func _snap(f: float, seconds: float) -> float:
	return maxf(roundf(f * seconds), 1.0) / seconds          # a whole number of cycles per loop: the loop has no seam


static func _render(seconds: float, rate: int, fn: Callable, loop := false) -> AudioStreamWAV:
	var n := int(seconds * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(fn.call(float(i) / rate, i), -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = n
	return s


static func _noise(i: int) -> float:
	var x := (i * 1103515245 + 12345) & 0x7fffffff
	x = (x * 1103515245 + 12345) & 0x7fffffff
	return float(x) / float(0x7fffffff) * 2.0 - 1.0


static func _lpn(i: int, n: int) -> float:
	var a := 0.0
	for j in n:
		a += _noise(i - j)
	return a / sqrt(float(n))


func _build() -> void:
	var out := {}
	# --- drone A (14 s): the sub, an octave with a slow swell, a dissonant minor second that comes and goes, a breath of dark wind made of sines (loops without a seam)
	var TA := 14.0
	var wind_f: Array = []
	var wind_p: Array = []
	for k in 9:
		wind_f.append(_snap(130.0 + k * 47.0, TA))
		wind_p.append(float(k) * 1.7)
	var fa := [_snap(36.71, TA), _snap(73.42, TA), _snap(77.78, TA), _snap(110.0, TA)]
	out["drone_a"] = _render(TA, LAYER_RATE, func(t: float, _i: int) -> float:
		var s := sin(TAU * fa[0] * t) * 0.50
		s += sin(TAU * fa[1] * t + 0.4) * 0.20 * (0.6 + 0.4 * sin(TAU * t / TA))
		s += sin(TAU * fa[2] * t) * 0.11 * (0.5 + 0.5 * sin(TAU * 2.0 * t / TA))
		s += sin(TAU * fa[3] * t) * 0.05 * (0.5 + 0.5 * sin(TAU * 3.0 * t / TA + 1.0))
		var w := 0.0
		for k in 9:
			w += sin(TAU * wind_f[k] * t + wind_p[k]) * (0.5 + 0.5 * sin(TAU * float(1 + k % 3) * t / TA + wind_p[k]))
		return (s + w * 0.012) * 0.75, true)
	# --- pad B (17 s): a diminished / minor-second cluster, each voice swelling on its own slow cycle
	var TB := 17.0
	var fb := [_snap(55.0, TB), _snap(65.41, TB), _snap(77.78, TB), _snap(92.5, TB), _snap(130.81, TB), _snap(155.56, TB)]
	out["pad_b"] = _render(TB, LAYER_RATE, func(t: float, _i: int) -> float:
		var s := 0.0
		for k in 6:
			var swell := 0.5 + 0.5 * sin(TAU * float(1 + k % 4) * t / TB + float(k) * 1.3)
			s += (sin(TAU * fb[k] * t) + 0.25 * sin(TAU * fb[k] * 2.0 * t)) * (0.4 + 0.6 * swell) * (0.14 - 0.012 * k)
		return s * 0.8, true)
	# --- texture C (19 s): inharmonic low metal, barely there, a slow tremolo
	var TC := 19.0
	var fc := [_snap(233.1, TC), _snap(349.4, TC), _snap(470.2, TC), _snap(622.7, TC), _snap(881.0, TC)]
	out["texture_c"] = _render(TC, LAYER_RATE, func(t: float, _i: int) -> float:
		var s := 0.0
		for k in 5:
			s += sin(TAU * fc[k] * t + float(k)) * (0.3 + 0.7 * (0.5 + 0.5 * sin(TAU * float(2 + k) * t / TC + float(k) * 0.9))) * (0.05 - 0.006 * k)
		return s, true)
	# --- heartbeat (1 s loop): two soft sub thumps
	out["heart"] = _render(1.0, HIT_RATE, func(t: float, _i: int) -> float:
		var a := sin(TAU * (62.0 - 22.0 * minf(t * 8.0, 1.0)) * t) * exp(-t * 16.0) * 0.9
		var t2 := t - 0.3
		var b := 0.0
		if t2 > 0.0:
			b = sin(TAU * (56.0 - 18.0 * minf(t2 * 8.0, 1.0)) * t2) * exp(-t2 * 18.0) * 0.7
		return a + b, true)
	# --- the boom (2.2 s): a sub that falls, a burst of dark noise, low metal
	out["boom"] = _render(2.2, HIT_RATE, func(t: float, i: int) -> float:
		var sub := sin(TAU * (46.0 * t - 7.0 * t * t)) * exp(-t * 2.0) * 0.95
		var burst := _lpn(i, 5) * exp(-t * 13.0) * 0.7
		var metal := (sin(TAU * 181.0 * t) + sin(TAU * 271.0 * t) * 0.8 + sin(TAU * 433.0 * t) * 0.6 + sin(TAU * 611.0 * t) * 0.4) * exp(-t * 4.5) * 0.14
		return sub + burst + metal)
	# --- the screech (1.3 s): a rising cluster of near tones, a rasp, harsh but kept under 2 kHz
	out["screech"] = _render(1.3, HIT_RATE, func(t: float, i: int) -> float:
		var f := 640.0 + 700.0 * minf(t / 0.9, 1.0) + 25.0 * sin(t * 38.0)
		var s := (sin(TAU * f * t) + sin(TAU * f * 1.07 * t) * 0.8 + sin(TAU * f * 1.5 * t) * 0.35) * 0.28
		s += _lpn(i, 3) * 0.22
		return s * minf(t * 60.0, 1.0) * exp(-maxf(t - 0.45, 0.0) * 3.2))
	# --- a house creak (1.4 s) for the quiet moments indoors
	out["creak"] = _render(1.4, HIT_RATE, func(t: float, i: int) -> float:
		var f := 92.0 + 36.0 * sin(t * 2.6) + 14.0 * t
		return (sin(TAU * f * t) * 0.35 + _lpn(i, 14) * 0.2 * (0.5 + 0.5 * sin(t * 40.0))) * sin(PI * clampf(t / 1.4, 0.0, 1.0)))
	# --- a far knock (0.5 s): wood, low, dull
	out["knock"] = _render(0.5, HIT_RATE, func(t: float, i: int) -> float:
		return (sin(TAU * 130.0 * t) * 0.6 + _lpn(i, 9) * 0.3) * exp(-t * 22.0))
	call_deferred("_built", out)


func _built(out: Dictionary) -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	_streams = out
	for k in ["drone_a", "pad_b", "texture_c"]:
		var p := AudioStreamPlayer.new()
		p.stream = _streams[k]
		p.volume_db = -60.0
		add_child(p)
		p.play()
		_drone.append(p)
	_heart = AudioStreamPlayer.new()
	_heart.stream = _streams["heart"]
	_heart.volume_db = -60.0
	add_child(_heart)
	_heart.play()
	ready_layers = true


# ------------------------------------------------------------------ the director
func _world() -> Node:
	return get_tree().get_first_node_in_group("veil_world")


func _hunter_distance() -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return INF
	var best := INF
	for h in get_tree().get_nodes_in_group("veil_hunter"):
		var n := h as Node3D
		if n != null and n.is_inside_tree() and n.visible:
			best = minf(best, n.global_position.distance_to(cam.global_position))
	return best


func _process(delta: float) -> void:
	if not ready_layers:
		return
	var veil := Game.has_flag("p3_mist")
	var w := _world()
	var indoors: bool = w != null and w.has_method("_outdoors") and not w._outdoors()
	var d := _hunter_distance()
	var near := clampf(1.0 - (d - 4.0) / 16.0, 0.0, 1.0) if d < INF else 0.0
	var want := maxf(near, 1.0 if Sfx.struggling else 0.0)
	want = maxf(want, clampf(float(Sfx.danger_level) / 6.0, 0.0, 0.6))
	_danger = move_toward(_danger, want, delta * (1.2 if want > _danger else 0.25))
	_boost = maxf(_boost - delta, 0.0)
	_mute = move_toward(_mute, 0.0, delta * 0.45)
	# layers: silent before the Veil; under it a steady dread bed, quieter indoors, swelling with the danger
	var base := -34.0 if veil else -80.0
	if indoors:
		base -= 5.0
	var duck := _mute * 40.0
	var vols := [base + 7.0 * _danger, base - 2.0 + 9.0 * _danger, base - 4.0 + 6.0 * _danger]
	for i in _drone.size():
		(_drone[i] as AudioStreamPlayer).volume_db = lerpf((_drone[i] as AudioStreamPlayer).volume_db, vols[i] - duck, minf(1.0, delta * 1.5))
	# the heartbeat: only when something is near / a scare has just landed; faster and louder the closer it is
	var beat := maxf(_danger, 1.0 if _boost > 0.0 else 0.0)
	var hv := -60.0 if beat < 0.08 else lerpf(-30.0, -6.0, beat)
	_heart.volume_db = lerpf(_heart.volume_db, hv - duck, minf(1.0, delta * 3.0))
	_heart.pitch_scale = lerpf(0.9, 1.45, beat)
	# the world dulls as danger closes in (never fully)
	if _lp != null and _boost <= 0.0 and _mute <= 0.0:
		_lp.cutoff_hz = lerpf(_lp.cutoff_hz, lerpf(20500.0, 2600.0, _danger * 0.8), minf(1.0, delta * 2.0))
	# something out there, now and then
	if veil and not _scene_busy():
		_event_t -= delta * (1.6 if _danger < 0.2 else 0.5)
		if _event_t <= 0.0:
			_event_t = randf_range(9.0, 24.0)
			_event(indoors)


func _scene_busy() -> bool:
	var w := _world()
	if w == null:
		return true
	return bool(w.get("conversing")) or Dialogue.is_busy() or Sfx.struggling or w.get("_cine") != null and is_instance_valid(w.get("_cine"))


func _event(indoors: bool) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var ang := randf() * TAU
	var dist := randf_range(30.0, 62.0)
	var at: Vector3 = cam.global_position + Vector3(cos(ang), 0.0, sin(ang)) * dist
	if indoors:
		match randi() % 3:
			0:
				Sfx.play_stream_at(_streams["creak"], cam.global_position + Vector3(cos(ang), 0.4, sin(ang)) * 6.0, -12.0, randf_range(0.8, 1.1), 6.0)
			1:
				Sfx.play_stream_at(_streams["knock"], cam.global_position + Vector3(cos(ang), 0.2, sin(ang)) * 9.0, -9.0, randf_range(0.8, 1.0), 6.0)
			_:
				Sfx.bank_at("ev_metal", cam.global_position + Vector3(cos(ang), 1.0, sin(ang)) * 14.0, -12.0, 14.0)
		return
	var pick := randi() % 6
	match pick:
		0, 1:
			Sfx.bank_at("hound_distant", at, -6.0, 24.0)
		2:
			Sfx.bank_at("co_distant", at + Vector3(0, 12, 0), -3.0, 40.0)
		3:
			Sfx.bank_at("ev_roof", at, -9.0, 18.0)
		4:
			Sfx.bank_at("ev_metal", at, -9.0, 18.0)
		_:
			Sfx.bank_at("ev_unknown", at, -8.0, 20.0)


# ------------------------------------------------------------------ the jumpscare
func jumpscare(kind := "generic") -> void:
	if not ready_layers:
		return
	_boost = 6.0
	_mute = 1.0                                          # the world is cut: a hush for the hit to land in
	Sfx.trim_music(-28.0)
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_callback(func(): Sfx.trim_music(0.0))
	# the hit: a sub boom, the creature's own stinger, a screech
	_play(_streams["boom"], 3.0)
	if kind != "burst":
		_play(_streams["screech"], -4.0 if kind in ["skitter", "bird"] else -9.0)
	var sting: String = {"hound": "res://game/audio/encounters/hound_stinger.wav", "skitter": "res://game/audio/encounters/skitter_stinger.wav",
		"crab": "res://game/audio/encounters/crab_stinger.wav", "bird": "res://game/audio/encounters/skitter_stinger.wav"}.get(kind, "")
	if sting != "" and ResourceLoader.exists(sting):
		_play(load(sting) as AudioStream, 2.0)
	# the ear: the world goes muffled and then opens back up
	if _lp != null:
		_lp.cutoff_hz = 700.0
		var lt := create_tween()
		lt.tween_interval(0.5)
		lt.tween_property(_lp, "cutoff_hz", 20500.0, 2.8).set_trans(Tween.TRANS_SINE)
	# the view: a punch in, a white flash
	var cam := get_viewport().get_camera_3d()
	if cam != null and kind != "burst":
		var f0 := cam.fov
		var ft := create_tween()
		ft.tween_property(cam, "fov", f0 - 16.0, 0.05)
		ft.tween_property(cam, "fov", f0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash_screen(0.5 if kind != "burst" else 0.18)


func _play(stream: AudioStream, db: float) -> void:
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _flash_screen(strength: float) -> void:
	if _flash == null:
		var layer := CanvasLayer.new()
		layer.layer = 90
		layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(layer)
		_flash = ColorRect.new()
		_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash.color = Color(0.9, 0.85, 0.85, 0.0)
		layer.add_child(_flash)
	_flash.color = Color(0.9, 0.85, 0.85, strength)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

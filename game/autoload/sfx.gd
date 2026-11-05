extends Node
## THE VEIL - small original sound set, synthesised at start-up (the repository has no audio files):
## footsteps, door creak / latch, pickup, fridge hum, evening ambience. No downloaded or licensed audio.
## Usage: Sfx.play("door_open", world_position) / Sfx.loop_at(node, "fridge_hum").

const RATE := 22050

var _streams := {}
var _ambience: AudioStreamPlayer


func _ready() -> void:
	_streams["step"] = _make(0.11, func(t, i): return _noise(i) * exp(-t * 55.0) * 0.55 + sin(TAU * 70.0 * t) * exp(-t * 40.0) * 0.4)
	_streams["step_soft"] = _make(0.1, func(t, i): return _noise(i) * exp(-t * 70.0) * 0.3)
	_streams["door_open"] = _make(0.55, func(t, i): return sin(TAU * (210.0 + 90.0 * sin(t * 9.0)) * t) * 0.18 * exp(-t * 3.0) * (0.6 + 0.4 * sin(t * 140.0)) + _noise(i) * 0.05 * exp(-t * 6.0))
	_streams["door_close"] = _make(0.25, func(t, i): return (_noise(i) * 0.5 + sin(TAU * 95.0 * t) * 0.6) * exp(-t * 28.0))
	_streams["pickup"] = _make(0.18, func(t, i): return (sin(TAU * 1450.0 * t) + sin(TAU * 2210.0 * t) * 0.6) * exp(-t * 22.0) * 0.25)
	_streams["fridge_hum"] = _make(1.0, _hum, true)
	_streams["ambience"] = _make(3.0, _amb, true)
	# once the Veil is here: the same wind without the high cricket chirps (they read as a shrill tense tone
	# behind the barricading and door closing)
	_streams["ambience_veil"] = _make(3.0, func(t, i): return _noise(i) * 0.05 * (0.6 + 0.4 * sin(TAU * t / 3.0)), true)
	# Phase 3: the Veil (synthesised placeholders)
	_streams["veil_rumble"] = _make(3.5, func(t, i): return (sin(TAU * 32.0 * t) * 0.5 + sin(TAU * 47.0 * t + sin(t * 3.0)) * 0.35 + _noise(i) * 0.12) * minf(t * 1.5, 1.0) * exp(-maxf(t - 2.2, 0.0) * 2.5))
	_streams["colossus_call"] = _make(4.0, func(t, i): return (sin(TAU * (58.0 - 14.0 * t) * t) * 0.55 + sin(TAU * (87.0 - 20.0 * t) * t) * 0.3 + _noise(i) * 0.08 * sin(t * 30.0)) * minf(t * 2.0, 1.0) * exp(-maxf(t - 2.8, 0.0) * 3.0))
	_streams["static"] = _make(1.6, func(t, i): return _noise(i) * 0.35 * (0.6 + 0.4 * sin(t * 60.0)) * exp(-maxf(t - 1.2, 0.0) * 8.0))
	_streams["tentacle_hiss"] = _make(0.7, func(t, i): return (_noise(i) * 0.5 + sin(TAU * 180.0 * t * (1.0 + t)) * 0.25) * exp(-t * 4.5))
	_streams["colossus_step"] = _make(2.6, func(t, i): return (sin(TAU * 26.0 * t) * 0.9 + sin(TAU * 41.0 * t) * 0.5 + _noise(i) * 0.5 * exp(-t * 9.0)) * exp(-t * 1.6) * minf(t * 60.0, 1.0))
	_streams["water_run"] = _make(2.2, func(t, i): return _noise(i) * 0.22 * (0.75 + 0.25 * sin(t * 37.0)) * minf(t * 8.0, 1.0) * minf((2.2 - t) * 4.0, 1.0))
	_streams["splash"] = _make(0.45, func(t, i): return (_noise(i) * 0.5 + sin(TAU * 320.0 * t) * 0.08) * exp(-t * 9.0))
	_streams["hurt"] = _make(0.35, func(t, i): return (_noise(i) * 0.4 + sin(TAU * (140.0 - 120.0 * t) * t) * 0.5) * exp(-t * 9.0))


func _hum(t: float, i: int) -> float:
	return sin(TAU * 60.0 * t) * 0.18 + sin(TAU * 120.0 * t) * 0.08 + _noise(i) * 0.015


func _amb(t: float, i: int) -> float:
	var wind := _noise(i) * 0.05 * (0.6 + 0.4 * sin(TAU * t / 3.0))
	var chirp := 0.0
	for c in [0.7, 1.9, 2.4]:
		var dt: float = t - c
		if dt > 0.0 and dt < 0.12:
			chirp += sin(TAU * (3200.0 + 1800.0 * dt / 0.12) * dt) * 0.05 * sin(PI * dt / 0.12)
	return wind + chirp


static func _noise(i: int) -> float:
	var x := (i * 1103515245 + 12345) & 0x7fffffff
	x = (x * 1103515245 + 12345) & 0x7fffffff
	return float(x) / float(0x7fffffff) * 2.0 - 1.0


func _make(seconds: float, fn: Callable, loop := false) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var prev := 0.0
	for i in n:
		var v: float = fn.call(float(i) / RATE, i)
		v = prev * 0.35 + v * 0.65          # gentle low-pass: softer, less synthetic
		prev = v
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = n
	return s


## Returns the player (or null) so a sequence can fade it out early.
func play(id: String, at: Vector3, volume_db := 0.0, pitch := 1.0) -> AudioStreamPlayer3D:
	if not _streams.has(id):
		return null
	var tree := get_tree()
	if tree.current_scene == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[id]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 4.0
	tree.current_scene.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()
	return p


func loop_at(parent: Node3D, id: String, volume_db := -10.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[id]
	p.volume_db = volume_db
	p.unit_size = 2.5
	parent.add_child(p)
	p.play()
	return p


func start_ambience(volume_db := -16.0) -> void:
	if _ambience == null:
		_ambience = AudioStreamPlayer.new()
		add_child(_ambience)
	_ambience.stream = _streams["ambience_veil"] if Game.has_flag("p3_mist") else _streams["ambience"]
	_ambience.volume_db = volume_db
	_ambience.play()


func stop_ambience() -> void:
	if _ambience:
		_ambience.stop()

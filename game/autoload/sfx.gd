extends Node
## THE VEIL - small original sound set, synthesised at start-up (the repository has no audio files):
## footsteps, door creak / latch, pickup, fridge hum, evening ambience. No downloaded or licensed audio.
## Usage: Sfx.play("door_open", world_position) / Sfx.loop_at(node, "fridge_hum").

const RATE := 22050

var _streams := {}
var _ambience: AudioStreamPlayer


func _ready() -> void:
	# a shoe on a hard floor: a dull heel thud, then the sole rolling down (a short gritty scuff ~45 ms later)
	_streams["step"] = _make(0.2, func(t, i): return _step_wave(t, i, 1.0))
	_streams["step_soft"] = _make(0.18, func(t, i): return _step_wave(t, i, 0.45))
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


## A shoe on a hard floor, kept low: a dull heel thud (55-75 Hz) and a soft scuff of smoothed (low-passed) noise
## ~40 ms later; no bright white noise and no high tones.
static func _step_wave(t: float, i: int, k: float) -> float:
	var thud := sin(TAU * (75.0 - 25.0 * minf(t * 10.0, 1.0)) * t) * exp(-t * 38.0) * 0.6
	var tap := _lp_noise(i, 10) * exp(-t * 70.0) * 0.45
	var t2 := t - 0.04
	var scuff := 0.0
	if t2 > 0.0:
		scuff = _lp_noise(i * 3 + 11, 16) * exp(-t2 * 45.0) * 0.35
	return (thud + tap + scuff) * k


## Noise averaged over n neighbouring samples: a cheap low-pass (darker, no hiss).
static func _lp_noise(i: int, n: int) -> float:
	var a := 0.0
	for j in n:
		a += _noise(i - j)
	return a / sqrt(float(n))


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
	var stream: AudioStream = _streams[id]
	var unit := 4.0
	if ID_BANK.has(id):                                 # the recorded take for this id; every call site and its timing stay
		var b := bank(String(ID_BANK[id][0]), 1.02, 1.0)
		if b:
			stream = b
			unit = float(ID_BANK[id][1])
	var tree := get_tree()
	if tree.current_scene == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = unit
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
	var bed: AudioStream = bank(_amb_bank) if Game.has_flag("p3_mist") else null
	if bed:
		_ambience.stream = bed                          # (the library's beds sit ~14 dB under the old synthesised wind)
		_ambience.volume_db = volume_db + 14.0
	else:
		_ambience.stream = _streams["ambience_veil"] if Game.has_flag("p3_mist") else _streams["ambience"]
		_ambience.volume_db = volume_db
	_amb_db = volume_db + 14.0
	_ambience.play()


## Indoors at the shelter / out in the fog: the bed fades across (only once the Veil is here, only if one is playing).
func set_ambience_area(shelter: bool) -> void:
	var want := "amb_shelter" if shelter else "amb_street"
	if want == _amb_bank:
		return
	_amb_bank = want
	if _ambience == null or not _ambience.playing or not Game.has_flag("p3_mist"):
		return
	var tw := create_tween()
	tw.tween_property(_ambience, "volume_db", -50.0, 1.2)
	tw.tween_callback(func():
		var bed := bank(_amb_bank)
		if bed:
			_ambience.stream = bed
			_ambience.play())
	tw.tween_property(_ambience, "volume_db", _amb_db, 1.8)


# ------------------------------------------------------------------ music (one channel)
const MUSIC_MENU := "res://game/audio/music/menu_exploration_smooth.wav"
const MUSIC_GAMEPLAY := "res://game/audio/music/gameplay_ambience_loop.wav"
const MUSIC_COLOSSUS := "res://game/audio/music/colossus_appearance.wav"
var _music: AudioStreamPlayer
var _music_db := -10.0
var _music_duck := 0.0
var _music_then := ""                  ## a one-shot hands back to this loop when it ends
var _music_tw: Tween


## The tracks' looping is set in their import settings (menu, gameplay and radio loop; the Colossus theme plays once):
## nothing is changed on the shared audio resources at runtime.
static func _looped(path: String, _loop: bool) -> AudioStream:
	return load(path) as AudioStream


## Play a music track (fades out the current one). loop: repeat; then_loop: after a one-shot, go back to that loop.
func play_music(path: String, loop := true, db := -10.0, fade := 1.2, then_loop := "") -> void:
	if _music == null:
		_music = AudioStreamPlayer.new()
		_music.name = "Music"
		add_child(_music)
		_music.finished.connect(func(): if _music_then != "": play_music(_music_then, true, _music_db, 2.0))
	if _music.playing and _music.has_meta("path") and _music.get_meta("path") == path:
		return
	if path == MUSIC_COLOSSUS:
		_set_cue("", 0.5)                               # the Colossus theme owns the moment
	_music_then = then_loop
	_music_db = db
	if _music_tw:
		_music_tw.kill()
	_music_tw = create_tween()
	if _music.playing:
		_music_tw.tween_property(_music, "volume_db", -50.0, fade * 0.5)
	_music_tw.tween_callback(func():
		_music.stream = _looped(path, loop)
		_music.set_meta("path", path)
		_music.volume_db = -50.0
		_music.play())
	_music_tw.tween_property(_music, "volume_db", db + _music_duck, fade * 0.5)


func stop_music(fade := 1.0) -> void:
	if _music == null or not _music.playing:
		return
	_music_then = ""
	if _music_tw:
		_music_tw.kill()
	_music_tw = create_tween()
	_music_tw.tween_property(_music, "volume_db", -50.0, fade)
	_music_tw.tween_callback(func():
		_music.stop()
		_music.remove_meta("path"))


## The car radio is on: the music sinks away (and comes back when it is off).
func duck_music(on: bool) -> void:
	_radio_on = on
	_apply_duck()


## The base music gives way to the radio or to an encounter cue, and comes back after.
func _apply_duck() -> void:
	var d := -40.0 if _radio_on or _cue != "" else 0.0
	if d == _music_duck:
		return
	_music_duck = d
	if _music and _music.playing:
		if _music_tw:
			_music_tw.kill()
		_music_tw = create_tween()
		_music_tw.tween_property(_music, "volume_db", _music_db + _music_duck, 0.8)


func stop_ambience() -> void:
	if _ambience:
		_ambience.stop()


# ------------------------------------------------------------------ the sound library (game/audio/library)
const BANKS := "res://game/data/audio_banks.json"
## Existing Sfx ids now voiced by the library: id -> [bank, unit size].
const ID_BANK := {"colossus_step": ["co_step", 30.0], "colossus_call": ["co_call", 30.0], "tentacle_hiss": ["te_strike", 6.0]}
var _bank_files := {}
var _bank_cache := {}
var _amb_bank := "amb_street"
var _amb_db := -2.0


## A bank's stream: one file as it is, several as a randomizer (no repeats, +-4 % pitch, +-2 dB). null if unknown.
func bank(id: String, pitch := 1.04, vol := 2.0) -> AudioStream:
	if _bank_cache.has(id):
		return _bank_cache[id]
	if _bank_files.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(BANKS))
		_bank_files = d if d is Dictionary else {"_": []}
	var files: Array = _bank_files.get(id, [])
	var streams: Array = []
	for f in files:
		var s := load(String(f)) as AudioStream
		if s:
			streams.append(s)
	var out: AudioStream = null
	if streams.size() == 1:
		out = streams[0]
	elif streams.size() > 1:
		var r := AudioStreamRandomizer.new()
		r.random_pitch = pitch
		r.random_volume_offset_db = vol
		r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		for s in streams:
			r.add_stream(-1, s)
		out = r
	_bank_cache[id] = out
	return out


## A one-shot from a bank at a point in the world, muffled with distance like everything in the fog.
func bank_at(id: String, at: Vector3, volume_db := 0.0, unit := 8.0) -> AudioStreamPlayer3D:
	var s := bank(id)
	var tree := get_tree()
	if s == null or tree.current_scene == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = volume_db
	p.unit_size = unit
	p.attenuation_filter_db = -18.0
	p.attenuation_filter_cutoff_hz = 3000.0
	tree.current_scene.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()
	return p


# ------------------------------------------------------------------ encounter music
## One cue at a time over the base music, crossfaded on two channels, so chase tracks never overlap. The cue follows
## what the creatures (group "veil_hunter", game/enemies/hound_ai.gd) are really doing: quiet -> growing danger (time
## outside, danger_level) -> something near -> a chase by kind -> searching -> an outro back to calm. A struggle takes
## over with its own sting and loop. The Colossus theme and the car radio both silence it.
const CHASE_CUES := {"hound": "mu_hound", "skitter": "mu_skitter", "crab": "mu_crab"}
const TENSE := ["mu_hound", "mu_skitter", "mu_crab", "mu_search", "mu_nearby", "mu_grabbed"]
const CUE_DB := -9.0
var danger_level := 0                  ## set by the expedition while outside
var struggling := false
var _radio_on := false
var _cue := ""
var _chan: Array = []
var _chan_i := 0
var _chan_tw: Array = [null, null]
var _sting: AudioStreamPlayer
var _cue_t := 0.0
var _hold_t := 0.0                     ## a cue is kept at least this long before easing to a calmer one
var _outro_t := 0.0


func _process(delta: float) -> void:
	_hold_t = maxf(_hold_t - delta, 0.0)
	_outro_t = maxf(_outro_t - delta, 0.0)
	_cue_t -= delta
	if _cue_t > 0.0:
		return
	_cue_t = 0.4
	var want := _want_cue()
	if want == _cue:
		return
	if _hold_t > 0.0 and TENSE.find(want) < 0 or (_hold_t > 0.0 and _cue in CHASE_CUES.values() and not want in CHASE_CUES.values() and want != "mu_grabbed"):
		return
	_set_cue(want, 0.5 if want == "mu_grabbed" else (1.2 if want in CHASE_CUES.values() else 2.5))


func _want_cue() -> String:
	if struggling:
		return "mu_grabbed"
	if _radio_on or (_music and _music.playing and String(_music.get_meta("path", "")) == MUSIC_COLOSSUS):
		return ""
	var w := get_tree().get_first_node_in_group("veil_world")
	if w == null or w.get("player") == null or float(w.player.health) <= 0.0:
		return ""
	var at: Vector3 = w.sedan.global_position if w.in_car else w.player.global_position
	var chase := ""
	var best := 40.0
	var searching := false
	var near := false
	for ai in get_tree().get_nodes_in_group("veil_hunter"):
		if ai.body == null or not is_instance_valid(ai.body) or not ai.body.is_visible_in_tree():
			continue
		var d: float = at.distance_to(ai.body.global_position)
		match String(ai.state):
			"CHASE", "RECOVER":
				if d < best:
					best = d
					chase = String(CHASE_CUES.get(ai.sound_kind, "mu_hound"))
			"SEARCH":
				searching = searching or d < 30.0
			"SUSPICIOUS":
				near = near or d < 28.0
			_:
				near = near or d < 16.0
	if chase != "":
		return chase
	if searching:
		return "mu_search"
	if near:
		return "mu_nearby"
	return "mu_explore" if danger_level >= 1 else ""


func _set_cue(cue: String, fade: float) -> void:
	if cue == _cue:
		return
	if _chan.is_empty():
		for i in 2:
			var p := AudioStreamPlayer.new()
			p.name = "Encounter%d" % i
			add_child(p)
			_chan.append(p)
		_sting = AudioStreamPlayer.new()
		_sting.name = "EncounterSting"
		add_child(_sting)
	var was := _cue
	_cue = cue
	_hold_t = 3.0 if cue in CHASE_CUES.values() else 0.0
	var old: AudioStreamPlayer = _chan[_chan_i]
	var old_i := _chan_i
	_chan_i = 1 - _chan_i
	var nw: AudioStreamPlayer = _chan[_chan_i]
	for t in _chan_tw:
		if t:
			t.kill()
	var s := bank(cue) if cue != "" else null
	if s:
		nw.stream = s
		nw.volume_db = -50.0
		nw.play()
		var ti := create_tween()
		ti.tween_property(nw, "volume_db", CUE_DB, fade)
		_chan_tw[_chan_i] = ti
	elif nw.playing:
		nw.stop()
	if old.playing:
		var to := create_tween()
		to.tween_property(old, "volume_db", -50.0, fade)
		to.tween_callback(old.stop)
		_chan_tw[old_i] = to
	_apply_duck()
	if was in TENSE and (cue == "" or cue == "mu_explore") and not struggling and _outro_t <= 0.0:
		_outro_t = 45.0
		_play_sting("mu_end", -14.0)                  # the danger ends: the outro, then the quiet comes back


func _play_sting(id: String, db: float) -> void:
	var s := bank(id)
	if s == null or _sting == null:
		return
	_sting.stream = s
	_sting.volume_db = db
	_sting.play()


func struggle_begin() -> void:
	struggling = true
	_hold_t = 0.0
	_set_cue("mu_grabbed", 0.4)
	_play_sting("mu_grab_sting", -6.0)


func struggle_end(won: bool) -> void:
	struggling = false
	_cue_t = 0.0
	_hold_t = 2.0
	if won:
		_play_sting("mu_escape", -10.0)
